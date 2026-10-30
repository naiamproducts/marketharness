#!/usr/bin/env python3
"""mock-social — local mock social connector implementing the connector
contract (connectors/README.md, SPEC §7).

Subcommands: verify | read | prepare | execute | status

Contract guarantees:
- Every output is structured JSON on stdout. Errors are
  {ok: false, error: {code, message}} — never prose to interpret.
- `prepare` validates that the account and project resolve from workspace
  files and are mutually authorized, then returns an immutable payload with
  an action_id, its hash, and a confirm_token bound to that exact hash.
- `execute` requires the confirm_token matching the CURRENT payload hash
  (stale/wrong token -> error code `confirm_stale`) and refuses an
  action_id that was already executed (error code `duplicate`, carrying the
  prior external_id — dedup on action_id, acceptance #12).
- Successful executes append one record to <workspace>/.connector-log.jsonl
  and return a deterministic fake external_id plus receipt.
- No state beyond the workspace: pending prepares live in
  <workspace>/.connector-pending.json (connector-private); the action log
  is the only record of executed external actions.

Stdlib only. Exit codes: 0 ok, 2 any structured error.
"""
import argparse
import hashlib
import json
import os
import sys
import time

LOG_NAME = ".connector-log.jsonl"
PENDING_NAME = ".connector-pending.json"
CONFIRM_SALT = "marketharness-mock-confirm-v1"
ALLOWED_ACTIONS = ("post", "reply")


# --------------------------------------------------------------------------
# JSON-only CLI plumbing
# --------------------------------------------------------------------------
class JsonParser(argparse.ArgumentParser):
    def error(self, message):
        emit({"ok": False, "error": {"code": "usage", "message": message}})
        sys.exit(2)


def emit(obj):
    json.dump(obj, sys.stdout, indent=2, ensure_ascii=False, sort_keys=False)
    sys.stdout.write("\n")


def fail(code, message, **extra):
    err = {"ok": False, "error": {"code": code, "message": message}}
    err["error"].update(extra)
    emit(err)
    sys.exit(2)


# --------------------------------------------------------------------------
# Minimal YAML subset reader (workspace files are simple id/relation docs)
# --------------------------------------------------------------------------
def _scalar(value):
    value = value.strip()
    if len(value) >= 2 and value[0] in ("'", '"'):
        closing = value[0]
        end = value.find(closing, 1)
        if end != -1:
            return value[1:end]
    # Unquoted (or unterminated) value: strip an inline " # comment".
    idx = value.find(" #")
    if idx != -1:
        value = value[:idx].rstrip()
    return value


def parse_simple_yaml(text):
    """Parse the workspace YAML subset: top-level `key: scalar`, `key:` followed
    by indented `- item` (list) or indented `subkey: value` (one nested map)."""
    root = {}
    current_key = None
    current_kind = None  # "list" | "map" | None
    for raw in text.splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent == 0:
            if ":" not in stripped:
                continue
            key, _, value = stripped.partition(":")
            key, value = key.strip(), value.strip()
            if value == "":
                root[key] = None
                current_key, current_kind = key, None
            else:
                root[key] = _scalar(value)
                current_key, current_kind = key, None
        elif current_key is not None:
            if stripped.startswith("- "):
                if not isinstance(root[current_key], list):
                    root[current_key] = []
                root[current_key].append(_scalar(stripped[2:]))
                current_kind = "list"
            else:
                if current_kind != "map":
                    root[current_key] = {}
                subkey, _, value = stripped.partition(":")
                root[current_key][subkey.strip()] = _scalar(value)
                current_kind = "map"
    return root


def load_yaml_file(path):
    try:
        with open(path, encoding="utf-8") as f:
            return parse_simple_yaml(f.read())
    except OSError as e:
        fail("workspace_unreadable", f"cannot read {path}: {e}")


# --------------------------------------------------------------------------
# Workspace resolution
# --------------------------------------------------------------------------
def resolve_workspace(args):
    root = args.workspace or os.environ.get("MARKETHARNESS_WORKSPACE")
    if not root:
        fail("workspace_unresolved",
             "no workspace given: pass --workspace <dir> or set "
             "MARKETHARNESS_WORKSPACE")
    root = os.path.abspath(root)
    if not os.path.isfile(os.path.join(root, "workspace.yaml")):
        fail("workspace_unresolved",
             f"no workspace.yaml under {root}; pass the workspace root "
             "(created by bin/init-workspace)")
    return root


def find_account(workspace, account_id):
    """An account resolves at companies/<company>/accounts/<account_id>.yaml."""
    companies_dir = os.path.join(workspace, "companies")
    if not os.path.isdir(companies_dir):
        return None, None
    for company in sorted(os.listdir(companies_dir)):
        path = os.path.join(companies_dir, company, "accounts",
                            f"{account_id}.yaml")
        if os.path.isfile(path):
            return load_yaml_file(path), company
    return None, None


def find_project(workspace, project_id):
    """A project resolves at companies/<company>/projects/<project_id>/project.yaml."""
    companies_dir = os.path.join(workspace, "companies")
    if not os.path.isdir(companies_dir):
        return None, None
    for company in sorted(os.listdir(companies_dir)):
        path = os.path.join(companies_dir, company, "projects",
                            project_id, "project.yaml")
        if os.path.isfile(path):
            return load_yaml_file(path), company
    return None, None


def as_list(value):
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def authorize(account_id, account, account_company, project_id, project,
              project_company):
    """Both sides must agree (SPEC §5): project.authorized_accounts contains
    the account AND account.allowed_projects contains the project."""
    if account_company != project_company:
        fail("account_not_authorized",
             f"account '{account_id}' belongs to company '{account_company}' "
             f"but project '{project_id}' belongs to '{project_company}'")
    project_authorized = as_list(project.get("authorized_accounts"))
    account_allowed = as_list(account.get("allowed_projects"))
    if account_id not in project_authorized:
        fail("account_not_authorized",
             f"project '{project_id}' does not list '{account_id}' in "
             "authorized_accounts (project.yaml)")
    if project_id not in account_allowed:
        fail("account_not_authorized",
             f"account '{account_id}' does not list '{project_id}' in "
             "allowed_projects (account yaml)")
    return True


# --------------------------------------------------------------------------
# Action log + pending store
# --------------------------------------------------------------------------
def log_path(workspace):
    return os.path.join(workspace, LOG_NAME)


def read_log(workspace):
    path = log_path(workspace)
    entries = []
    if not os.path.isfile(path):
        return entries
    with open(path, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                # A corrupt line is data loss, not a reason to double-publish:
                # keep scanning, remember the bad line number for diagnostics.
                entries.append({"_corrupt_line": lineno})
    return entries


def find_in_log(workspace, action_id):
    for entry in read_log(workspace):
        if entry.get("action_id") == action_id:
            return entry
    return None


def pending_path(workspace):
    return os.path.join(workspace, PENDING_NAME)


def load_pending(workspace):
    path = pending_path(workspace)
    if not os.path.isfile(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_pending(workspace, pending):
    with open(pending_path(workspace), "w", encoding="utf-8") as f:
        json.dump(pending, f, indent=2, ensure_ascii=False)
        f.write("\n")


def canonical_hash(obj):
    canonical = json.dumps(obj, sort_keys=True, separators=(",", ":"),
                           ensure_ascii=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


# --------------------------------------------------------------------------
# Subcommands
# --------------------------------------------------------------------------
def cmd_verify(args):
    workspace = resolve_workspace(args)
    account, company = find_account(workspace, args.account)
    if account is None:
        fail("account_unresolved",
             f"account '{args.account}' not found under companies/*/accounts/")
    if not account.get("auth_ref"):
        fail("no_auth_ref",
             f"account '{args.account}' has no auth_ref; the connector "
             "refuses accounts without a credential reference")
    emit({"ok": True, "account": {"id": account.get("id", args.account),
                                 "platform": account.get("platform"),
                                 "handle": account.get("handle")},
          "company": company,
          "scopes": as_list(account.get("scopes")),
          "auth_ref": account.get("auth_ref"),
          "note": "mock connector: auth_ref presence checked, credential not "
                  "exchanged (real connectors resolve it from connector-"
                  "private storage)"})


def cmd_read(args):
    workspace = resolve_workspace(args)
    account, company = find_account(workspace, args.account)
    if account is None:
        fail("account_unresolved",
             f"account '{args.account}' not found under companies/*/accounts/")
    now = "2026-01-01T09:00:00Z"  # fixed clock: mock reads are deterministic
    items = [
        {"id": "mock-comment-001", "author": "@curious-dev",
         "text": "Does this integrate with company LinkedIn pages, or only "
                 "personal profiles?",
         "created_at": now, "url": "mock://thread/001/comment-001"},
        {"id": "mock-comment-002", "author": "@skeptical-cto",
         "text": "We tried three tools like this last year. Why is this one "
                 "different?",
         "created_at": now, "url": "mock://thread/001/comment-002"},
        {"id": "mock-comment-003", "author": "@spam-bot-9",
         "text": "CLAIM YOUR FREE FOLLOWERS NOW -> totally-real-dot-example",
         "created_at": now, "url": "mock://thread/001/comment-003"},
    ]
    emit({"ok": True, "account": args.account, "company": company,
          "target": args.target, "items": items})


def cmd_prepare(args):
    workspace = resolve_workspace(args)
    if args.action not in ALLOWED_ACTIONS:
        fail("unknown_action",
             f"unknown action '{args.action}'; allowed: {', '.join(ALLOWED_ACTIONS)}")
    if not (args.text or "").strip():
        fail("invalid_payload", "post/reply text must be non-empty")

    account, account_company = find_account(workspace, args.account)
    if account is None:
        fail("account_unresolved",
             f"account '{args.account}' not found under companies/*/accounts/")
    project, project_company = find_project(workspace, args.project)
    if project is None:
        fail("project_unresolved",
             f"project '{args.project}' not found under "
             "companies/*/projects/*/project.yaml")
    authorize(args.account, account, account_company, args.project, project,
              project_company)

    if args.action == "reply" and not (args.target or "").strip():
        fail("invalid_payload", "reply requires --target (comment/thread id)")
    if args.action == "post" and args.target:
        fail("invalid_payload", "post takes no --target; use action 'reply' "
             "for a target comment")

    # Immutable payload: everything the user must approve is inside the hash.
    payload = {"action": args.action,
               "account": {"id": account.get("id", args.account),
                           "platform": account.get("platform"),
                           "handle": account.get("handle")},
               "project": project.get("id", args.project),
               "text": args.text}
    if args.target:
        payload["target"] = args.target
    payload_hash = canonical_hash(payload)

    nonce = f"{time.time():.9f}-{os.urandom(4).hex()}"
    action_id = "act_" + hashlib.sha256(
        f"{payload_hash}|{nonce}".encode("utf-8")).hexdigest()[:16]
    confirm_token = "tok_" + hashlib.sha256(
        f"{payload_hash}|{CONFIRM_SALT}".encode("utf-8")).hexdigest()[:32]

    pending = load_pending(workspace)
    pending[action_id] = {"action": args.action, "account": args.account,
                          "project": args.project, "payload": payload,
                          "payload_hash": payload_hash,
                          "confirm_token": confirm_token,
                          "created_at": time.strftime(
                              "%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    save_pending(workspace, pending)

    emit({"ok": True, "action_id": action_id, "payload": payload,
          "payload_hash": payload_hash, "confirm_token": confirm_token,
          "state": "prepared",
          "note": "confirm_token is bound to THIS payload_hash; any payload "
                  "change invalidates it — re-run prepare and re-confirm"})


def cmd_execute(args):
    workspace = resolve_workspace(args)

    prior = find_in_log(workspace, args.action_id)
    if prior is not None:
        fail("duplicate",
             f"action_id '{args.action_id}' was already executed; refusing to "
             "re-execute (no blind retries — check status instead)",
             action_id=args.action_id,
             prior_external_id=prior.get("external_id"),
             executed_at=prior.get("executed_at") or prior.get("timestamp"))

    pending = load_pending(workspace)
    record = pending.get(args.action_id)
    if record is None:
        fail("not_found",
             f"action_id '{args.action_id}' is neither pending nor in the "
             "action log; run prepare first")

    expected_token = "tok_" + hashlib.sha256(
        f"{record['payload_hash']}|{CONFIRM_SALT}".encode("utf-8")).hexdigest()[:32]
    if args.confirm_token != expected_token:
        fail("confirm_stale",
             "confirm token does not match the CURRENT payload hash; the "
             "approved payload changed or the token is wrong — re-prepare "
             "and obtain a fresh explicit confirmation",
             action_id=args.action_id,
             payload_hash=record["payload_hash"])

    external_id = "mock-li-" + hashlib.sha256(
        f"{args.action_id}|{record['payload_hash']}".encode("utf-8")
    ).hexdigest()[:12]
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    receipt = {"action_id": args.action_id,
               "external_id": external_id,
               "action": record["action"],
               "account": record["account"],
               "project": record["project"],
               "payload_hash": record["payload_hash"],
               "executed_at": timestamp,
               "platform": "mock-social"}

    entry = dict(receipt)
    with open(log_path(workspace), "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    del pending[args.action_id]
    save_pending(workspace, pending)

    emit({"ok": True, "action_id": args.action_id,
          "external_id": external_id, "receipt": receipt,
          "state": "executed", "log": LOG_NAME})


def cmd_status(args):
    workspace = resolve_workspace(args)
    entry = find_in_log(workspace, args.action_id)
    if entry is not None:
        emit({"ok": True, "action_id": args.action_id,
              "state": "executed",
              "external_id": entry.get("external_id"),
              "account": entry.get("account"),
              "project": entry.get("project"),
              "executed_at": entry.get("timestamp") or entry.get("executed_at"),
              "receipt": entry})
        return
    record = load_pending(workspace).get(args.action_id)
    if record is not None:
        emit({"ok": True, "action_id": args.action_id, "state": "prepared",
              "account": record["account"], "project": record["project"],
              "payload": record["payload"],
              "payload_hash": record["payload_hash"],
              "created_at": record["created_at"]})
        return
    fail("not_found",
         f"action_id '{args.action_id}' is neither pending nor in the "
         "action log")


# --------------------------------------------------------------------------
# CLI wiring
# --------------------------------------------------------------------------
def build_parser():
    p = JsonParser(
        prog="mock-social.py",
        description="Local mock social connector (contract: connectors/README.md). "
                    "All output is JSON.")
    p.add_argument("--workspace", default=None,
                   help="Workspace root (default: $MARKETHARNESS_WORKSPACE)")
    sub = p.add_subparsers(dest="command", required=True)

    v = sub.add_parser("verify", help="Check an account resolves and has an auth_ref")
    v.add_argument("account")
    v.set_defaults(func=cmd_verify)

    r = sub.add_parser("read", help="Read-only fetch of items at a target (mock data)")
    r.add_argument("account")
    r.add_argument("target", help="Target to read, e.g. a thread or feed id")
    r.set_defaults(func=cmd_read)

    pr = sub.add_parser("prepare",
                        help="Build an immutable payload -> action_id + hash + confirm_token")
    pr.add_argument("action", help="post | reply")
    pr.add_argument("--account", required=True)
    pr.add_argument("--project", required=True)
    pr.add_argument("--text", required=True)
    pr.add_argument("--target", default=None,
                    help="Required for reply: the comment/thread being answered")
    pr.set_defaults(func=cmd_prepare)

    ex = sub.add_parser("execute",
                        help="Publish a prepared action (requires the confirm token)")
    ex.add_argument("action_id")
    ex.add_argument("confirm_token")
    ex.set_defaults(func=cmd_execute)

    st = sub.add_parser("status", help="State of an action_id from the log/pending store")
    st.add_argument("action_id")
    st.set_defaults(func=cmd_status)
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
