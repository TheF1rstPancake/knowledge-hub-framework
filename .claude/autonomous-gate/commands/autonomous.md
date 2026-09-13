---
description: Arm autonomous build mode for THIS session — keep working until built + written up, self-serve decisions, escalate only if genuinely concerned
allowed-tools: Bash(mkdir:*), Bash(touch:*), Bash(rm:*), Bash(printf:*), Bash(date:*), Bash(tr:*), Bash(echo:*)
---

Arm autonomous build mode for this session, then carry out the task.

First, create the session marker the Stop-hook gate reads (key resolution MUST match `autonomous-gate.sh`: prefer `ORCA_PANE_KEY`, else `CLAUDE_CODE_SESSION_ID`, sanitized):

```bash
STATE_DIR="${AUTONOMOUS_GATE_STATE_DIR:-$HOME/.claude/autonomous}"
raw="${ORCA_PANE_KEY:-$CLAUDE_CODE_SESSION_ID}"
key=$(printf '%s' "$raw" | tr -c 'a-zA-Z0-9' '_')
mkdir -p "$STATE_DIR"
# fresh arm: clear any stale terminal/counter markers from a prior run on this key
rm -f "$STATE_DIR/$key.done" "$STATE_DIR/$key.escalate" "$STATE_DIR/$key.blocks"
printf 'armed %s\n' "$(date -u +%FT%TZ)" > "$STATE_DIR/$key.armed"
echo "autonomous mode ARMED (key=$key, state=$STATE_DIR)"
```

Now you are in autonomous build mode. Operating agreement for the rest of this session:

- **Build the thing.** Keep working through the task without pausing to ask for confirmation. The gate will block "looks done" stops and tell you to continue.
- **Self-serve product questions.** If you hit a product question or design consideration, research it (web, codebase, findings) and decide it yourself. Do not bounce it back to the human.
- **Release cleanly by writing it up.** When the work is built, write a finding with the `{{org}}-finding` skill describing what you did and what you learned. Writing the finding marks this session done and releases the gate, which lets the session stop and notifies the human via Orca.
- **Escalate only if genuinely concerned.** If — and only if — you are genuinely concerned about a decision the human must make, write your concern (the question + the options + your recommendation) to `$STATE_DIR/$key.escalate`, then stop. That releases the gate and notifies them. Use this sparingly; it is the one exception to "don't ask."
- **Disarm** with `/stand-down` to return to normal stop-when-done behavior at any time.

The task:

$ARGUMENTS
