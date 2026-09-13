#!/bin/sh
# autonomous-gate.sh — a Stop hook that keeps an ARMED Claude session working
# instead of handing control back to the human on "looks done".
#
# Contract ({{OWNER}}'s autonomy agreement): build the thing and write up what
# you learned; self-serve product questions; only interrupt the human, with a
# notification, if genuinely concerned about a decision.
#
# Behavior:
#   - UNARMED session  -> exit 0 immediately. Zero behavior change vs. today;
#     the Stop propagates to Orca and you get pinged exactly as before.
#   - ARMED + not done -> block the Stop and inject a "keep going" reason, so
#     the agent continues rather than waiting on the human.
#   - ARMED + done OR escalation written -> allow the Stop. Orca's existing
#     Stop->notification then fires naturally; that IS the "come look" ping.
#   - A consecutive-block cap is a runaway backstop (Claude also self-overrides
#     a Stop hook that blocks with no progress).
#
# Marker files live in $STATE_DIR, keyed so the hook (this script) and the
# arming command compute the SAME key. Both run as children of the same
# Orca-launched claude process, so ORCA_PANE_KEY is shared and stable; we fall
# back to the session id outside Orca. Keys are sanitized to a safe filename.
#
# Fails OPEN: any unexpected condition -> exit 0 (let the session stop). The
# gate must never be able to wedge a session shut.

set -u

STATE_DIR="${AUTONOMOUS_GATE_STATE_DIR:-$HOME/.claude/autonomous}"
BLOCK_CAP="${AUTONOMOUS_GATE_BLOCK_CAP:-40}"

payload=$(cat 2>/dev/null) || exit 0

# Need jq to parse/emit JSON safely; without it, fail open.
command -v jq >/dev/null 2>&1 || exit 0

sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)

# Resolve the marker key identically to the arm command:
#   prefer ORCA_PANE_KEY (guaranteed-shared under Orca), else the session id.
raw="${ORCA_PANE_KEY:-$sid}"
[ -n "$raw" ] || exit 0
key=$(printf '%s' "$raw" | tr -c 'a-zA-Z0-9' '_')

armed="$STATE_DIR/$key.armed"
done_f="$STATE_DIR/$key.done"
esc="$STATE_DIR/$key.escalate"
blocks="$STATE_DIR/$key.blocks"

# Not armed -> default behavior.
[ -f "$armed" ] || exit 0

# Terminal states -> allow the stop (and let Orca notify). Clean up counters.
if [ -f "$done_f" ] || [ -f "$esc" ]; then
  rm -f "$blocks"
  exit 0
fi

# Runaway backstop: count consecutive blocks; release if we exceed the cap.
n=0
[ -f "$blocks" ] && n=$(cat "$blocks" 2>/dev/null || echo 0)
case "$n" in (*[!0-9]*) n=0 ;; esac
n=$((n + 1))
if [ "$n" -ge "$BLOCK_CAP" ]; then
  rm -f "$blocks"
  printf '{"systemMessage":"autonomous-gate: hit block cap (%s) without a finding/escalation; releasing the session to stop"}\n' "$BLOCK_CAP"
  exit 0
fi
printf '%s' "$n" > "$blocks" 2>/dev/null || true

reason="You are in AUTONOMOUS BUILD MODE and the task is not finished. Do NOT hand control back to the human. Keep working. If you have product questions or considerations, research and decide them yourself — do not ask. The gate releases automatically once you have (a) built the thing AND (b) written up what you learned as a finding via the {{org}}-finding skill (which marks this session done). ONLY stop early if you are genuinely concerned about a decision the human must make — in that case, write your concern to ${esc} and then stop; that notifies them. To leave autonomous mode entirely, run /stand-down."

jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
