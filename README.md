# marketagents

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
optional Qloo MCP that is only wired in when you actually have a credential.

## Quick start

```bash
./install.sh      # preflight -> pinned runtime -> repo copy -> rendered config -> CLI link
marketagents      # first launch prints the onboarding checklist
# inside the TUI:
/marketagents-init
```

`./install.sh` installs by cloning `MARKETAGENTS_REPO_URL` into
`~/.local/share/marketagents`; to install the checkout you are currently in
(the pre-release path), run:

```bash
MARKETAGENTS_SOURCE=$PWD ./install.sh
```

Overrides: `MARKETAGENTS_REPO_URL=<git url>` (clone source) ·
`MARKETAGENTS_SOURCE=<dir>` (local checkout, re-copied on every run) ·
`MARKETAGENTS_ROOT=<dir>` (install root) · `MARKETAGENTS_HOME=<dir>` (config home).

First run: the launcher stages the profile (placeholders rendered, zero
leftovers enforced), prints the next steps, and opens the TUI with
`marketing-lead` as the default agent. Then:

1. `marketagents init-workspace ~/workspaces/<name> --company <slug> --project <slug>`
2. `marketagents ~/workspaces/<name>/companies/<slug>/projects/<slug>`
3. `/marketagents-init` — onboarding: workspace → company → project → model →
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
| `/marketagents-init` | First-run onboarding (workspace → company → project → model → optional Qloo → optional social → first brief) |
| `/marketagents-brief` | brief-intake → route to research/growth |
| `/marketagents-research` | Audience research flow with evidence labels (research agent) |
| `/marketagents-experiment` | Design an experiment with pre-registered thresholds (growth) |
| `/marketagents-publish` | prepare → confirm → execute → log — the **only** command that may reach the connector's `execute` (community) |
| `/marketagents-report` | results-review consolidation: verdict per experiment |

## Workspace tree (scaffolded by `marketagents init-workspace <dir>`)

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

`marketagents` never reads or writes your existing OpenCode installation —
`~/.config/opencode`, `~/.local/share/opencode*`, `~/.opencode`, credentials,
sessions, plugins, or the `opencode` command.

- **Own runtime**: it execs only
  `~/.local/share/marketagents/opencode/node_modules/.bin/opencode`
  (pinned `opencode-ai@1.19.3`); a system `opencode` on `PATH` is never used
  (verified with a poisoned `opencode` shim on `PATH`).
- **Own XDG dirs**: `XDG_CONFIG_HOME/DATA_HOME/STATE_HOME/CACHE_HOME` all live
  under `~/.config/marketagents`, plus an explicit
  `OPENCODE_CONFIG=~/.config/marketagents/opencode/opencode.json`
  (`OPENCODE_CONFIG_DIR` is defensively unset so a globally exported one can't
  add config sources). `marketagents debug paths` shows every runtime path
  under the product config home.
- **Own skill set**: V1's automatic external-skill scan (`~/.claude/skills`,
  `~/.agents/skills`) is disabled by default
  (`OPENCODE_DISABLE_EXTERNAL_SKILLS=1`; export `0` to opt back in), so a
  session sees exactly the distribution's 8 skills plus built-ins.
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

## Model first run (SPEC §9)

marketagents ships no credentials and never reads your existing OpenCode
credentials. On first run, pick a model when asked (`marketagents models`);
if no usable model is available, the `/marketagents-init` onboarding flow
offers provider configuration **without touching your existing OpenCode
setup** — any future import would be copy-only and explicit, never automatic.

## Install / update / uninstall

```bash
./install.sh                 # full install (idempotent — safe to re-run)
./install.sh --force         # back up and replace a conflicting ~/.local/bin/marketagents
./install.sh --update        # re-sync: source re-copy (MARKETAGENTS_SOURCE) or
                             # git fast-forward when cloned (refuses dirty/diverged);
                             # edited staged config is backed up as <file>.bak.<ts>
./install.sh --uninstall     # remove symlink + install root; config home only after
                             # an explicit TTY confirmation, kept otherwise
```

- The launcher's subcommands: `marketagents init-workspace <dir>`,
  `marketagents update`, `marketagents help`, `marketagents --version`
  (product version + runtime pin + config paths + qloo state), plus an
  optional positional dir (`marketagents <workspace-or-project-dir>`).
  Anything else is passed through to the pinned runtime unchanged.
- Symlink installation has a collision guard (a foreign `~/.local/bin/
  marketagents` is never clobbered without `--force`, which backs it up) and
  warns when another `marketagents` shadows the installed one on your `PATH`.
- **Qloo**: with no `QLOO_API_KEY`, install prints `Qloo MCP: disabled
  (optional)` and the render omits the `mcp.qloo` entry entirely. The entry
  is wired in only when `QLOO_API_KEY` is set **and** the `qloo` CLI is on
  `PATH`.

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
| 1 | Installing marketagents does not modify the user's OpenCode config (`~/.config/opencode`) | **Automated**: md5 manifest of all 8,143 entries (files + symlinks) before/after full install — `diff` empty |
| 2 | Launching (TUI + non-interactive) does not modify the user's OpenCode config or legacy home; runtime state stays under `MARKETAGENTS_HOME` | **Automated**: `~/.config/opencode` md5 manifest and `~/.opencode` inode/size/mtime listing before/after install + full TUI session — both diffs **empty**; `marketagents debug paths` shows data/state/cache under `~/.config/marketagents` (its own `opencode.db` + log live there). A supplementary metadata snapshot of `~/.local/share/opencode` showed changes only in the *host* OpenCode session's own bookkeeping (global log append, session-db shm/wal, shell-output rotation of the instance running the test) — reproduced by a no-marketagents control run and with zero `marketagents` entries added there |
| 3 | Runs only its own pinned runtime; never the system `opencode` command | **Automated**: `marketagents --version` reports only its own paths; `marketagents agent list` succeeds with a poisoned `opencode` shim (exit 42) at the front of `PATH` |
| 4 | Side-by-side coexistence: own runtime + own XDG dirs, nothing shared | **Automated**: `marketagents debug paths` shows data/config/cache/state all under `~/.config/marketagents`; runtime lives in `~/.local/share/marketagents/opencode` |
| 5 | Uninstall removes only product dirs (config home only after explicit TTY confirmation) | **Automated**: full install on a throwaway `HOME` with decoy OpenCode files → symlink + install root removed, config home kept non-TTY (removed on TTY + `y`), decoy md5s identical |
| 6 | Two projects in one workspace keep deliverables fully separate | **Automated (scaffold level)**: second project scaffolded in one workspace gets its own complete tree; full two-project agent run = **manual pending** |
| 7 | One institutional account across projects: authorization recorded on both sides and enforced | **Automated**: both sides rendered by `init-workspace`; connector `prepare` for an existing project missing from `allowed_projects` fails with `account_not_authorized` |
| 8 | Context resolution first — `Company / Project / Account` declared before external actions, re-resolved on project switch | Clause present in all 5 agent prompts + all 6 command templates (`debug config` evidence); live behavior = **manual pending** |
| 9 | Publishing requires explicit confirmation binding account + project + full text + attachments + target; any change re-approves | **Automated (connector)**: `execute` with a wrong/stale token → `confirm_stale`; correct token → receipt. TUI confirm flow = **manual pending** |
| 10 | Research outputs label `EVIDENCE / INTERPRETATION / HYPOTHESIS` with citations | Encoded in every agent prompt + `audience-research` skill (`debug config` evidence); live research run = **manual pending** |
| 11 | Connector is structured JSON in/out; `execute` only via confirm token | **Automated**: `verify`/`prepare`/`execute`/`status` all return JSON `{ok,...}` / `{ok:false,error:{code,...}}` |
| 12 | External actions recorded in the append-only action log; no duplicate/blind retries | **Automated**: log line appended on execute; second execute → `duplicate` with prior `external_id` |
| 13 | First-run onboarding `/marketagents-init` walks workspace → company → project → model → optional Qloo → optional social → brief | **Automated (presence)**: command in rendered config + first-launch banner/next-steps reference it; full interactive run = **manual pending** |
| 14 | Simplicity: add a skill = drop `skills/<name>/SKILL.md`, discovered with zero code changes | **Automated**: temp skill added to the skills root → `debug skill` lists 9; removed → back to 8 |
| 15 | Identity by distribution (no fork): name, theme, logo, 5 agents, 6 commands purely from rendered profile | **Automated**: TUI home screen shows the 3-tier `marketagents` wordmark + tui config applied (boot log), slash menu lists all 6 commands, `agent list` shows 5 agents, `default_agent: marketing-lead` |
| 16 | Mandatory prohibitions enforced by shared config (`delete: deny`, `rm -rf *`/`sudo *`/`git push *` deny) | **Automated**: `marketagents debug config` output contains all four deny records |

Static smoke for this build: `bash -n` on `install.sh` + `bin/marketagents`,
`python3 -m json.tool` on every source and rendered JSON, zero placeholders in
the staged config, qloo render verified with and without `QLOO_API_KEY`.

## License

MIT — see `LICENSE`. OpenCode attribution and third-party notes:
`THIRD_PARTY_NOTICES.md`.
