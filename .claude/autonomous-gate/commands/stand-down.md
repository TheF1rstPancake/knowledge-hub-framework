---
description: Disarm autonomous build mode for THIS session — return to normal stop-when-done behavior
allowed-tools: Bash(rm:*), Bash(printf:*), Bash(tr:*), Bash(echo:*)
---

Disarm autonomous build mode for this session. Remove the session markers (same key resolution as `autonomous-gate.sh`):

```bash
STATE_DIR="${AUTONOMOUS_GATE_STATE_DIR:-$HOME/.claude/autonomous}"
raw="${ORCA_PANE_KEY:-$CLAUDE_CODE_SESSION_ID}"
key=$(printf '%s' "$raw" | tr -c 'a-zA-Z0-9' '_')
rm -f "$STATE_DIR/$key.armed" "$STATE_DIR/$key.done" "$STATE_DIR/$key.escalate" "$STATE_DIR/$key.blocks"
echo "autonomous mode DISARMED (key=$key) — back to normal stop-when-done"
```

After this, the Stop-hook gate is a no-op for this session: it will let the session stop normally and you can hand control back to the human as usual.
