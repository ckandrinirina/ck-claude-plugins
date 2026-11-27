#!/usr/bin/env bash
# playground.sh — throwaway test projects for the LOCAL ck-code / ck-code-lite / ck-oneshot copies.
#
# Each project is its own git repo under playground/<name>/, created from
# playground/fixture/ (a tiny Node 24 TypeScript CLI) — or, for `shot`, from
# playground/fixture-shot/ (documents only: a PRD and an API note). The projects are gitignored;
# only the fixture and this script are tracked. Claude runs are non-interactive
# (`claude -p`) and load the plugin from ./ck-code or ./ck-code-lite via
# --plugin-dir. Each project's .claude/settings.json turns the marketplace copies
# off, so commands are never listed twice. It also enables the Claude Code sandbox, with no
# way out: Bash writes stay inside the project (plus the npm and tool caches), the network
# reaches only the package registries and context7, a server may listen on a local port (the
# ck-oneshot boot check), and a command can never retry unsandboxed. acceptEdits only
# auto-approves edits inside the project. There is no permission-bypass mode.
#
# Usage:
#   scripts/playground.sh reset <code|lite|shot|all>   # recreate from the fixture, one baseline commit
#   scripts/playground.sh run <code|lite|shot|shot-lite|shot-code> <prompt>
#                                                      # claude -p in the project, log to playground/logs/
#   scripts/playground.sh status [code|lite|shot]      # branches, recent commits, dirty files
#
# shot-lite and shot-code run ck-code-lite or ck-code in the ck-oneshot project (the take-over
# check).
#
# Env: PLAYGROUND_MODEL (optional --model), PLAYGROUND_MAX_TURNS (default 60),
#      (PLAYGROUND_UNSAFE is gone: the sandbox's registry allowlist covers what it was for.)

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG="$ROOT/playground"

die() { echo "playground: $*" >&2; exit 1; }

# name -> project dir and plugin dir
resolve() {
  case "$1" in
    code) PROJECT="$PG/ck-code-demo";  PLUGIN="$ROOT/ck-code";       FIXTURE="$PG/fixture" ;;
    lite) PROJECT="$PG/ck-lite-demo";  PLUGIN="$ROOT/ck-code-lite";  FIXTURE="$PG/fixture" ;;
    shot) PROJECT="$PG/ck-shot-demo";  PLUGIN="$ROOT/ck-oneshot";    FIXTURE="$PG/fixture-shot" ;;
    shot-lite) PROJECT="$PG/ck-shot-demo"; PLUGIN="$ROOT/ck-code-lite"; FIXTURE="$PG/fixture-shot" ;;
    shot-code) PROJECT="$PG/ck-shot-demo"; PLUGIN="$ROOT/ck-code";      FIXTURE="$PG/fixture-shot" ;;
    *) die "unknown project '$1' (expected code, lite, shot, shot-lite or shot-code)" ;;
  esac
  [ -f "$PLUGIN/.claude-plugin/plugin.json" ] || die "no plugin at $PLUGIN"
}

reset_one() {
  resolve "$1"
  case "$PROJECT" in "$PG"/ck-*-demo) ;; *) die "refusing to delete $PROJECT" ;; esac
  rm -rf "$PROJECT"
  cp -R "$FIXTURE" "$PROJECT"
  mkdir -p "$PROJECT/.claude"
  cat > "$PROJECT/.claude/settings.json" <<'EOF'
{
  "enabledPlugins": {
    "ck-code@ck-marketplace": false,
    "ck-code-lite@ck-marketplace": false,
    "ck-oneshot@ck-marketplace": false
  },
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "failIfUnavailable": true,
    "network": {
      "allowedDomains": [
        "registry.npmjs.org", "*.npmjs.org", "registry.yarnpkg.com",
        "pypi.org", "files.pythonhosted.org",
        "crates.io", "index.crates.io", "static.crates.io",
        "proxy.golang.org", "sum.golang.org",
        "context7.com", "*.context7.com"
      ],
      "allowLocalBinding": true
    },
    "filesystem": { "allowWrite": ["~/.npm", "~/.cache"] }
  },
  "permissions": {
    "defaultMode": "acceptEdits",
    "deny": ["WebFetch", "WebSearch", "Bash(git push:*)", "Bash(gh:*)", "Bash(curl:*)", "Bash(wget:*)"]
  }
}
EOF
  git -C "$PROJECT" init -q -b main
  git -C "$PROJECT" add -A
  git -C "$PROJECT" -c user.name=playground -c user.email=playground@localhost \
    commit -q -m "chore: baseline from playground fixture"
  echo "reset $1 -> $PROJECT ($(jq -r .version "$PLUGIN/.claude-plugin/plugin.json") local)"
}

run_one() {
  local name="${1:-}"; shift || true
  [ $# -gt 0 ] || die "run needs a prompt"
  resolve "$name"
  [ -d "$PROJECT/.git" ] || reset_one "$name"
  mkdir -p "$PG/logs"
  local log="$PG/logs/$(basename "$PROJECT")-$(date +%Y%m%d-%H%M%S).log"
  # project,local only: the user's own hooks, plugins and settings stay out of the test.
  local args=(-p --setting-sources project,local --plugin-dir "$PLUGIN" --add-dir "$PLUGIN" --max-turns "${PLAYGROUND_MAX_TURNS:-60}")
  [ -z "${PLAYGROUND_UNSAFE:-}" ] || die "PLAYGROUND_UNSAFE is gone — runs stay in the sandbox (registries allowed); unset it"
  # Passed as a flag: settings.json allow rules are ignored in an untrusted workspace.
  args+=(--permission-mode acceptEdits --allowedTools
         "Bash(git:*) Bash(node:*) Bash(npm:*) Bash(npx:*) Bash(bash:*) Bash(sh:*) Bash(ck-*)
          Bash(mkdir:*) Bash(cp:*) Bash(mv:*) Bash(rm:*) Bash(touch:*) Bash($PLUGIN/bin/*) Bash(cd:*)")
  [ -n "${PLAYGROUND_MODEL:-}" ] && args+=(--model "$PLAYGROUND_MODEL")
  echo "== $(basename "$PROJECT") | prompt: $*" | tee "$log"
  # the local plugin's scripts, never an installed copy's: drop every cached plugin bin/ from PATH
  local p; p="$PLUGIN/bin:$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/.claude/plugins/' | paste -sd: -)"
  (cd "$PROJECT" && PATH="$p" claude "${args[@]}" -- "$*" < /dev/null) 2>&1 | tee -a "$log"
  echo "== log: $log"
}

status_one() {
  resolve "$1"
  echo "== $(basename "$PROJECT")"
  [ -d "$PROJECT/.git" ] || { echo "   (not created — run reset $1)"; return; }
  git -C "$PROJECT" branch --list | sed 's/^/   /'
  git -C "$PROJECT" log --oneline -5 | sed 's/^/   /'
  git -C "$PROJECT" status --short | sed 's/^/   /'
}

cmd="${1:-}"; shift || true
case "$cmd" in
  reset)  case "${1:-}" in all) reset_one code; reset_one lite; reset_one shot ;; *) reset_one "${1:-}" ;; esac ;;
  run)    run_one "$@" ;;
  status) if [ $# -gt 0 ]; then status_one "$1"; else status_one code; status_one lite; status_one shot; fi ;;
  *) sed -n '2,24p' "$0"; exit 1 ;;
esac
