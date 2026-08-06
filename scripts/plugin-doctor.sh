#!/usr/bin/env bash
# plugin-doctor.sh — report what is broken across the ck marketplace plugins.
#
# Every check here exists because the defect it catches actually shipped. Run it
# before any release; `update-skill` Phase 3.0 runs it automatically.
#
# Usage:
#   scripts/plugin-doctor.sh                 # check every plugin
#   scripts/plugin-doctor.sh ck-code         # check one plugin
#   scripts/plugin-doctor.sh --quiet         # print only WARN/ERROR lines
#
# Exit status: 0 clean or warnings only, 1 if any ERROR was found.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

QUIET=0
PLUGINS=()
for a in "$@"; do
  case "$a" in
    --quiet|-q) QUIET=1 ;;
    -*) echo "plugin-doctor: unknown flag $a" >&2; exit 2 ;;
    *) PLUGINS+=("$a") ;;
  esac
done
[ ${#PLUGINS[@]} -eq 0 ] && PLUGINS=(ck-code ck-code-lite ck-tools)

# Almost every check below shells out to python3; without it they would read empty
# output as a pass. A release gate must fail loudly, never silently degrade.
command -v python3 >/dev/null 2>&1 || {
  echo "plugin-doctor: python3 is required — install it and re-run." >&2
  exit 1
}

ERRORS=0
WARNS=0

# ---- output helpers ----------------------------------------------------------
# row LABEL DETAIL STATUS — aligned "  label   detail ..... STATUS" line.
row() {
  local label="$1" detail="$2" status="$3" line
  case "$status" in
    ERROR) ERRORS=$((ERRORS+1)) ;;
    WARN)  WARNS=$((WARNS+1)) ;;
    OK)    [ "$QUIET" -eq 1 ] && return 0 ;;
  esac
  line=$(printf '  %-13s %s ' "$label" "$detail")
  printf '%s' "$line"
  local n=$(( 62 - ${#line} )); [ "$n" -lt 3 ] && n=3
  printf '%*s' "$n" '' | tr ' ' '.'
  printf ' %s\n' "$status"
}
detail_of() { printf '%s' "$1"; }

# ---- checks ------------------------------------------------------------------

# Frontmatter must parse as YAML. The failure that motivated this check: a `": "`
# inside an unquoted description silently voids the ENTIRE frontmatter, so the
# skill registers with no name and no description and simply does not exist.
check_frontmatter() {
  local plugin="$1" files
  files=$(ls "$plugin"/skills/*/SKILL.md "$plugin"/agents/*.md 2>/dev/null)
  [ -z "$files" ] && { row frontmatter "no skills or agents" OK; return; }

  local out
  if command -v ruby >/dev/null 2>&1; then
    out=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 ruby -ryaml -e '
      ARGV.each do |f|
        fm = File.read(f)[/\A---\n(.*?)\n---\n/m, 1]
        (puts "#{f}: no frontmatter fence"; next) if fm.nil?
        begin
          d = YAML.safe_load(fm)
          puts "#{f}: frontmatter is not a mapping" unless d.is_a?(Hash)
          puts "#{f}: missing name" if d.is_a?(Hash) && d["name"].to_s.empty?
        rescue => e
          puts "#{f}: #{e.message.lines.first.strip}"
        end
      end')
  else
    # No ruby: fall back to the one rule that actually breaks in practice.
    out=$(printf '%s\n' "$files" | while IFS= read -r f; do
      awk -v F="$f" '
        NR==1 && $0!="---" { print F": no frontmatter fence"; exit }
        NR==1 { next }
        $0=="---" { exit }
        /^[A-Za-z][A-Za-z0-9_-]*:[ \t]/ {
          v=$0; sub(/^[^:]*:[ \t]*/,"",v)
          if (v !~ /^["'"'"'\[{|>]/ && v ~ /:[ \t]/)
            print F": unquoted value contains \": \" — YAML will reject the block"
        }' "$f"
    done)
  fi

  local nskills nagents
  nskills=$(ls -d "$plugin"/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
  nagents=$(ls "$plugin"/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ -n "$out" ]; then
    row frontmatter "$(printf '%s\n' "$out" | awk 'END{print NR}') unparseable" ERROR
    printf '%s\n' "$out" | sed 's/^/                  ✗ /'
  else
    row frontmatter "$nskills skills, $nagents agents" OK
  fi
}

# Descriptions are always in context for every session — long ones are a standing tax.
# Measured in characters over the FULL scalar: a description continued across several
# lines is the case most likely to be overlong, so a first-line-only count would miss
# exactly what this check is for.
check_descriptions() {
  local plugin="$1" worst
  worst=$(PLUGIN="$plugin" python3 - <<'PY'
import os, glob, re
rows = []
for f in sorted(glob.glob(f"{os.environ['PLUGIN']}/skills/*/SKILL.md")):
    t = open(f).read()
    m = re.match(r'---\n(.*?)\n---\n', t, re.S)
    if not m:
        continue
    fm = m.group(1)
    d = re.search(r'^description:[ \t]*(.*(?:\n(?![A-Za-z][\w-]*:).*)*)', fm, re.M)
    if d:
        rows.append((len(' '.join(d.group(1).split())), os.path.basename(os.path.dirname(f))))
if rows:
    n, name = max(rows)
    print(f"{n}\t{name}")
PY
)
  [ -z "$worst" ] && { row descriptions "none found" WARN; return; }
  local n name
  n=${worst%%$'\t'*}; name=${worst##*$'\t'}
  if [ "$n" -gt 500 ]; then row descriptions "$name $n/500" WARN
  else row descriptions "longest $n/500 ($name)" OK; fi
}

# A relative link that resolves to nothing is a reference the model cannot follow.
# LINK_SKIP holds files whose relative links are TEMPLATE content — written verbatim
# into a generated project, where they resolve against that project's tree, not this
# repo's. Paths are plugin-relative. Placeholder targets (`<URL>`, `{{slug}}`, `…`)
# are filtered everywhere, so only genuinely-template *paths* need listing here.
LINK_SKIP='skills/design/references/architecture-templates.md
skills/design/references/maintenance-playbook.md
skills/dependency-upgrade/references/templates.md
skills/release-prep/references/templates.md'
check_links() {
  local plugin="$1"
  local res
  res=$(PLUGIN="$plugin" SKIP="$LINK_SKIP" python3 - <<'PY'
import os, re, glob
plugin = os.environ['PLUGIN']
skip = {s.strip() for s in os.environ['SKIP'].split('\n') if s.strip()}
bad, total, skipped = [], 0, 0
for f in glob.glob(f'{plugin}/**/*.md', recursive=True):
    rel = os.path.relpath(f, plugin)
    if rel in skip:
        skipped += 1
        continue
    d, t = os.path.dirname(f), open(f).read()
    for m in re.finditer(r'\[[^\]]*\]\(([^)\s]+)\)', t):
        tgt = m.group(1)
        if tgt.startswith(('http://', 'https://', 'mailto:', '#')):
            continue
        # Placeholder targets are illustrative, not navigable.
        if re.search(r'[<>{}]|\.\.\.|…|\$\{', tgt):
            continue
        path = tgt.split('#')[0]
        if not path:
            continue
        total += 1
        if not os.path.exists(os.path.normpath(os.path.join(d, path))):
            bad.append(f"{f}:{t[:m.start()].count(chr(10))+1} -> {tgt}")
print(f"{total}\t{len(bad)}\t{skipped}")
print('\n'.join(bad))
PY
)
  local head rest total nbad nskip
  head=$(printf '%s' "$res" | head -1); rest=$(printf '%s' "$res" | tail -n +2)
  total=$(printf '%s' "$head" | cut -f1); nbad=$(printf '%s' "$head" | cut -f2)
  nskip=$(printf '%s' "$head" | cut -f3)
  local note=""; [ "${nskip:-0}" -gt 0 ] && note=", $nskip template file(s) skipped"
  if [ "${nbad:-0}" -gt 0 ]; then
    row links "$nbad broken of $total$note" ERROR
    printf '%s\n' "$rest" | sed 's/^/                  ✗ /'
  else
    row links "$total refs$note" OK
  fi
}

# The folder name IS the command name; a frontmatter `name:` that disagrees is invisible.
check_names() {
  local plugin="$1" bad=""
  for f in "$plugin"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    local dir fmname
    dir=$(basename "$(dirname "$f")")
    fmname=$(awk 'NR==1&&$0!="---"{exit} NR==1{next} $0=="---"{exit} /^name:/{sub(/^name:[ \t]*/,"");gsub(/["'"'"']/,"");print;exit}' "$f")
    [ "$dir" = "$fmname" ] || bad="$bad$f: folder '$dir' != name '$fmname'"$'\n'
  done
  if [ -n "$bad" ]; then
    row names "mismatched" ERROR
    printf '%s' "$bad" | sed 's/^/                  ✗ /'
  else
    row names "folder == frontmatter name" OK
  fi
}

check_shell() {
  local plugin="$1" n=0 bad=""
  # bin/ wrappers have no .sh extension — include anything there with a sh shebang.
  for f in "$plugin"/scripts/*.sh "$plugin"/bin/*; do
    [ -f "$f" ] || continue
    case "$f" in
      */bin/*) head -1 "$f" 2>/dev/null | grep -q '^#!.*sh' || continue ;;
    esac
    n=$((n+1))
    bash -n "$f" 2>/dev/null || bad="$bad$f"$'\n'
  done
  [ "$n" -eq 0 ] && { row shell "no scripts" OK; return; }
  if [ -n "$bad" ]; then row shell "syntax errors" ERROR
    printf '%s' "$bad" | sed 's/^/                  ✗ /'
  else row shell "$n scripts" OK; fi
}

check_json() {
  local plugin="$1" n=0 bad=""
  for f in "$plugin"/.claude-plugin/*.json "$plugin"/hooks/hooks.json "$plugin"/settings.json; do
    [ -f "$f" ] || continue
    n=$((n+1))
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null \
      || bad="$bad$f"$'\n'
  done
  if [ -n "$bad" ]; then row json "invalid" ERROR
    printf '%s' "$bad" | sed 's/^/                  ✗ /'
  else row json "$n files" OK; fi
}

# ck-code only: session-start.sh hard-codes the layout major that version-gate.md
# defines. When they drift, every correctly-stamped project is nagged to migrate.
check_layout_const() {
  local plugin="$1"
  [ -f "$plugin/scripts/session-start.sh" ] || return 0
  [ -f "$plugin/references/version-gate.md" ] || return 0
  local hook gate doctor
  hook=$(awk -F= '/^LAYOUT=/{print $2; exit}' "$plugin/scripts/session-start.sh")
  gate=$(awk '/^LAYOUT[ \t]*=/{print $NF; exit}' "$plugin/references/version-gate.md")
  # ck-doctor.sh derives its expectation from version-gate.md at runtime, but its
  # offline fallback is a third copy of the constant — keep it in lockstep too.
  doctor=$gate
  [ -f "$plugin/scripts/ck-doctor.sh" ] && \
    doctor=$(awk -F'"' '/^FALLBACK_LAYOUT=/{print $2; exit}' "$plugin/scripts/ck-doctor.sh")
  if [ -n "$hook" ] && [ "$hook" = "$gate" ] && [ "$doctor" = "$gate" ]; then
    row "layout const" "hook=$hook gate=$gate doctor=$doctor" OK
  else
    row "layout const" "hook=${hook:-?} gate=${gate:-?} doctor=${doctor:-?}" ERROR
  fi
}

# A marketplace ref that lags the plugin's own version serves users an old release.
check_marketplace_ref() {
  local plugin="$1" version ref
  version=$(python3 -c "import json;print(json.load(open('$plugin/.claude-plugin/plugin.json'))['version'])" 2>/dev/null)
  ref=$(python3 - "$plugin" <<'PY'
import json, sys
name = sys.argv[1]
try:
    d = json.load(open('ck-code/.claude-plugin/marketplace.json'))
except Exception:
    print('?'); raise SystemExit
for p in d['plugins']:
    if p['name'] == name:
        s = p['source']
        print('local' if isinstance(s, str) else s.get('ref', '?'))
        raise SystemExit
print('absent')
PY
)
  case "$ref" in
    local)  row "marketplace" "v$version, local source" OK ;;
    absent) row "marketplace" "not listed in marketplace.json" WARN ;;
    "v$version") row "marketplace" "ref $ref == v$version" OK ;;
    *)      row "marketplace" "ref $ref != plugin v$version" ERROR ;;
  esac
}

# The official manifest validator. Catches a misspelled or foreign plugin.json field
# that this script has no table for, and that Claude Code would silently ignore at
# load time. --strict promotes those warnings to errors, which is the point of running
# it in a release gate. Skipped (not failed) when the CLI is unavailable.
check_manifest() {
  local plugin="$1" out
  command -v claude >/dev/null 2>&1 || { row "manifest" "claude CLI not on PATH — skipped" WARN; return 0; }
  if out=$(claude plugin validate "./$plugin" --strict 2>&1); then
    row "manifest" "validate --strict clean" OK
  else
    row "manifest" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-100)" ERROR
  fi
}

# Executables in bin/ are added to the Bash tool's PATH. A non-executable file there is
# invisible at runtime with no error, and every skill that calls it as a bare command fails.
check_bin() {
  local plugin="$1" f n=0 bad=0
  [ -d "$plugin/bin" ] || return 0
  for f in "$plugin"/bin/*; do
    [ -e "$f" ] || continue
    n=$((n+1))
    [ -x "$f" ] || { bad=$((bad+1)); row "bin" "$(basename "$f") is not executable (chmod +x)" ERROR; }
  done
  [ "$bad" -eq 0 ] && [ "$n" -gt 0 ] && row "bin" "$n executable(s) on PATH" OK
  return 0
}

# The cross-skill invocation contract (ck-code/references/skill-invocation.md).
# Every check here exists because the defect it catches actually shipped:
#   targets   — a hand-off naming a skill that does not exist is a dead end.
#   reachable — `disable-model-invocation` removes a skill from the Skill tool's
#               registry, so a documented hand-off to it silently never fires.
#               This shipped: `team` was an invocation target AND carried the
#               flag, so build's team gate could never actually run it.
#   allowed   — a write skill without `Skill` in allowed-tools costs the user a
#               second permission prompt on every hand-off.
#   readonly  — a read-only skill runs inside an Explore fork with no Write/Edit,
#               so a Skill() call from one fails at the callee's first file write.
# `allowed`/`readonly` are scoped to ck-code: it is the plugin that adopted the
# contract, and ck-tools / ck-code-lite must not be failed by a rule they never took on.
CONTRACT_PLUGIN='ck-code'
check_skill_interop() {
  local plugin="$1" res
  res=$(PLUGIN="$plugin" CONTRACT="$CONTRACT_PLUGIN" python3 - <<'PY'
import os, re, glob

plugin  = os.environ['PLUGIN']
scoped  = plugin == os.environ['CONTRACT']
root    = os.path.dirname(os.path.abspath(plugin)) or '.'

def frontmatter(path):
    t = open(path).read()
    m = re.match(r'---\n(.*?)\n---\n', t, re.S)
    return (m.group(1) if m else ''), t

skills = {}          # name -> (frontmatter, body)
for f in sorted(glob.glob(f'{plugin}/skills/*/SKILL.md')):
    skills[os.path.basename(os.path.dirname(f))] = frontmatter(f)

# Every Skill({ skill: <quote><plugin>:<name><quote> }) call in this plugin's markdown.
# The quote char is matched with `.` on purpose — a literal quote class here would
# desync bash 3.2's $( ) scanner, which counts quotes even inside a quoted heredoc.
CALL = re.compile(r'Skill\(\{\s*skill\s*:\s*.([\w-]+):([\w-]+).')
targets = set()
for f in glob.glob(f'{plugin}/**/*.md', recursive=True):
    for m in CALL.finditer(open(f).read()):
        targets.add((m.group(1), m.group(2), f))

bad_target, bad_reach, bad_allowed, bad_readonly = [], [], [], []

for tplugin, tname, where in sorted(targets):
    tpath = os.path.join(root, tplugin, 'skills', tname, 'SKILL.md')
    if not os.path.exists(tpath):
        bad_target.append(f'{where} -> {tplugin}:{tname} (no such skill)')
        continue
    tfm, _ = frontmatter(tpath)
    if re.search(r'^disable-model-invocation:\s*true\s*$', tfm, re.M):
        bad_reach.append(f'{tplugin}:{tname} is an invocation target but sets '
                         f'disable-model-invocation (referenced from {where})')

if scoped:
    for name, (fm, body) in sorted(skills.items()):
        dis = re.search(r'^disallowed-tools:.*$', fm, re.M)
        readonly = bool(dis) and 'Write' in dis.group(0)
        al = re.search(r'^allowed-tools:[ \t]*(.*)$', fm, re.M)
        allowed = al.group(1) if al else ''
        has_skill = re.search(r'(^|[\s,])Skill([\s,]|$)', allowed) is not None
        if readonly:
            if CALL.search(body):
                bad_readonly.append(f'{name} is read-only but calls Skill()')
            if has_skill:
                bad_readonly.append(f'{name} is read-only but lists Skill in allowed-tools')
        else:
            if not has_skill:
                bad_allowed.append(f'{name} is a write skill without Skill in allowed-tools')

# Only emit labels that were actually evaluated. Reporting "clean" for a rule a
# plugin was never checked against reads as a pass it never earned.
checks = [('targets', bad_target), ('reachable', bad_reach)]
if scoped:
    checks += [('allowed', bad_allowed), ('readonly', bad_readonly)]
for label, rows in checks:
    print(f'#{label}\t{len(rows)}')
    for r in rows:
        print(r)
PY
)
  local label n block
  for label in targets reachable allowed readonly; do
    n=$(printf '%s\n' "$res" | awk -F'\t' -v L="#$label" '$1==L{print $2}')
    [ -z "$n" ] && continue
    if [ "$n" -gt 0 ]; then
      row "interop" "$label — $n violation(s)" ERROR
      block=$(printf '%s\n' "$res" | awk -v L="#$label" '
        $0 ~ "^"L"\t" {f=1; next} /^#/ {f=0} f')
      printf '%s\n' "$block" | sed 's/^/                  ✗ /'
    else
      row "interop" "$label clean" OK
    fi
  done
}

# ---- run ---------------------------------------------------------------------
echo
for plugin in "${PLUGINS[@]}"; do
  if [ ! -d "$plugin" ]; then
    printf '%-18s %s\n' "$plugin" "MISSING — no such directory"
    ERRORS=$((ERRORS+1)); continue
  fi
  ver=$(python3 -c "import json;print(json.load(open('$plugin/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo '?')
  printf '%-18s %s\n' "$plugin" "$ver"
  check_frontmatter    "$plugin"
  check_descriptions   "$plugin"
  check_names          "$plugin"
  check_links          "$plugin"
  check_shell          "$plugin"
  check_json           "$plugin"
  check_layout_const   "$plugin"
  check_marketplace_ref "$plugin"
  check_bin            "$plugin"
  check_manifest       "$plugin"
  check_skill_interop  "$plugin"
  echo
done

if [ "$ERRORS" -gt 0 ]; then
  echo "$WARNS warning(s), $ERRORS error(s) — fix the errors before releasing."
  exit 1
fi
echo "$WARNS warning(s), 0 errors."
exit 0
