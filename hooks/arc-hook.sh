#!/usr/bin/env bash
# Arc plugin hook dispatcher.
#
#   arc-hook.sh session-start   SessionStart: stdout is injected into context (exit 0).
#   arc-hook.sh stop            Stop: exit 2 with stderr = continuation prompt blocks the
#                               stop and continues the turn. Exit 0 lets the turn end
#                               (stdout/stderr on exit 0 are NOT shown).
#
# POSIX tools only. The claude CLI ships as a standalone binary, so neither `node` nor
# `jq` is guaranteed to exist on the machine. The persist state file is therefore
# line-oriented key=value, never JSON, and is parsed with grep/cut — never sourced,
# because the model writes it.

set -u

MODE="${1:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STALE_SECONDS=21600 # 6h

# --- helpers ---------------------------------------------------------------

# json_str <key> <payload> -- first string value for <key>. Adequate for cwd/session_id,
# which never contain quotes. Deliberately not used for free-text fields.
json_str() {
  printf '%s' "$2" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

state_get() {
  [ -f "$STATE" ] || return 0
  grep -m1 "^$1=" "$STATE" 2>/dev/null | cut -d= -f2-
}

state_set() {
  tmp="$STATE.tmp$$"
  if [ -f "$STATE" ]; then grep -v "^$1=" "$STATE" > "$tmp" 2>/dev/null || :; else : > "$tmp"; fi
  printf '%s=%s\n' "$1" "$2" >> "$tmp"
  mv "$tmp" "$STATE"
}

deactivate() { state_set active 0; }

# --- session-start ---------------------------------------------------------

if [ "$MODE" = "session-start" ]; then
  cat > /dev/null 2>&1 || : # drain stdin
  cat <<'EOF'
[Arc principles — full text at the plugin's CLAUDE.md]
1. Think Before Coding — don't assume, don't hide confusion, surface tradeoffs. Unclear? Stop and ask.
2. Simplicity First — the minimum code that solves the problem. Nothing speculative.
3. Surgical Changes — touch only what you must; every changed line traces to the request.
4. Goal-Driven Execution — define success criteria, then loop until verified. Evidence before assertions.
EOF
  exit 0
fi

# --- stop ------------------------------------------------------------------

if [ "$MODE" != "stop" ]; then
  echo "arc-hook.sh: unknown mode '${MODE}' (expected session-start|stop)" >&2
  exit 1
fi

PAYLOAD="$(cat 2>/dev/null || printf '')"

CWD="$(json_str cwd "$PAYLOAD")"
[ -n "$CWD" ] || CWD="$PWD"
SESSION="$(json_str session_id "$PAYLOAD")"

STATE="$CWD/.arc/state/persist.state"
[ -f "$STATE" ] || exit 0

[ "$(state_get active)" = "1" ] || exit 0

# Project scoping: a state file must not hijack a different checkout.
SPROJECT="$(state_get project)"
[ -z "$SPROJECT" ] || [ "$SPROJECT" = "$CWD" ] || exit 0

# Session scoping: another Claude Code session's loop is not ours to continue.
SSESSION="$(state_get session)"
[ -z "$SSESSION" ] || [ -z "$SESSION" ] || [ "$SSESSION" = "$SESSION" ] || exit 0

# Staleness: an abandoned state file must not resurrect itself days later.
UPDATED="$(state_get updated_at)"
NOW="$(date +%s)"
case "$UPDATED" in
  ''|*[!0-9]*) : ;;
  *) [ "$((NOW - UPDATED))" -lt "$STALE_SECONDS" ] || { deactivate; exit 0; } ;;
esac

# Iteration cap.
ITER="$(state_get iteration)";     case "$ITER" in ''|*[!0-9]*) ITER=0 ;; esac
MAXI="$(state_get max_iterations)"; case "$MAXI" in ''|*[!0-9]*) MAXI=25 ;; esac
if [ "$ITER" -ge "$MAXI" ]; then
  deactivate
  exit 0
fi

# Progress guard. Claude Code overrides a Stop hook after CLAUDE_CODE_STOP_HOOK_BLOCK_CAP
# (default 8) *consecutive* blocks, and resets that counter whenever the model does real
# work. So the thing to detect is an unproductive block: if the assistant's last message is
# byte-identical to the previous iteration's, nothing happened — let the turn end cleanly
# rather than burning through the platform cap. stop_hook_active is deliberately NOT used
# as a blanket bail (that would limit the loop to a single block per user prompt); it flips
# once and stays set, so it is excluded from the hash below.
# NOTE: [a-z]* rather than \(true\|false\) -- BSD sed has no BRE alternation, and a silent
# non-match here would disable the guard entirely.
HASH="$(printf '%s' "$PAYLOAD" \
  | sed 's/"stop_hook_active"[[:space:]]*:[[:space:]]*[a-z]*//g' \
  | cksum | cut -d' ' -f1)"
if [ "$HASH" = "$(state_get msg_hash)" ]; then
  deactivate
  exit 0
fi

ITER=$((ITER + 1))
state_set iteration "$ITER"
state_set msg_hash "$HASH"
state_set updated_at "$NOW"

GOAL="$(state_get goal)"

cat >&2 <<EOF
[ARC PERSIST — ITERATION ${ITER}/${MAXI}]

You did not report completion, so the task is still open. Keep working.

Goal: ${GOAL:-(see .arc/prd.json)}

- Read .arc/prd.json and pick the highest-priority story with "passes": false.
- Verify each acceptance criterion with fresh command output before marking it passed.
- Record what you did and what you learned in .arc/progress.md.
- When every story passes and a reviewer has verified them, run \`/arc:persist --stop\`.

To stop now: run \`/arc:persist --stop\`, or delete .arc/state/persist.state.
EOF
exit 2
