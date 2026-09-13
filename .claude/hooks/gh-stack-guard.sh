#!/bin/sh
# Block hand-rolled PR stacks.
#
# `gh pr create --base <feature-branch>` layers the diffs correctly but creates no stack: there is no
# stack metadata, so `gh stack sync` / `submit` / `merge` do not know the PRs are related and cannot
# restack them when a lower layer takes review feedback. The convention (global CLAUDE.md + the
# {{org}}-pr skill) is `gh stack init` -> `gh stack add` -> `gh stack submit --auto`.
#
# This exists because the prose rule was in context and got ignored anyway. Reads the PreToolUse
# payload on stdin; denies with guidance rather than failing silently.
#
# Escape hatch: prefix the command with STACK_EXEMPT=1 when a PR genuinely targets a long-lived
# non-default branch (a release branch, or contributing to someone else's feature branch).

set -eu

command=$(cat | jq -r '.tool_input.command // ""' 2>/dev/null || printf '')

# Fast path: this runs on every Bash call, so bail before doing any real work.
case "$command" in
*"gh pr create"* | *"gh pr edit"*) ;;
*) exit 0 ;;
esac

# The command must actually invoke gh, not merely mention it: a commit message or doc that quotes
# `gh pr create --base ...` is not a hand-rolled stack. Requires `gh` at a command position — start
# of string or after a `;`, `|`, `&&`, `(` — allowing leading VAR=value assignments.
INVOCATION='(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]]|$)'
printf '%s' "$command" | grep -Eq "$INVOCATION" || exit 0

case "$command" in
*STACK_EXEMPT=1*) exit 0 ;;
esac

# Match `--base x`, `--base=x`, and `-B x`.
base=$(printf '%s' "$command" | sed -n 's/.*--base[ =]\{1,\}\([^ ]\{1,\}\).*/\1/p' | head -1)
if [ -z "$base" ]; then
	base=$(printf '%s' "$command" | sed -n 's/.*[ ]-B[ =]\{1,\}\([^ ]\{1,\}\).*/\1/p' | head -1)
fi
[ -n "$base" ] || exit 0

base=$(printf '%s' "$base" | tr -d "\"'")
case "$base" in
main | master | develop | origin/main | origin/master | "\$DEFAULT_BRANCH") exit 0 ;;
esac

reason=$(
	cat <<TEXT
Blocked: --base '$base' is not the default branch, which means this is a stack built by hand.

That layers the diffs but creates no stack on GitHub, so gh stack sync / submit / merge cannot manage
the PRs and restacking after review feedback becomes manual. Use the stack tooling instead:

  gh stack init <bottom-branch> <top-branch>   # adopts branches that already exist
  gh stack add <branch>                        # for each further layer
  gh stack submit --auto                       # pushes and creates/links the PRs

If the branches already have open PRs, gh stack init adopts them and gh stack submit links them into
a stack without creating duplicates. See the {{org}}-pr skill for the full flow, including why
gh stack sync owns restacking.

If this PR genuinely targets a long-lived branch and is not a stack, re-run with STACK_EXEMPT=1 as a
command prefix.
TEXT
)

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
