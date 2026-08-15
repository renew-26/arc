#!/usr/bin/env bash
# Arc release gate. Run from the repository root: ./scripts/validate.sh
#
# Every check prints the evidence it acted on. A green run here is a claim that
# the plugin's manifests parse, its skills register, its hook actually loops,
# and its attribution is complete -- not that anyone eyeballed it.

set -u
cd "$(dirname "$0")/.." || exit 1

FAIL=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }
head2() { printf '\n\033[1m%s\033[0m\n' "$1"; }

SKILLS="require ideate plan launch persist squad trace scan"

# --- 1. manifests ----------------------------------------------------------
# Both invocations are needed. With marketplace.json present, `validate .` takes the
# marketplace path and never reaches plugin.json; pointing at plugin.json directly is
# what checks the plugin manifest. Neither validates hooks/hooks.json -- section 6 does.
#
# One --strict warning is expected and accepted: the validator notes that a plugin-root
# CLAUDE.md is not loaded as project context. That is true, and is exactly why Arc ships
# a SessionStart hook to inject the principles (section 6 proves it emits them). The file
# stays because the specification calls for it. Any OTHER warning still fails the gate.
head2 "1. Manifests"
KNOWN_WARN='CLAUDE.md at the plugin root is not loaded as project context'
for target in "." ".claude-plugin/plugin.json"; do
  if out="$(claude plugin validate "$target" --strict 2>&1)"; then
    pass "claude plugin validate $target --strict"
  elif printf '%s' "$out" | grep -q 'Found 1 warning' \
    && printf '%s' "$out" | grep -q "$KNOWN_WARN"; then
    pass "claude plugin validate $target --strict (1 known, accepted warning: root CLAUDE.md)"
  else
    fail "claude plugin validate $target --strict"; printf '%s\n' "$out"
  fi
done

# --- 2. manifest field agreement -------------------------------------------
head2 "2. Manifest fields"
python3 - <<'PY' || FAIL=1
import json, sys
p = json.load(open(".claude-plugin/plugin.json"))
m = json.load(open(".claude-plugin/marketplace.json"))
ok = True
def chk(cond, msg):
    global ok
    print(("  \033[32mPASS\033[0m  " if cond else "  \033[31mFAIL\033[0m  ") + msg)
    ok = ok and cond
chk(p["name"] == "arc", 'plugin.json name == "arc" (got %r)' % p["name"])
chk(m["name"] == "arc", 'marketplace.json name == "arc" (got %r)' % m["name"])
chk(isinstance(m.get("owner"), dict), "marketplace.json has owner object (required)")
entry = m["plugins"][0]
chk(entry["source"] == "./", 'plugins[0].source == "./" (got %r)' % entry["source"])
chk(entry.get("version") == p["version"],
    "versions agree: plugin.json %s == marketplace entry %s" % (p["version"], entry.get("version")))
sys.exit(0 if ok else 1)
PY

# --- 3. skills register ----------------------------------------------------
head2 "3. Skills"
for s in $SKILLS; do
  f="skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then fail "$f missing"; continue; fi
  name="$(sed -n '2,12s/^name:[[:space:]]*//p' "$f" | head -1)"
  desc="$(sed -n '2,12s/^description:[[:space:]]*//p' "$f" | head -1)"
  [ "$name" = "$s" ] || { fail "$f frontmatter name '$name' != directory '$s'"; continue; }
  printf '%s' "$name" | grep -Eq '^[a-z0-9-]+$' || { fail "$f name '$name' not [a-z0-9-]"; continue; }
  [ -n "$desc" ] || { fail "$f has no description"; continue; }
  dlen=${#desc}
  [ "$dlen" -le 200 ] || { fail "$f description is $dlen chars (max 200, loads every session)"; continue; }
  pass "$f  name=$name  description=${dlen}c"
done

# --- 4. no laundered upstream dependencies ---------------------------------
# Scoped to upstream INTERNALS. Native Claude Code tools (TeamCreate, SendMessage,
# TaskUpdate) are legitimate in squad; the Understand-Anything data-dir names are
# legitimate in scan, which interoperates with that plugin by design.
head2 "4. Forbidden upstream references"
PAT='oh-my-claudecode|\.omc/|superpowers:|state_write|state_read|state_clear|omc\.jsonc|boulder never stops|progress\.txt|Skill\("(oh-my-claudecode|superpowers|understand-anything):'
if hits="$(grep -rEn "$PAT" skills/ CLAUDE.md hooks/ 2>/dev/null)"; then
  fail "upstream-internal references found:"; printf '%s\n' "$hits"
else
  pass "no upstream-internal references in skills/, CLAUDE.md, hooks/"
fi

# --- 5. declared gates -----------------------------------------------------
head2 "5. Declared harness dependencies"
for s in persist squad; do
  if grep -q '^## Requirements' "skills/$s/SKILL.md" 2>/dev/null; then
    pass "skills/$s/SKILL.md declares its gate in ## Requirements"
  else
    fail "skills/$s/SKILL.md has no ## Requirements section (it depends on a hook / env flag)"
  fi
done

# --- 6. hooks --------------------------------------------------------------
head2 "6. Hooks"
bash -n hooks/arc-hook.sh 2>/dev/null && pass "arc-hook.sh syntax" || fail "arc-hook.sh syntax"
python3 -c 'import json;json.load(open("hooks/hooks.json"))' 2>/dev/null \
  && pass "hooks.json parses" || fail "hooks.json parses"
[ -x hooks/arc-hook.sh ] && pass "arc-hook.sh is executable" || fail "arc-hook.sh not executable"

n=$(printf '{}' | ./hooks/arc-hook.sh session-start 2>/dev/null | grep -c '^[0-9]\.')
[ "$n" -ge 4 ] && pass "session-start emits $n principles" || fail "session-start emitted $n principles (want >=4)"

T="$(mktemp -d)"; mkdir -p "$T/.arc/state"
mk() { printf 'active=1\nproject=%s\nsession=s1\niteration=%s\nmax_iterations=%s\n' "$T" "$1" "$2" > "$T/.arc/state/persist.state"; }
ev() { printf '{"session_id":"s1","cwd":"%s","stop_hook_active":%s,"last_assistant_message":"%s"}' "$T" "$2" "$1"; }
run() { ev "$1" "${2:-false}" | ./hooks/arc-hook.sh stop >/dev/null 2>&1; echo $?; }

rm -f "$T/.arc/state/persist.state"
[ "$(run alpha)" = "0" ] && pass "stop: no state file -> exit 0 (silent)" || fail "stop: no state file"
mk 0 9
[ "$(run alpha)" = "2" ] && pass "stop: active + new message -> exit 2 (blocks)" || fail "stop: should block"
[ "$(run alpha true)" = "0" ] && pass "stop: repeated message -> exit 0 (no-progress guard)" || fail "stop: no-progress guard"
mk 9 9
[ "$(run beta)" = "0" ] && pass "stop: iteration cap -> exit 0" || fail "stop: iteration cap"
mk 0 9; sed -i.bak 's/^session=s1/session=OTHER/' "$T/.arc/state/persist.state"
[ "$(run gamma)" = "0" ] && pass "stop: foreign session -> exit 0" || fail "stop: session scoping"
mk 0 9; printf 'updated_at=%s\n' "$(( $(date +%s) - 25200 ))" >> "$T/.arc/state/persist.state"
[ "$(run delta)" = "0" ] && pass "stop: stale state (>6h) -> exit 0" || fail "stop: staleness guard"
rm -rf "$T"

# --- 7. README -------------------------------------------------------------
head2 "7. README"
for s in $SKILLS; do
  grep -q "/arc:$s" README.md 2>/dev/null || fail "README missing /arc:$s"
done
grep -q "$(printf '/arc:scan')" README.md 2>/dev/null && pass "all 8 skills referenced" || true
grep -q '^## Quickstart' README.md 2>/dev/null \
  && pass "## Quickstart present" || fail "## Quickstart missing (non-developer entry point)"
grep -q 'claude plugin marketplace add' README.md 2>/dev/null \
  && pass "marketplace add documented" || fail "marketplace add missing"
grep -q 'claude plugin install arc@arc' README.md 2>/dev/null \
  && pass "install command documented" || fail "install command missing"
if grep -q 'plugin install http' README.md 2>/dev/null; then
  fail "README documents 'claude plugin install <url>' -- that form does not exist"
else
  pass "no bogus git-URL install form"
fi
ex=$(awk '/^## Examples/{f=1;next} /^## /{f=0} f&&/^```/{c++} END{print c+0}' README.md 2>/dev/null)
[ "$((ex / 2))" -ge 3 ] && pass "$((ex / 2)) worked examples under ## Examples" \
  || fail "only $((ex / 2)) examples under ## Examples (want >=3)"

# --- 8. attribution --------------------------------------------------------
head2 "8. NOTICE"
n=$(grep -c 'Permission is hereby granted' NOTICE 2>/dev/null)
[ "$n" -eq 3 ] && pass "full MIT text reproduced 3x" || fail "MIT text appears $n times (want 3)"
for c in "Yeachan Heo" "Jesse Vincent" "Yuxiang Lin" "Infinite Universe, Inc."; do
  grep -q "Copyright (c) .*$c" NOTICE 2>/dev/null && pass "copyright: $c" || fail "copyright missing: $c"
done
for sha in 3e945671dcf3ed1c1bcc422862815f92c1999143 \
           b36e0829c6d0140e93cfef2ca599b1b07d4a7797 \
           32944829e7a63a9fa9c55d811d7f98a9530c6a6a; do
  grep -q "$sha" NOTICE 2>/dev/null && pass "source commit ${sha:0:7}" || fail "missing commit $sha"
done

printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mAll checks passed.\033[0m\n'
  printf 'Not covered here (run manually): claude plugin details arc -> Skills (8) + Hooks (2);\n'
  printf 'behavioral tests for scan/trace/persist; git ls-remote origin main.\n'
else
  printf '\033[31mFAILED.\033[0m\n'
fi
exit "$FAIL"
