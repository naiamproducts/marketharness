# mock-social — reference connector (local mock)

Implements the full connector contract (../README.md) with zero network:
prepare → confirm → execute → action log, with token-bound payloads and
dedup on `action_id`. Python 3 stdlib only.

## Usage

```
mock-social.py [--workspace <dir>] <command> ...

verify   <account>
read     <account> <target>
prepare  <post|reply> --account <id> --project <id> --text "..." [--target <id>]
execute  <action_id> <confirm_token>
status   <action_id>
```

All output is JSON on stdout. Errors are `{ok: false, error: {code, message}}`.
Exit codes: 0 ok, 2 structured error. Workspace can also come from
`$MARKETAGENTS_WORKSPACE`. The workspace must exist (create one with
`bin/init-workspace`).

## 3-command demo

1. **Prepare** (validates account + project resolve and are mutually
   authorized; returns the immutable payload, its hash, and the confirm
   token):

   ```bash
   WS=/tmp/ma-demo
   bin/init-workspace "$WS" --company example_company --project example_project
   cd connectors/mock-social
   ./mock-social.py --workspace "$WS" prepare post \
     --account example-linkedin --project example_project \
     --text "Hello from marketagents — first mock post."
   ```

   Note the returned `action_id` and `confirm_token`.

2. **Execute with the token** (wrong token first to see `confirm_stale`,
   then the real one):

   ```bash
   ./mock-social.py --workspace "$WS" execute <action_id> WRONG-TOKEN
   # -> {"ok": false, "error": {"code": "confirm_stale", ...}}

   ./mock-social.py --workspace "$WS" execute <action_id> <confirm_token>
   # -> {"ok": true, "external_id": "mock-li-...", "receipt": {...},
   #    "state": "executed"}
   ```

3. **Duplicate test** (re-executing the same action_id is refused with the
   prior external_id — acceptance #12, no blind retries):

   ```bash
   ./mock-social.py --workspace "$WS" execute <action_id> <confirm_token>
   # -> {"ok": false, "error": {"code": "duplicate",
   #       "prior_external_id": "mock-li-...", ...}}
   ```

The executed action is recorded in `<workspace>/.connector-log.jsonl` (one
JSON line, append-only). Check with:

```bash
./mock-social.py --workspace "$WS" status <action_id>
# -> {"ok": true, "state": "executed", "external_id": "mock-li-...", ...}
```

## Error codes

| Code | Meaning |
|---|---|
| `usage` | Bad CLI invocation |
| `workspace_unresolved` | No workspace root (flag/env/workspace.yaml) |
| `account_unresolved` | Account file not found in the workspace |
| `project_unresolved` | Project file not found in the workspace |
| `account_not_authorized` | project.yaml ↔ account yaml authorization mismatch |
| `no_auth_ref` | Account has no `auth_ref` (credential reference) |
| `unknown_action` / `invalid_payload` | Bad prepare arguments |
| `confirm_stale` | Token does not match the current payload hash |
| `duplicate` | action_id already executed (carries `prior_external_id`) |
| `not_found` | action_id neither pending nor in the log |
| `workspace_unreadable` | Workspace file unreadable |
