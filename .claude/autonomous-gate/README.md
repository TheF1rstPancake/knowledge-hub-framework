# autonomous-gate

A `Stop`-hook gate that lets an **armed** Claude session keep working instead of
handing control back to the human on "looks done". Built to enforce {{OWNER}}'s
autonomy contract: *build the thing and write up what you learned; self-serve
product questions; only interrupt the human (with a notification) if genuinely
concerned about a decision.*

## Why this exists

Sessions stall not on permission prompts (we run `--dangerously-skip-permissions`)
but because the model voluntarily ends its turn — "looks done" is the only stop
signal it has, so the human becomes the verification loop. This replaces the
human gate with a machine-readable one: the session keeps going until the work
is **built and written up as a finding**, or the agent **escalates** a genuine
decision.

## Pieces

- `autonomous-gate.sh` — the Stop hook. Registered as a *second* `Stop` hook in
  `~/.claude/settings.json`, alongside the Orca dispatcher (both run; if this one
  returns `decision:block`, the stop is held).
- `commands/autonomous.md` → `/autonomous <task>` — arms the session (writes a
  marker) and states the operating agreement, then runs the task.
- `commands/stand-down.md` → `/stand-down` — disarms; returns to normal
  stop-when-done.
- The `{{org}}-finding` skill, on an armed session, touches the `.done` marker
  after writing a finding — that's what releases the gate cleanly.

## How it works

Marker files in `~/.claude/autonomous/` (override with `$AUTONOMOUS_GATE_STATE_DIR`),
keyed by `${ORCA_PANE_KEY:-$CLAUDE_CODE_SESSION_ID}` sanitized — the hook (reading
`session_id` from stdin / `ORCA_PANE_KEY` from env) and the commands (reading env)
compute the same key.

| Marker        | Meaning                          | Gate behavior                          |
|---------------|----------------------------------|----------------------------------------|
| *(none)*      | session not armed                | **no-op** — stop propagates as today   |
| `<key>.armed` | autonomous mode on               | block "looks done" stops               |
| `<key>.done`  | finding written (work done)      | release → stop → Orca notifies         |
| `<key>.escalate` | agent raised a real decision  | release → stop → Orca notifies         |
| `<key>.blocks`| consecutive-block counter        | runaway backstop (cap default 40)      |

Fails **open**: any unexpected state → `exit 0` (let the session stop). The gate
can never wedge a session shut.

## Notification

There is no separate notification code. While gated, the agent keeps working, so
nothing pings. When the gate **releases** (done or escalate), the Stop propagates
to the Orca dispatcher, and Orca's existing pane-idle notification is the "come
look" signal. (If desktop pings aren't firing, that's an Orca setting, not this.)

## Fully removing it

Disarm (`/stand-down`) reverts a single session. To remove the gate entirely:

```bash
# 1. drop the Stop hook entry (restore the backup made at install)
cp ~/.claude/settings.json.pre-autonomous-gate.bak ~/.claude/settings.json
# 2. remove the slash commands
rm ~/.claude/commands/autonomous.md ~/.claude/commands/stand-down.md
# 3. (optional) clear any marker state
rm -rf ~/.claude/autonomous
```

The hook is no-op unless armed, so leaving it installed has no effect on normal
sessions.

## Known wrinkle

The Orca `Stop` dispatcher forwards *every* turn-end event, including ones this
gate then blocks. Whether that produces premature "idle" notifications depends on
Orca's own logic (it likely tracks PTY activity, not just the hook event). Observe
in practice; if noisy, the fix is on the Orca side.
