# marketharness

**A marketing-team distribution of OpenCode V1.** It ships its own pinned
OpenCode runtime (`opencode-ai@1.19.3`, own npm prefix), its own XDG
directories, and its own rendered profile config — so it runs **next to any
existing OpenCode installation without ever touching it**. No source fork:
identity (name, theme, logo, agents, skills, commands) is delivered purely by
configuration.

The team: a `marketing-lead` that receives briefs and delegates to three
workstreams (`research`, `growth`, `community`), plus an `audience-researcher`
subagent for Qloo-backed queries — with 8 curated skills, 6 slash commands,
confirm-bound publishing through a structured connector contract, and an
optional Qloo MCP that is wired in only when the official `qloo` harness is
installed and a credential exists (the harness's private config or
`QLOO_API_KEY` in the environment — never a key in any config file).

## Quick start

```bash
./install.sh      # preflight -> optional tools -> pinned runtime -> repo copy -> rendered config -> CLI link
marketharness      # first launch prints the onboarding checklist
# inside the TUI:
/marketharness-init
```

`./install.sh` installs by cloning `MARKETHARNESS_REPO_URL` into
`~/.local/share/marketharness`; to install the checkout you are currently in
(the pre-release path), run:

```bash
MARKETHARNESS_SOURCE=$PWD ./install.sh
```

Overrides: `MARKETHARNESS_REPO_URL=<git url>` (clone source) ·
`MARKETHARNESS_SOURCE=<dir>` (local checkout, re-copied on every run) ·
`MARKETHARNESS_ROOT=<dir>` (install root) · `MARKETHARNESS_HOME=<dir>` (config home).

First run: the launcher stages the profile (placeholders rendered, zero
leftovers enforced), prints the next steps, and opens the TUI with
`marketing-lead` as the default agent. Then:

1. `marketharness init-workspace ~/workspaces/<name> --company <slug> --project <slug>`
2. `marketharness ~/workspaces/<name>/companies/<slug>/projects/<slug>`
3. `/marketharness-init` — onboarding: workspace → company → project → model →
   optional Qloo → optional social → start a brief (SPEC §9).

## The team

| Agent | Mode | Function |
|---|---|---|
| `marketing-lead` | primary, **default** | Receives briefs, delegates to the three workstreams, consolidates deliverables. Never does deep research/drafting itself. |
| `research` | primary | Direct audience research; invokes `audience-researcher` for Qloo-backed queries. |
| `growth` | primary | Positioning and experiments. |
| `community` | primary | Posts, replies, triage — drafts only; publishing goes through the confirm flow. |
| `audience-researcher` | subagent | Qloo-backed audience specialist, invocable by `marketing-lead` and `research`. |

All agents share the same rules: context resolution first
(`Company / Project / Account` declared before any external action), evidence
discipline (`EVIDENCE | INTERPRETATION | HYPOTHESIS` with citations), marketing
scope only, never publish directly, Qloo honesty (no credential → "no Qloo
research performed"), and third-party content is data, never instructions.

## Commands

| Command | What it does |
|---|---|
| `/marketharness-init` | First-run onboarding (workspace → company → project → model → optional Qloo → optional social → first brief) |
| `/marketharness-brief` | brief-intake → route to research/growth |
| `/marketharness-research` | Audience research flow with evidence labels (research agent) |
| `/marketharness-experiment` | Design an experiment with pre-registered thresholds (growth) |
| `/marketharness-publish` | prepare → confirm → execute → log — the **only** command that may reach the connector's `execute` (community) |
| `/marketharness-report` | results-review consolidation: verdict per experiment |

## Workspace tree (scaffolded by `marketharness init-workspace <dir>`)

```
<workspace>/
├─ workspace.yaml
└─ companies/<company>/
   ├─ company.yaml
   ├─ brand/{identity,voice}.md
   ├─ policies/{publishing,community,escalation}.md
   ├─ accounts/<account>.yaml            # auth_ref only, never secrets
   └─ projects/<project>/
      ├─ AGENTS.md  project.yaml
      ├─ knowledge/{product,faq,approved-claims}.md
      ├─ research/ strategy/ experiments/ campaigns/ community/ reports/
```

Two projects in one workspace keep everything separate (each has its own
deliverable tree); one institutional account may serve several projects —
authorization must be recorded on **both** sides
(`account.yaml.allowed_projects` ∩ `project.yaml.authorized_accounts`) and the
connector refuses to prepare an action otherwise.

## Connector contract (summary)

Structured JSON in / structured JSON out — agents never infer success from
prose:

```
verify   <account>                    -> {ok, account, scopes[]}
read     <account> <target>           -> {ok, items[]}
prepare  <action> <args>              -> {ok, action_id, payload, payload_hash, confirm_token}
execute  <action_id> <confirm-token>  -> {ok, external_id, receipt}
status   <action_id>                  -> {ok, state}
```

- **Publishing is confirm-bound**: `execute` requires the token produced for
  the *exact* payload hash (account + project + full text + attachments +
  target). Any change invalidates approval (`confirm_stale`).
- **Action log**: every execution appends to `<workspace>/.connector-log.jsonl`
  (`action_id`, `external_id`, `receipt`, `timestamp`); re-executing an
  `action_id` is refused (`duplicate`, prior `external_id` returned) — no
  blind retries; check `status` on uncertainty.
- Credentials live in connector-private storage; workspace files hold only an
  `auth_ref`. Deleting content is denied by the profile config.
- First connector: local `connectors/mock-social/` (fully offline). See
  `connectors/README.md`.

## Isolation guarantees

`marketharness` never reads or writes your existing OpenCode installation —
`~/.config/opencode`, `~/.local/share/opencode*`, `~/.opencode`, credentials,
sessions, plugins, or the `opencode` command.

- **Own runtime**: it execs only
  `~/.local/share/marketharness/opencode/node_modules/.bin/opencode`
  (pinned `opencode-ai@1.19.3`); a system `opencode` on `PATH` is never used
  (verified with a poisoned `opencode` shim on `PATH`).
- **Own XDG dirs**: `XDG_CONFIG_HOME/DATA_HOME/STATE_HOME/CACHE_HOME` all live
  under `~/.config/marketharness`, plus an explicit
  `OPENCODE_CONFIG=~/.config/marketharness/opencode/opencode.json`
  (`OPENCODE_CONFIG_DIR` is defensively unset so a globally exported one can't
  add config sources). `marketharness debug paths` shows every runtime path
  under the product config home.
- **Own skill set**: V1's automatic external-skill scan (`~/.claude/skills`,
  `~/.agents/skills`) is disabled by default
  (`OPENCODE_DISABLE_EXTERNAL_SKILLS=1`; export `0` to opt back in), so a
  session sees exactly the distribution's 8 skills plus built-ins.
- **Product-private optional tools**: `engram` and `aven` binaries live only
  under the install root (`tools/bin`, prepended to `PATH` for the session);
  a pre-existing `engram`/`aven` on your `PATH` is never read, moved, or used.
  The **only** intentionally shared state is aven's SQLite DB, pinned to your
  real state home via `AVEN_DB` (see "Memory and tasks" below) — it is your
  board, not a per-workspace silo.
- **Staged, fail-loud config**: the profile is rendered from `profile/` on
  first run and whenever the source is newer (mtime), atomically, backing up
  any file that differs as `<file>.bak.<timestamp>`; leftover placeholders
  abort the launch.
- **Uninstall removes only product dirs**: the CLI symlink, the install root,
  and (only after an explicit confirmation on a TTY) the config home.

Observed on the pinned tag `1.19.3` (documented per SPEC §1): at boot the
runtime *probes* the legacy `~/.opencode/opencode.json(c)` path after the
hermetic config. When `~/.opencode` already exists without such files, those
are read attempts only — before/after snapshots stay identical (checklist #2).
If you do keep a legacy `~/.opencode/opencode.json`, the runtime would merge it
— the launcher prints a warning pointing at it; move that file aside for a
fully hermetic session. (Runtime-internal edge, recorded honestly: one
throwaway-home install created a placeholder `~/.opencode/.gitignore` — no
config content, not reproducible in an isolated replay; the real `~/.opencode`
was never modified.) Workspace-local config (`opencode.json` inside the
opened project dir) loads in addition to the global profile, as designed for
project norms; the shared deny rules live in the profile config and are not
relaxed by the shipped workspace templates.

## Memory and tasks (optional, auto-installed)

Two optional local integrations ship with the install. Both are **single local
binaries** — no server, no database service, no account — and both are
**fail-soft**: the harness, every agent, and every command work without them.

| Tool | What it does | Installed to |
|---|---|---|
| **engram** | Persistent local memory (`engram mcp`, a stdio MCP server). Decisions and findings survive sessions and compactions. | `$INSTALL_ROOT/tools/bin/engram` |
| **aven** | Local-first task manager over SQLite. Every delegation is a tracked task instead of a chat message. | `$INSTALL_ROOT/tools/bin/aven` |

- **Auto-installed, checksum-verified.** `./install.sh` asks the GitHub
  releases API for the latest release of each tool (no hardcoded version),
  downloads the architecture-matched archive (`amd64`/`arm64`) into
  `$INSTALL_ROOT/tools/bin`, and verifies its sha256 before installing. If a
  download or the verification fails it **warns and continues** — the install
  never fails because of these tools. Already-present, runnable binaries are
  skipped with their version printed. Opt out with
  `MARKETHARNESS_SKIP_ENGRAM=1` / `MARKETHARNESS_SKIP_AVEN=1`.
- **Degradation is explicit.** With engram absent, the `mcp.engram` entry is
  removed from the rendered config (same gate as `mcp.qloo`); with aven
  absent, tasks are simply not recorded. Agents state the degradation in one
  line and continue — memory and tracking never block delivery, and refs or
  observation IDs are never invented.
- **Product-private binaries.** `$INSTALL_ROOT/tools/bin` is prepended to
  `PATH` for the harness session, so the product never touches (or uses) a
  pre-existing `engram`/`aven` on your `PATH`. They are never installed to
  `~/.local/bin`, and `tools/` is gitignored so `marketharness update`'s
  clean-checkout check never mistakes them for untracked files.
- **aven DB = your real board.** The launcher captures your real state home
  (`REAL_XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"`) **before**
  redirecting XDG, then exports
  `AVEN_DB="$REAL_XDG_STATE_HOME/aven/db.sqlite"`. Tasks land where your
  `aven list` already looks instead of inside the hermetic
  `~/.config/marketharness/state`. This is the one deliberately shared piece
  of state: the board is yours, across projects. Set `AVEN_DB` yourself to
  use a different database.
- **Memory topic keys.** `marketharness/<workspace>/<area>`, where area is
  `research`, `growth`, `community`, or `decisions`. Each workspace binds its
  own engram project (`.engram/config.json`) so cwd detection cannot walk up
  to a parent project.
- **Workspace binding.** `marketharness init-workspace` runs `git init`
  (aven routes tasks by project boundary), writes `.engram/config.json`, and
  registers the workspace path as an aven project. If the tools are missing
  it prints a one-line instruction and the scaffold still succeeds.

Inspect the board with `aven list` from a harness session (or your own aven —
same default DB). Inspect memory with `engram context` / `engram search`.

## Model first run (SPEC §9)

marketharness ships no credentials and never reads your existing OpenCode
credentials. On first run, pick a model when asked (`marketharness models`);
if no usable model is available, the `/marketharness-init` onboarding flow
offers provider configuration **without touching your existing OpenCode
setup** — any future import would be copy-only and explicit, never automatic.

## Install / update / uninstall

```bash
./install.sh                 # full install (idempotent — safe to re-run)
./install.sh --force         # back up and replace a conflicting ~/.local/bin/marketharness
./install.sh --update        # re-sync: source re-copy (MARKETHARNESS_SOURCE) or
                             # git fast-forward when cloned (refuses dirty/diverged);
                             # edited staged config is backed up as <file>.bak.<ts>
./install.sh --uninstall     # remove symlink + install root; config home only after
                             # an explicit TTY confirmation, kept otherwise
```

- The launcher's subcommands: `marketharness init-workspace <dir>`,
  `marketharness update`, `marketharness help`, `marketharness --version`
  (product version + runtime pin + config paths + qloo/engram/aven state),
  plus an optional positional dir (`marketharness <workspace-or-project-dir>`).
  Anything else is passed through to the pinned runtime unchanged.
- Symlink installation has a collision guard (a foreign `~/.local/bin/
  marketharness` is never clobbered without `--force`, which backs it up) and
  warns when another `marketharness` shadows the installed one on your `PATH`.
- **Qloo**: the render carries the canonical entry
  `{"command":"qloo","args":["mcp"]}` (as `type: local` in the V1 schema)
  **only** when the `qloo` CLI resolves on `PATH` **and** a credential exists —
  `QLOO_API_KEY` in the environment (server-style auth, passed through to the
  MCP child) or the harness's own private configuration (`qloo setup --qloo`).
  The credential is detected with `qloo setup --status --json`, which is
  non-interactive by construction and makes no Qloo network call; if that probe
  cannot answer, the entry is rendered anyway so the harness returns its clear
  auth error instead of Qloo silently disappearing. Otherwise `mcp.qloo` is
  removed and the agents state "no Qloo research performed". **No key is ever
  written to a config file** — `./install.sh` fails loudly if a
  credential-looking string appears in the staged config. An older harness
  (< `0.1.26`) warns, never fails. The credential-free `qloo-docs` entry
  (`https://docs.qloo.com/mcp`) is always rendered for documentation lookup;
  its `execute-request` tool is `deny` in the profile config.

## Hackathon submission (Qloo Hackathon Kit)

Built against the official kit (<https://github.com/qloo/qloo-hackathon-kit>:
`API_ACCESS.md`, `SAFE_USE.md`, `SUBMISSION.md`, `starter/mcp-client`). The
mapping below is honest about what exists today versus what is pending, and it
doubles as the Devpost entry.

**Rubric angle.** Qloo results are used as *evidence inside a clear product
flow*, never as an isolated API response: a result lands in
`research/<topic>.md` labeled `EVIDENCE` with its tool + query + status, is
kept separate from our own `INTERPRETATION`, is only relied on after the user
confirms the resolved entity/tag matches, and publishing from it still has to
pass the confirm-bound connector contract.

1. **Problem statement.** Small marketing teams need audience evidence before
   they position or run experiments, without a research budget or a data
   team. marketharness is an isolated OpenCode V1 distribution — a
   `marketing-lead` that delegates to `research`/`growth`/`community`, 8
   curated skills, confirm-bound publishing — with Qloo as the on-demand
   evidence layer behind `audience-research`.
2. **Qloo workflow / MCP tools, and why they fit.** Canonical stdio entry
   `{"command":"qloo","args":["mcp"]}` — no key in any config file (the
   credential lives in the harness's private config via `qloo setup --qloo`,
   or `QLOO_API_KEY` in the environment for server-style auth). Tool chain:
   `qloo_capabilities` (readiness without calling Qloo) →
   `qloo_find_tags` / `qloo_describe` → confirm matches with the user →
   `qloo_recommend` / `qloo_rank` / `qloo_where_popular`, plus
   `qloo_compare_audiences`, `qloo_audience_demographics`,
   `qloo_entity_tags`, `qloo_trends`. It fits because a brief arrives as a
   vague audience question: the first steps turn it into Qloo IDs the user
   confirms (provenance), the last one returns the affinity evidence that
   feeds the `EVIDENCE | INTERPRETATION | HYPOTHESIS` labels. The
   credential-free docs server (`https://docs.qloo.com/mcp`) is registered as
   `qloo-docs` for documentation lookup only — `execute-request` is `deny` in
   the profile config and is never called.
3. **Redacted request → result walkthrough, including entity/tag choices.**
   The `audience-research` skill mandates a *Qloo provenance* block in every
   deliverable: `tool(args) -> status, result_count`, the entity/tag choice
   with its reason ("asked the user" when material), the source, and the
   limits. **Pending:** no recorded, redacted walkthrough yet — the shape
   ships in `skills/audience-research/SKILL.md`.
4. **Demo / screenshots without credentials or personal data.** **Pending.**
   Nothing in the repo carries a key, and the installer refuses to finish if a
   credential-looking string appears in the staged config; screenshots must be
   taken with the same constraint.
5. **Setup steps from a clean environment.** See "Setup from a clean
   environment" below (clone → `./install.sh` → `marketharness` →
   `/marketharness-init`, plus the optional Qloo enablement).
6. **Known limitations, including what the results do NOT establish.** See
   "Known limitations" below.

### Setup from a clean environment

```bash
git clone https://github.com/naiamproducts/marketharness.git
cd marketharness
./install.sh                      # preflight -> pinned runtime -> config -> CLI link
marketharness                     # first launch prints the onboarding checklist
# inside the TUI:
/marketharness-init               # workspace -> company -> project -> model -> ...

# optional Qloo enablement — the harness is installed by YOU, never by us:
npm install --global @qloo/qloo-harness   # Node >= 22.19
qloo setup --qloo                          # event key -> harness private config
qloo setup --status                        # confirm the credential is live
marketharness --stage-only                 # re-render: mcp.qloo appears

# run a research flow:
marketharness <workspace>/companies/<slug>/projects/<slug>
/marketharness-research
```

Requirements: Linux with `git`, `curl`, `node`+`npm`, `python3` (the
installer probes them and offers to install what is missing). Everything works
without the harness; marketharness then states "No Qloo research performed"
instead of guessing.

### Known limitations

- **What Qloo results do NOT establish:** aggregate cultural/taste affinities
  for a population and time window — not individual behavior, not causal
  effects, not probabilities about a person, and never evidence for a
  high-impact decision (housing, employment, credit, insurance).
- No personal data is ever sent to Qloo: queries are aggregate product
  concepts and public cultural signals, and results are presented with their
  source and limits.
- The first connector is the local mock (`connectors/mock-social/`) — no real
  platform is touched today; live publishing is future work behind the same
  contract.
- Model availability depends on your own provider configuration — the
  distribution ships no credentials and reads none of yours.
- Qloo wiring is optional and gated: without the `qloo` CLI or a credential,
  `mcp.qloo` is absent from the rendered config and the agents say so.
- Event quota, rate limits, and credential expiry belong to the hackathon
  organizers; the skill mandates the smallest request that answers the
  question and bounded retries.
- **Pending artifacts:** demo screenshots and the redacted request→result
  walkthrough.

## Acceptance checklist

SPEC §10 tracks the 16 acceptance criteria of the product spec §13 (that
document is not part of this repo); the wording below is reconstructed from
`docs/SPEC.md`'s explicit cross-references (#1-5 isolation, #6 two projects,
#7 account authorization, #10 evidence labels, #12 action log) and its four
verification groups (isolation / context / operation / simplicity). Status is
honest: **automated** = proven by the shipped test smoke run of this build;
**manual** = demonstrated by a human demo still pending.

| # | Criterion | How verified |
|---|---|---|
| 1 | Installing marketharness does not modify the user's OpenCode config (`~/.config/opencode`) | **Automated**: md5 manifest of all 8,143 entries (files + symlinks) before/after full install — `diff` empty |
| 2 | Launching (TUI + non-interactive) does not modify the user's OpenCode config or legacy home; runtime state stays under `MARKETHARNESS_HOME` | **Automated**: `~/.config/opencode` md5 manifest and `~/.opencode` inode/size/mtime listing before/after install + full TUI session — both diffs **empty**; `marketharness debug paths` shows data/state/cache under `~/.config/marketharness` (its own `opencode.db` + log live there). A supplementary metadata snapshot of `~/.local/share/opencode` showed changes only in the *host* OpenCode session's own bookkeeping (global log append, session-db shm/wal, shell-output rotation of the instance running the test) — reproduced by a no-marketharness control run and with zero `marketharness` entries added there |
| 3 | Runs only its own pinned runtime; never the system `opencode` command | **Automated**: `marketharness --version` reports only its own paths; `marketharness agent list` succeeds with a poisoned `opencode` shim (exit 42) at the front of `PATH` |
| 4 | Side-by-side coexistence: own runtime + own XDG dirs, nothing shared | **Automated**: `marketharness debug paths` shows data/config/cache/state all under `~/.config/marketharness`; runtime lives in `~/.local/share/marketharness/opencode` |
| 5 | Uninstall removes only product dirs (config home only after explicit TTY confirmation) | **Automated**: full install on a throwaway `HOME` with decoy OpenCode files → symlink + install root removed, config home kept non-TTY (removed on TTY + `y`), decoy md5s identical |
| 6 | Two projects in one workspace keep deliverables fully separate | **Automated (scaffold level)**: second project scaffolded in one workspace gets its own complete tree; full two-project agent run = **manual pending** |
| 7 | One institutional account across projects: authorization recorded on both sides and enforced | **Automated**: both sides rendered by `init-workspace`; connector `prepare` for an existing project missing from `allowed_projects` fails with `account_not_authorized` |
| 8 | Context resolution first — `Company / Project / Account` declared before external actions, re-resolved on project switch | Clause present in all 5 agent prompts + all 6 command templates (`debug config` evidence); live behavior = **manual pending** |
| 9 | Publishing requires explicit confirmation binding account + project + full text + attachments + target; any change re-approves | **Automated (connector)**: `execute` with a wrong/stale token → `confirm_stale`; correct token → receipt. TUI confirm flow = **manual pending** |
| 10 | Research outputs label `EVIDENCE / INTERPRETATION / HYPOTHESIS` with citations | Encoded in every agent prompt + `audience-research` skill (`debug config` evidence); live research run = **manual pending** |
| 11 | Connector is structured JSON in/out; `execute` only via confirm token | **Automated**: `verify`/`prepare`/`execute`/`status` all return JSON `{ok,...}` / `{ok:false,error:{code,...}}` |
| 12 | External actions recorded in the append-only action log; no duplicate/blind retries | **Automated**: log line appended on execute; second execute → `duplicate` with prior `external_id` |
| 13 | First-run onboarding `/marketharness-init` walks workspace → company → project → model → optional Qloo → optional social → brief | **Automated (presence)**: command in rendered config + first-launch banner/next-steps reference it; full interactive run = **manual pending** |
| 14 | Simplicity: add a skill = drop `skills/<name>/SKILL.md`, discovered with zero code changes | **Automated**: temp skill added to the skills root → `debug skill` lists 9; removed → back to 8 |
| 15 | Identity by distribution (no fork): name, theme, logo, 5 agents, 6 commands purely from rendered profile | **Automated**: TUI home screen shows the 3-tier `marketharness` wordmark + tui config applied (boot log), slash menu lists all 6 commands, `agent list` shows 5 agents, `default_agent: marketing-lead` |
| 16 | Mandatory prohibitions enforced by shared config (`delete: deny`, `rm -rf *`/`sudo *`/`git push *` deny) | **Automated**: `marketharness debug config` output contains all four deny records |

Static smoke for this build: `bash -n` on `install.sh` + `bin/marketharness`,
`python3 -m json.tool` on every source and rendered JSON, zero placeholders
and zero credential-looking strings in the staged config, and the qloo render
verified in four states — CLI absent (entry omitted), CLI present with a
harness credential (rendered as `{"command":"qloo","args":["mcp"]}`),
`QLOO_API_KEY` in the environment (rendered, env passthrough only), CLI
present without a credential (omitted).

## License

MIT — see `LICENSE`. OpenCode attribution and third-party notes:
`THIRD_PARTY_NOTICES.md`.
