#!/usr/bin/env bash
# marketharness installer — hermetic OpenCode V1 distribution for a marketing team.
#
# Installs, idempotently:
#   1. the pinned OpenCode V1 runtime (opencode-ai@1.19.3) into its OWN npm
#      prefix: ~/.local/share/marketharness/opencode — never ~/.opencode,
#      never ~/.local/share/opencode*, never the system `opencode` command
#   2. the marketharness repo copy -> ~/.local/share/marketharness
#      (from MARKETHARNESS_SOURCE=<dir> — re-copied on every run — or by
#      cloning MARKETHARNESS_REPO_URL)
#   3. the rendered profile config -> ~/.config/marketharness/opencode
#      (staging runs through the launcher's --stage-only mode so install and
#      first run share ONE render implementation: placeholders, the Qloo gate,
#      .bak.<timestamp> backups of edited staged files)
#   4. the `marketharness` symlink -> ~/.local/bin/marketharness (collision
#      guard, PATH-shadow warning)
#
# The user's existing OpenCode install (~/.config/opencode,
# ~/.local/share/opencode*, ~/.opencode, credentials, sessions, the opencode
# binary) is NEVER read or written.
#
# Modes:
#   ./install.sh                 full install (see above)
#   ./install.sh --update        re-sync: source re-copy when
#                                MARKETHARNESS_SOURCE is set, else git
#                                fast-forward when installed from a clone
#                                (refuses a dirty or diverged checkout);
#                                edited staged config files are backed up as
#                                <file>.bak.<timestamp> before re-render
#   ./install.sh --uninstall     remove the symlink + install dir; the config
#                                home is removed only after an explicit
#                                confirmation on a TTY (kept otherwise)
#   ./install.sh --force         back up and replace a conflicting
#                                ~/.local/bin/marketharness entry
#
# Environment:
#   MARKETHARNESS_SOURCE    local checkout to install from (re-copied every run)
#   MARKETHARNESS_REPO_URL  git URL to clone when no source is given
#                          (default: https://github.com/naiamproducts/marketharness)
#   MARKETHARNESS_ROOT      install root (default: ~/.local/share/marketharness)
#   MARKETHARNESS_HOME      config home  (default: ~/.config/marketharness)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PRODUCT_VERSION="0.1.0"
OPENCODE_PIN="1.19.3"

INSTALL_ROOT="${MARKETHARNESS_ROOT:-$HOME/.local/share/marketharness}"
RUNTIME_PREFIX="$INSTALL_ROOT/opencode"
RUNTIME_BIN="$RUNTIME_PREFIX/node_modules/.bin/opencode"
CONFIG_HOME="${MARKETHARNESS_HOME:-$HOME/.config/marketharness}"
CONFIG_DIR="$CONFIG_HOME/opencode"

BIN_DIR="$HOME/.local/bin"
CLI_LINK="$BIN_DIR/marketharness"
CLI_TARGET="$INSTALL_ROOT/bin/marketharness"

REPO_URL="${MARKETHARNESS_REPO_URL:-https://github.com/naiamproducts/marketharness}"
ORIGINAL_PATH="$PATH"

# --- Presentation -----------------------------------------------------------
INDIGO=$'\033[38;5;105m'
MUTED=$'\033[38;5;245m'
BOLD=$'\033[1m'
RED=$'\033[38;5;203m'
RESET=$'\033[0m'
info() { printf '  \033[38;5;105m•\033[0m %s\n' "$*"; }
ok()   { printf '  \033[38;5;105m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[38;5;203m!\033[0m %s\n' "$*" >&2; }
fail() { printf '\n\033[38;5;203m✘ %s\033[0m\n\n' "$*" >&2; exit 1; }

usage() {
  awk 'NR>1 && /^set -euo pipefail/{exit} NR>1{sub(/^# ?/,""); print}' "${BASH_SOURCE[0]}"
}

# --- Flags ------------------------------------------------------------------
FORCE=0
UNINSTALL=0
UPDATE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --update) UPDATE=1 ;;
    --help|-h) usage; exit 0 ;;
    *) printf '%sUnknown option: %s (supported: --force, --update, --uninstall, --help)%s\n' "$RED" "$arg" "$RESET" >&2; exit 1 ;;
  esac
done

# --- Sudo helper (only ever used for missing required packages) -------------
SUDO_OK=0
need_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then SUDO_OK=0; return; fi
  if command -v sudo >/dev/null 2>&1; then
    info "This step needs root to install missing packages via the system package manager"
    sudo -v || fail "sudo authentication failed"
    SUDO_OK=1
    return
  fi
  fail "Missing required tools and no sudo available. Install them manually, then re-run:
  - git, curl, node, npm, python3
  Debian/Ubuntu:  sudo apt-get install -y git curl nodejs npm python3
  Fedora:         sudo dnf install -y git curl nodejs npm python3
  Arch:           sudo pacman -S --noconfirm git curl nodejs npm python3
  openSUSE:       sudo zypper -n install git curl nodejs npm python3"
}
as_root() {
  if [[ "$SUDO_OK" == "1" ]]; then sudo "$@"; else "$@"; fi
}

# --- 1. Preflight -----------------------------------------------------------
preflight() {
  printf '\n%smarketharness installer%s (OpenCode V1 %s, isolated)\n\n' "$INDIGO" "$RESET" "$OPENCODE_PIN"

  [[ "$(uname -s)" == "Linux" ]] \
    || fail "marketharness currently supports Linux only (detected: $(uname -s))."

  local pkgmgr="" m
  for m in apt-get dnf pacman zypper; do
    if command -v "$m" >/dev/null 2>&1; then pkgmgr="$m"; break; fi
  done
  info "Platform: linux/$(uname -m) (pkg manager: ${pkgmgr:-none detected})"

  local missing=() c
  for c in git curl node npm; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    info "Missing required tools: ${missing[*]}"
    need_sudo
    local pkgs=()
    for c in "${missing[@]}"; do
      case "$c" in
        node) pkgs+=(nodejs) ;;
        *)    pkgs+=("$c") ;;
      esac
    done
    # shellcheck disable=SC2207
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | sort -u)
    info "Installing via $pkgmgr: ${pkgs[*]}"
    case "$pkgmgr" in
      apt-get) as_root apt-get update -qq && as_root apt-get install -y "${pkgs[@]}" ;;
      dnf)     as_root dnf install -y "${pkgs[@]}" ;;
      pacman)  as_root pacman -S --noconfirm --needed "${pkgs[@]}" ;;
      zypper)  as_root zypper -n install "${pkgs[@]}" ;;
      *) fail "No supported package manager found to install: ${pkgs[*]}" ;;
    esac
    for c in "${missing[@]}"; do
      command -v "$c" >/dev/null 2>&1 || fail "'$c' is still missing after installation. Install it manually and re-run."
    done
  fi

  # python3 is required by the profile staging and bin/init-workspace.
  if ! command -v python3 >/dev/null 2>&1; then
    info "python3 not found — required to render the profile config"
    if [[ -n "$pkgmgr" ]]; then
      need_sudo
      case "$pkgmgr" in
        apt-get) as_root apt-get install -y python3 ;;
        dnf)     as_root dnf install -y python3 ;;
        pacman)  as_root pacman -S --noconfirm python3 ;;
        zypper)  as_root zypper -n install python3 ;;
      esac
    fi
    command -v python3 >/dev/null 2>&1 \
      || fail "python3 is required (profile rendering + workspace scaffolding). Install python3, then re-run."
  fi

  ok "Prerequisites present: git, curl, node ($(node --version 2>/dev/null || true)), npm, python3 ($(python3 --version 2>/dev/null | awk '{print $2}'))"
}

# --- 2. Pinned OpenCode V1 runtime (own npm prefix) -------------------------
install_runtime() {
  printf '\n%s[1/4]%s OpenCode V1 runtime (pinned)\n' "$INDIGO" "$RESET"

  if [[ -x "$RUNTIME_BIN" ]]; then
    local cur
    cur="$("$RUNTIME_BIN" --version 2>/dev/null || true)"
    if [[ "$cur" == "$OPENCODE_PIN" ]]; then
      ok "runtime already present: opencode-ai@$OPENCODE_PIN ($RUNTIME_BIN), skipping install"
      return
    fi
    info "runtime at $RUNTIME_BIN reports '$cur' (expected $OPENCODE_PIN) — reinstalling"
  fi

  command -v npm >/dev/null 2>&1 \
    || fail "npm not found (needed to install the pinned runtime)."
  info "npm install --prefix $RUNTIME_PREFIX opencode-ai@$OPENCODE_PIN"
  # npm's optional-dependency libc detection can flake on a cold cache; retry
  # once, it resolves on reify (same behavior as the reference installer).
  local attempt
  for attempt in 1 2; do
    if npm install --prefix "$RUNTIME_PREFIX" "opencode-ai@$OPENCODE_PIN" >/dev/null 2>&1; then
      break
    fi
    if [[ "$attempt" == "2" ]]; then
      fail "npm install of opencode-ai@$OPENCODE_PIN failed twice. Check your network/npm, then re-run."
    fi
    info "npm install flaked (libc detection), retrying once..."
  done

  [[ -x "$RUNTIME_BIN" ]] || fail "runtime binary missing at $RUNTIME_BIN after install"
  local ver
  ver="$("$RUNTIME_BIN" --version 2>/dev/null || true)"
  [[ "$ver" == "$OPENCODE_PIN" ]] || fail "installed runtime reports '$ver', expected $OPENCODE_PIN"
  ok "runtime ready: opencode-ai@$OPENCODE_PIN"
  info "your existing OpenCode install (~/.opencode, ~/.local/share/opencode*, the opencode command) was not touched"
}

# --- 3. Repo copy -----------------------------------------------------------
copy_source() {
  local src="$1"
  [[ -d "$src" ]] || fail "MARKETHARNESS_SOURCE=$src is not a directory"
  src="$(cd "$src" && pwd)"
  if [[ "$src" == "$(readlink -f "$INSTALL_ROOT" 2>/dev/null || echo x)" ]]; then
    info "Source IS the install dir — nothing to copy"
    return
  fi
  mkdir -p "$INSTALL_ROOT"
  # Re-sync copy: the tar excludes runtime dirs, git metadata and backups, so
  # re-copying refreshes product files without touching the pinned runtime,
  # local state, or any .bak.<ts> backups.
  info "Copying $src -> $INSTALL_ROOT (every run when MARKETHARNESS_SOURCE is set)"
  (cd "$src" && tar \
      --exclude=.git --exclude=opencode --exclude=node_modules \
      --exclude='*.bak.*' --exclude=__pycache__ --exclude='*.pyc' \
      --exclude=.connector-log.jsonl --exclude=.connector-pending.json \
      --exclude=.env -cf - .) \
    | (cd "$INSTALL_ROOT" && tar -xf -)
}

acquire_source() {
  printf '\n%s[2/4]%s marketharness repo copy\n' "$INDIGO" "$RESET"

  if [[ -n "${MARKETHARNESS_SOURCE:-}" ]]; then
    copy_source "$MARKETHARNESS_SOURCE"
  elif [[ -f "$CLI_TARGET" ]]; then
    ok "marketharness already installed at $INSTALL_ROOT (reusing; set MARKETHARNESS_SOURCE=<dir> to re-sync from a local checkout)"
  else
    info "Cloning $REPO_URL -> $INSTALL_ROOT"
    # The runtime is installed FIRST (step [1/4]) with --prefix
    # $INSTALL_ROOT/opencode, which already creates $INSTALL_ROOT. Cloning
    # directly into it always fails ("destination path already exists and is
    # not an empty directory"), so clone into a temp dir and merge the result
    # in, keeping the runtime and the .git metadata (so --update still works).
    local tmp
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/marketharness-clone.XXXXXX")" \
      || fail "cannot create a temporary directory for git clone"
    if ! git clone --depth 1 "$REPO_URL" "$tmp/repo"; then
      rm -rf "$tmp"
      fail "git clone failed. Overrides:
  local checkout:  MARKETHARNESS_SOURCE=<dir> ./install.sh
  other remote:    MARKETHARNESS_REPO_URL=<git url> ./install.sh"
    fi
    if [[ -e "$INSTALL_ROOT/.git" ]]; then
      rm -rf "$tmp"
      fail "$INSTALL_ROOT is already a git checkout, but $CLI_TARGET is missing (broken install).
Inspect with:  git -C $INSTALL_ROOT status
Or force a clean install:  rm -rf $INSTALL_ROOT && ./install.sh"
    fi
    mkdir -p "$INSTALL_ROOT"
    ( cd "$tmp/repo" && tar --exclude=opencode --exclude=node_modules -cf - . ) \
      | ( cd "$INSTALL_ROOT" && tar -xf - ) \
      || { rm -rf "$tmp"; fail "copying the cloned checkout into $INSTALL_ROOT failed"; }
    rm -rf "$tmp"
  fi

  [[ -f "$CLI_TARGET" ]] || fail "install incomplete: missing $CLI_TARGET"
  chmod +x "$CLI_TARGET" "$INSTALL_ROOT/bin/init-workspace" 2>/dev/null || true
  [[ -f "$INSTALL_ROOT/profile/opencode.json" ]] || fail "install incomplete: missing profile/opencode.json"
  ok "repo copy in place at $INSTALL_ROOT"
}

# --- 4. Rendered profile config (shared with the launcher) ------------------
# Staging runs the LAUNCHER's --stage-only mode: one render implementation
# everywhere (placeholder substitution, the Qloo gate — canonical `qloo mcp`
# entry, no credential in any config file, atomic writes, .bak.<timestamp>
# backups of edited staged files, loud placeholder + credential checks).
stage_config() {
  printf '\n%s[3/4]%s profile config -> %s\n' "$INDIGO" "$RESET" "$CONFIG_DIR"
  bash "$CLI_TARGET" --stage-only || fail "profile staging failed (see errors above)"
  placeholder_check
  ok "profile staged: opencode.json, tui.json, theme, logo plugin, 5 agents"
}

placeholder_check() {
  local leftovers
  leftovers="$(grep -RIl '__MARKETHARNESS_ROOT__\|__MARKETHARNESS_CONFIG__\|__QLOO_MCP__' \
                 "$CONFIG_DIR" 2>/dev/null || true)"
  [[ -z "$leftovers" ]] \
    || fail "placeholder(s) not substituted in the staged config:
$(printf '%s\n' "$leftovers")
Re-run ./install.sh --stage-only via the launcher (marketharness --stage-only)."

  # Official Qloo kit rule: never a credential in a client configuration file,
  # ever. The credential lives in the harness's private config or in the
  # environment of the process that starts `qloo mcp` — never in staged JSON.
  local leaked
  leaked="$(grep -RIl 'API_KEY\|apiKey' "$CONFIG_DIR" 2>/dev/null || true)"
  [[ -z "$leaked" ]] \
    || fail "credential-looking string(s) in the staged config — refusing:
$(printf '%s\n' "$leaked")
The rendered config must never carry a Qloo key (official Qloo kit rule)."
}

# --- 5. CLI symlink ---------------------------------------------------------
link_cli() {
  printf '\n%s[4/4]%s CLI symlink\n' "$INDIGO" "$RESET"
  info "Linking $CLI_TARGET -> $CLI_LINK"
  mkdir -p "$BIN_DIR"

  # Collision guard: refuse to clobber anything that is not our own symlink.
  if [[ -e "$CLI_LINK" || -L "$CLI_LINK" ]]; then
    if [[ -L "$CLI_LINK" && "$(readlink "$CLI_LINK")" == "$CLI_TARGET" ]]; then
      ok "marketharness already linked correctly"
    elif [[ "$FORCE" == "1" ]]; then
      local backup
      backup="$CLI_LINK.bak.$(date +%Y%m%d%H%M%S)"
      mv "$CLI_LINK" "$backup"
      info "Existing entry moved to $backup"
      ln -s "$CLI_TARGET" "$CLI_LINK"
      ok "marketharness linked (previous entry backed up)"
    else
      fail "$CLI_LINK exists and is not the marketharness launcher. Re-run with --force to back it up and replace it."
    fi
  else
    ln -s "$CLI_TARGET" "$CLI_LINK"
    ok "marketharness linked"
  fi

  # Shadow detection: resolve what the USER'S shell would run (this script
  # never modifies PATH, so $ORIGINAL_PATH is the caller's environment as-is).
  local shadow shadow_real target_real kind verb remedy
  shadow="$( (PATH="$ORIGINAL_PATH"; command -v marketharness) 2>/dev/null || true)"
  [[ "$shadow" == /* ]] || shadow=""
  if [[ -n "$shadow" ]]; then
    shadow_real="$(readlink -f "$shadow" 2>/dev/null || true)"
    target_real="$(readlink -f "$CLI_TARGET" 2>/dev/null || true)"
    if [[ -n "$shadow_real" && -n "$target_real" && "$shadow_real" != "$target_real" ]]; then
      if [[ -L "$shadow" ]]; then
        kind="symlink -> $(readlink "$shadow")"
        verb="Repoint it at the installed launcher, e.g.:"
        remedy="ln -sf $CLI_TARGET $shadow"
      else
        kind="regular file"
        verb="Remove it, e.g.:"
        remedy="mv $shadow $shadow.old"
      fi
      warn "WARNING: another 'marketharness' shadows the installed one:"
      printf '      %s  (%s)\n' "$shadow" "$kind" >&2
      printf '    Your commands would run that copy instead. %s\n' "$verb" >&2
      printf '      %s\n' "$remedy" >&2
    fi
  fi

  case ":$ORIGINAL_PATH:" in
    *":$BIN_DIR:"*) ok "\$HOME/.local/bin is on PATH" ;;
    *) info "NOTE: add $BIN_DIR to your PATH to run 'marketharness' directly" ;;
  esac
}

# --- Optional Qloo wiring (official Qloo Hackathon Kit) ----------------------
# marketharness NEVER installs the harness globally and NEVER writes a key:
# the credential lives in the harness's own private config (`qloo setup
# --qloo`) or in QLOO_API_KEY on the environment (server-style auth). The gate
# decision is made by the launcher's staging step and cached in .qloo-gate; a
# stale/absent cache is refreshed by `marketharness --stage-only`.
qloo_gate_field() {
  local key="$1" line gate="$CONFIG_HOME/.qloo-gate"
  [[ -f "$gate" ]] || return 0
  while IFS= read -r line; do
    case "$line" in
      "$key="*) printf '%s' "${line#*=}"; return 0 ;;
    esac
  done < "$gate"
}

# Optional readiness check through the `qloo_capabilities` MCP tool: it reports
# readiness WITHOUT calling Qloo (no network, no credential use), so it only
# depends on the harness being runnable. Bounded by a timeout, attempted only
# when the CLI is on PATH, and NEVER a hard failure.
qloo_capabilities_check() {
  command -v qloo >/dev/null 2>&1 || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  local runner=(python3 -) out
  if command -v timeout >/dev/null 2>&1; then runner=(timeout 40 python3 -); fi
  out="$("${runner[@]}" 2>/dev/null <<'PY' || true
import json
import subprocess
import sys


def read_reply(stream, want_id):
    for line in stream:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            continue
        if message.get("id") == want_id:
            return message
    return None


proc = subprocess.Popen(
    ["qloo", "mcp"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
    bufsize=1,
)
try:
    def send(payload):
        proc.stdin.write(json.dumps(payload) + "\n")
        proc.stdin.flush()

    send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2025-06-18",
        "capabilities": {},
        "clientInfo": {"name": "marketharness-installer", "version": "0.1.0"},
    }})
    init = read_reply(proc.stdout, 1)
    if not init:
        print("qloo mcp did not answer initialize")
        sys.exit(0)
    server = (init.get("result") or {}).get("serverInfo") or {}
    send({"jsonrpc": "2.0", "method": "notifications/initialized"})
    send({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
          "params": {"name": "qloo_capabilities", "arguments": {}}})
    capability = read_reply(proc.stdout, 2)
    if capability is None:
        print("qloo_capabilities did not answer")
    elif capability.get("error"):
        print("qloo_capabilities error: %s"
              % capability["error"].get("message", "unknown"))
    else:
        text = "".join(block.get("text", "")
                       for block in (capability.get("result") or {}).get("content", [])
                       if block.get("type") == "text")
        try:
            contract = json.loads(text).get("contract_version", "unknown")
        except ValueError:
            contract = "unknown"
        print("qloo_capabilities answered (harness %s, contract %s)"
              % (server.get("version", "unknown"), contract))
finally:
    try:
        proc.stdin.close()
    except Exception:
        pass
    try:
        proc.wait(timeout=5)
    except Exception:
        proc.kill()
PY
)"
  if [[ -n "$out" ]]; then
    ok "Qloo readiness: $out"
  else
    info "qloo_capabilities probe unavailable (harness unresponsive or timed out — never a failure; no network or credential is involved)"
  fi
}

qloo_note() {
  printf '\n%sQloo (optional — official @qloo/qloo-harness)%s\n' "$INDIGO" "$RESET"

  if ! command -v qloo >/dev/null 2>&1; then
    info "qloo CLI not found — mcp.qloo omitted from the render (Qloo research stays optional)"
    cat <<'EOF'
  marketharness never installs the harness for you (your npm prefix, your
  Node). To enable Qloo, run the official steps yourself:

    npm install --global @qloo/qloo-harness    # requires Node >= 22.19
    qloo setup --qloo                          # key -> the harness's PRIVATE
                                                # config (never a config file,
                                                # never a repo, never a demo)
    qloo setup --status                        # confirm: "Qloo data: live"
    marketharness --stage-only                 # re-render with mcp.qloo
EOF
    return 0
  fi

  # The version warning is printed by the launcher during staging above
  # (single source of truth: warn, never fail, on harness < 0.1.26).
  case "$(qloo_gate_field credential)" in
    environment) ok "Qloo MCP: wired (canonical qloo mcp; credential: QLOO_API_KEY env)" ;;
    harness)     ok "Qloo MCP: wired (canonical qloo mcp; credential: qloo setup --qloo)" ;;
    unknown)     info "Qloo MCP: rendered (credential state unknown — the harness returns its own auth error)" ;;
    missing)     info "Qloo MCP: no credential — mcp.qloo omitted (run: qloo setup --qloo, then marketharness --stage-only)" ;;
    "")          info "Qloo MCP: gate not staged yet (run: marketharness --stage-only)" ;;
    *)           info "Qloo MCP: unexpected gate state (run: marketharness --stage-only to re-check)" ;;
  esac
  qloo_capabilities_check
}

# --- Sanity ------------------------------------------------------------------
sanity() {
  printf '\n%sSanity check%s\n' "$INDIGO" "$RESET"

  local ver run agent_out
  ver="$("$RUNTIME_BIN" --version 2>/dev/null | head -1 || true)"
  printf '  runtime      opencode-ai@%s (installed: %s)\n' "$OPENCODE_PIN" "${ver:-NOT RUNNABLE}"
  printf '  install root %s\n' "$INSTALL_ROOT"
  printf '  config home  %s\n' "$CONFIG_HOME"
  printf '  config file  %s\n' "$CONFIG_DIR/opencode.json"
  printf '  launcher     %s\n' "$CLI_LINK"
  [[ -n "$ver" && "$ver" == "$OPENCODE_PIN" ]] || fail "runtime is not runnable/reports wrong version ('$ver')"

  placeholder_check

  # Run the launcher exactly as the user's shell resolves it (a stale copy
  # earlier on PATH would outrank our symlink).
  run="$( (PATH="$ORIGINAL_PATH"; command -v marketharness) 2>/dev/null || true)"
  [[ "$run" == /* ]] || run="$CLI_LINK"
  if ! agent_out="$("$run" agent list 2>&1)"; then
    fail "'marketharness agent list' failed:
$agent_out"
  fi
  # `agent list` prints full permission records (very large). Extract just the
  # agent header lines. NOTE: no `grep -q` here — under pipefail a grep -q
  # that exits early SIGPIPEs the printf and fails the pipeline even on a
  # match; the substring tests below are plain bash pattern matching instead.
  local agent_names
  agent_names="$(printf '%s\n' "$agent_out" \
    | grep -E '^[A-Za-z0-9_-]+ \((primary|subagent)\)$' || true)"
  [[ "$agent_names" == *marketing-lead* ]] \
    || fail "agent list does not show marketing-lead:
$agent_names"
  [[ "$agent_names" == *audience-researcher* ]] \
    || fail "agent list does not show the audience-researcher subagent:
$agent_names"
  printf '  agents      \n%s\n' "$(printf '%s\n' "$agent_names" | sed 's/^/    /')"
  ok "agent list OK (marketing-lead primary + audience-researcher subagent present)"
  ok "placeholders in staged config: 0"
}

next_steps() {
  cat <<EOF

${INDIGO}✔ marketharness installed.${RESET} (product $PRODUCT_VERSION, OpenCode V1 $OPENCODE_PIN, isolated)

${BOLD}Next steps${RESET}
  1. Make sure $BIN_DIR is on your PATH, then start the TUI: ${BOLD}marketharness${RESET}
  2. Scaffold a workspace and open it:
       marketharness init-workspace ~/workspaces/<name> --company <slug> --project <slug>
       marketharness ~/workspaces/<name>/companies/<slug>/projects/<slug>
  3. Inside the TUI run the first-run onboarding command:
       ${BOLD}/marketharness-init${RESET}
     workspace -> company -> project -> model -> optional Qloo -> optional social -> first brief.
  4. Pick an available model when asked (${BOLD}marketharness models${RESET}); if none is usable,
     the onboarding flow offers provider setup WITHOUT touching your existing
     OpenCode credentials (copy-only, explicit — never automatic).

${MUTED}Isolation: runtime in $RUNTIME_PREFIX, config in $CONFIG_HOME.
Your OpenCode install (~/.config/opencode, ~/.local/share/opencode*,
~/.opencode, credentials, sessions) and your workspaces were never touched.${RESET}

EOF
}

# --- Update mode (`marketharness update` / ./install.sh --update) ------------
# Re-syncs the repo copy and re-renders the staged config. Edited staged
# config files are backed up as <file>.bak.<timestamp> by the staging step
# before they are replaced. The pinned runtime is a separate component and is
# not changed (re-run a fresh install if the pin ever changes).
run_update() {
  printf '\n%smarketharness update%s\n\n' "$INDIGO" "$RESET"
  [[ -f "$CLI_TARGET" ]] || fail "No marketharness install found at $INSTALL_ROOT. Install first: ./install.sh"
  command -v python3 >/dev/null 2>&1 || fail "python3 is required to re-render the profile config"

  if [[ -n "${MARKETHARNESS_SOURCE:-}" ]]; then
    copy_source "$MARKETHARNESS_SOURCE"
  elif git -C "$INSTALL_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    local branch leftovers mode_only f old_sha new_sha
    branch="$(git -C "$INSTALL_ROOT" symbolic-ref --short HEAD 2>/dev/null || true)"
    [[ -n "$branch" ]] \
      || fail "The checkout at $INSTALL_ROOT is in detached-HEAD state; re-install instead (./install.sh)."
    # Refuse to run over user edits. Mode-only changes (the installer's own
    # chmod +x) are installer noise, not user work — filtered out and absorbed.
    leftovers="$(git -C "$INSTALL_ROOT" diff --numstat | grep -v $'^0\t0\t' || true)"
    leftovers+="$(git -C "$INSTALL_ROOT" diff --cached --numstat)"
    leftovers+="$(git -C "$INSTALL_ROOT" ls-files --others --exclude-standard)"
    if [[ -n "${leftovers//[[:space:]]/}" ]]; then
      fail "The checkout at $INSTALL_ROOT has local modifications; refusing to update over them.
Inspect with:  git -C $INSTALL_ROOT status
Commit or stash your changes there, then re-run 'marketharness update'."
    fi
    mode_only="$(git -C "$INSTALL_ROOT" diff --numstat | grep $'^0\t0\t' | cut -f3- || true)"
    if [[ -n "$mode_only" ]]; then
      while IFS= read -r f; do
        [[ -n "$f" ]] && git -C "$INSTALL_ROOT" checkout -- "$f"
      done <<<"$mode_only"
      info "Absorbed mode-only changes (chmod +x on files in the checkout)"
    fi
    old_sha="$(git -C "$INSTALL_ROOT" rev-parse HEAD)"
    info "Fetching origin $branch..."
    git -C "$INSTALL_ROOT" fetch --quiet origin "$branch" \
      || fail "git fetch from origin failed (network?). Nothing was changed."
    if ! git -C "$INSTALL_ROOT" merge-base --is-ancestor HEAD "origin/$branch"; then
      fail "The checkout at $INSTALL_ROOT has local commits not on origin/$branch (diverged).
Refusing to reset or overwrite local work. Inspect with:
  git -C $INSTALL_ROOT log --oneline origin/$branch..HEAD"
    fi
    new_sha="$(git -C "$INSTALL_ROOT" rev-parse "origin/$branch")"
    if [[ "$old_sha" == "$new_sha" ]]; then
      ok "Already up to date (origin/$branch @ ${new_sha:0:7})"
    else
      git -C "$INSTALL_ROOT" merge --ff-only --quiet "origin/$branch" \
        || fail "Fast-forward merge failed; nothing beyond the fetch was changed."
      ok "Updated to $(git -C "$INSTALL_ROOT" rev-parse --short HEAD)"
    fi
  else
    fail "The install at $INSTALL_ROOT is not a git clone (it was installed from a local source copy), so --update cannot refresh it automatically.
Re-run with your local checkout:  MARKETHARNESS_SOURCE=<dir> ./install.sh --update"
  fi

  chmod +x "$CLI_TARGET" "$INSTALL_ROOT/bin/init-workspace" 2>/dev/null || true
  printf '\n'
  stage_config
  link_cli
  qloo_note
  printf '\n%sDone.%s Runtime unchanged (opencode-ai@%s). Restart marketharness to pick up changes.\n\n' "$INDIGO" "$RESET" "$OPENCODE_PIN"
}

# --- Uninstall mode ---------------------------------------------------------
# Removes ONLY product dirs: the CLI symlink (when it is ours), the install
# root (runtime + repo copy), and — after an explicit confirmation on a TTY —
# the config home. Never touches OpenCode or user workspaces.
run_uninstall() {
  printf '\n%smarketharness uninstall%s\n\n' "$INDIGO" "$RESET"

  if [[ -L "$CLI_LINK" ]]; then
    if [[ "$(readlink "$CLI_LINK")" == "$CLI_TARGET" ]]; then
      rm -f "$CLI_LINK"
      ok "removed symlink $CLI_LINK"
    else
      warn "leaving $CLI_LINK alone (it points at $(readlink "$CLI_LINK"), not the marketharness launcher)"
    fi
  elif [[ -e "$CLI_LINK" ]]; then
    warn "leaving $CLI_LINK alone (it exists and is not a marketharness symlink)"
  else
    info "no symlink at $CLI_LINK"
  fi

  if [[ -d "$INSTALL_ROOT" ]]; then
    [[ -n "$INSTALL_ROOT" && "$INSTALL_ROOT" != "/" && "$INSTALL_ROOT" != "$HOME" ]] \
      || fail "refusing to remove suspicious install root: '$INSTALL_ROOT'"
    [[ -e "$INSTALL_ROOT/bin/marketharness" || -e "$INSTALL_ROOT/opencode" ]] \
      || fail "refusing to remove $INSTALL_ROOT: does not look like a marketharness install (no bin/marketharness, no opencode/ runtime)"
    rm -rf "$INSTALL_ROOT"
    ok "removed install root $INSTALL_ROOT (repo copy + pinned runtime)"
  else
    info "no install root at $INSTALL_ROOT"
  fi

  if [[ -d "$CONFIG_HOME" ]]; then
    local answer=""
    if [[ -t 0 ]]; then
      printf '  Remove the marketharness config home %s as well? [y/N] ' "$CONFIG_HOME"
      read -r answer || answer=""
    fi
    case "$answer" in
      y|Y|yes|YES)
        rm -rf "$CONFIG_HOME"
        ok "removed config home $CONFIG_HOME"
        ;;
      *)
        info "kept config home $CONFIG_HOME (confirm on a TTY to remove it, or delete it manually)"
        ;;
    esac
  fi

  printf '\n%sNote:%s marketharness never touched your OpenCode install\n(~/.config/opencode, ~/.local/share/opencode*, ~/.opencode) or your\nworkspaces — that is still true after uninstall.\n\n' "$MUTED" "$RESET"
}

# --- Run ---------------------------------------------------------------------
if [[ "$UNINSTALL" == "1" ]]; then
  run_uninstall
  exit 0
fi

if [[ "$UPDATE" == "1" ]]; then
  run_update
  exit 0
fi

preflight
install_runtime
acquire_source
stage_config
link_cli
qloo_note
sanity
next_steps
