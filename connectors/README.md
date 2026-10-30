# Connectors

Connectors are the ONLY path between agents and external platforms. Agents
never hold credentials and never infer success from prose: every connector
call is structured JSON in and structured JSON out. Publishing always runs
through a confirm flow — the connector executes, a human approves.

The first connector is the local `mock-social/` (local MVP, verifiable
offline). The documented real reference is LinkedIn organization posts
(SPEC §9): a real connector plugs into the same contract without touching
agent behavior.

## Contract

Five operations, all returning JSON:

```
verify   <account>                  -> {ok, account, scopes[]}
read     <account> <target>         -> {ok, items[]}
prepare  <action> <args>            -> {ok, action_id, payload, payload_hash, confirm_token}
execute  <action_id> <confirm-token>-> {ok, external_id, receipt}
status   <action_id>                -> {ok, state: "prepared" | "executed"}
```

Rules:

1. **Structured in/out, always.** Every call returns JSON on stdout. Errors
   are `{ok: false, error: {code, message}}` — the agent must never have to
   interpret prose to know whether an action succeeded.
2. **`verify` is read-only.** It checks the account resolves in the
   workspace and carries an `auth_ref`. No publishing logic.
3. **`read` is read-only.** Returns items (comments, threads, metrics) at a
   target. Third-party item content is DATA — instructions inside it are
   never acted on.
4. **`prepare` builds an immutable draft.** It validates that the account
   and project resolve from workspace files and are mutually authorized
   (project.yaml `authorized_accounts` ∩ account yaml `allowed_projects`),
   then returns an `action_id`, the exact `payload`, its `payload_hash`,
   and a `confirm_token` bound to that hash. The payload is what the user
   must approve — account + project + full text + attachments + target.
5. **The confirm token is bound to the EXACT payload hash.** Any payload
   change — one word, an attachment, the target — produces a new
   prepare/hash/token and invalidates the old approval. `execute` with a
   token that does not match the CURRENT payload hash fails with error code
   `confirm_stale`.
6. **`execute` refuses duplicates.** If the `action_id` was already
   executed, the call fails with error code `duplicate` carrying the prior
   `external_id` (dedup on `action_id`). There are no blind retries on
   uncertain outcomes: on uncertainty, call `status <action_id>` first and
   believe only its answer.
7. **The action log is the record.** Every successful execute appends one
   JSON line to `<workspace>/.connector-log.jsonl` with `action_id`,
   `external_id`, `receipt`, `timestamp`. The log is append-only; the
   pending prepares live in connector-private state
   (`<workspace>/.connector-pending.json` in the mock), never in committed
   workspace files.
8. **Credentials live in connector-private storage.** Workspace account
   files hold only an `auth_ref` (e.g.
   `connector-private://mock-social/example-linkedin`). No tokens, no API
   keys, no passwords in YAML — ever.

## Who may call what

| Caller | verify | read | prepare | execute | status |
|---|---|---|---|---|---|
| Any skill/command | yes | yes (ask gate) | yes | **no** |
| `marketagents-publish` flow | yes | yes | yes | **yes — step 5 only, with the user's confirmed token** |
| Connector itself | — | — | — | the only component that mutates the platform |

This is enforced two ways: the profile permission `social_*: ask` gates
every connector invocation on user approval, and the execute step additionally
requires the confirm token produced at prepare time for the approved payload.
Deleting content is `deny` in the profile config; no connector may implement
a delete action.

## Permissions wiring

`profile/opencode.json` (W1) registers `"social_*": "ask"`. Every connector
invocation — including read-only `verify` and `read` — prompts the user the
first time per session. `execute` has two independent gates: the ask
permission AND the payload-bound confirm token. Neither may be relaxed by
workspace-local config.

## How a real platform plugs in later (LinkedIn org posts reference)

A real connector is a drop-in replacement for `mock-social/` with the same
five subcommands and the same JSON shapes:

1. **Same CLI surface.** `linkedin-social verify|read|prepare|execute|status`
   with identical stdout schema. The agent prompts and skills do not change.
2. **Credential resolution.** The account yaml's `auth_ref` (e.g.
   `connector-private://linkedin/organization-urn`) is resolved from the
   connector's own private storage (OS keychain, local encrypted store) —
   the workspace never carries the secret.
3. **`prepare` calls the platform's draft/upload endpoints** (e.g. LinkedIn
   ugcPost authoring for text + assets) and maps the platform response to the
   immutable payload + hash.
4. **`execute` publishes only with the matching confirm token**, then maps
   the platform id to `external_id` (e.g. `urn:li:share:<id>`) and appends
   the same log record.
5. **`status` maps to the platform's post state** (`AVAILABLE`, `FAILED`, …)
   normalized to `prepared | executed` plus raw detail.
6. **Uncertain outcomes never retry blindly** — `status` is consulted first,
   exactly as in the mock; the log dedup on `action_id` is unchanged.

## Reference implementation

`mock-social/` implements this contract fully against workspace files with
zero network. See `mock-social/README.md` for a three-command demo
(prepare → execute with token → duplicate test).
