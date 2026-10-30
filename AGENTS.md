# AGENTS.md — marketagents (development)

Rules for people and agents **developing this repo**. The shipped product's runtime
context lives in workspace files, not here.

## Purpose

marketagents is a marketing-team distribution of **OpenCode V1 only**: own runtime
pin, own XDG dirs, own rendered config — identity by distribution, zero source-fork
changes. `docs/SPEC.md` is authoritative; when code and SPEC disagree, fix the code.

## Layout

- `docs/SPEC.md` — architecture spec (source of truth)
- `profile/` — config source rendered by `install.sh` into `~/.config/marketagents`
  (`opencode.json`, `agent/*.md`, `tui.json`, `themes/`, `tui-plugins/`)
- `skills/`, `connectors/`, `bin/`, `install.sh`, `workspace-template/` — see SPEC §2
  (skills: SPEC §4, connectors: SPEC §7, workspace: SPEC §5)

## Rules

1. **V1 only.** Target the pinned runtime `opencode-ai@1.19.3` (own npm prefix).
   No V2-only config keys, agents, or TUI slots. Do not add a source fork.
2. **Verify on the pinned tag.** Before relying on any OpenCode capability
   (config key, permission behavior, skill/MCP/TUI support), verify it against
   `opencode-ai@1.19.3` itself — binary schema, embedded docs, or a running
   instance. Never assume from other versions or from memory.
3. **English artifacts.** Config, prompts, skills, docs, and commit messages are
   written in English.
4. **Conventional commits** (`feat:`, `fix:`, `docs:`, `chore:`, ...). No AI
   attribution or `Co-Authored-By` trailers.
5. **Placeholders stay literal in `profile/`**: `__MARKETAGENTS_ROOT__` (skills
   root) and `__MARKETAGENTS_CONFIG__` (rendered tui.json dir) are substituted by
   `install.sh`; never bake absolute dev paths into committed profile files.
