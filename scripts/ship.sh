#!/usr/bin/env bash
# Ship the current umbrella branch: push, open PR, enable auto-merge.
#
# Handles the race where `gh pr merge --auto` fires before GitHub has
# computed the PR's mergeability. Retries the auto-merge enable until
# it sticks (usually 1–2 tries, ~3s).
#
# Usage:
#   scripts/ship.sh                  # uses commit message for PR title/body
#   scripts/ship.sh "PR title"       # explicit title, body from commits
set -euo pipefail

BRANCH=$(git branch --show-current)
if [[ "$BRANCH" == "main" ]]; then
  echo "refusing to ship from main — create a feature branch first" >&2
  exit 1
fi

# Push (set upstream if not tracked)
if ! git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  git push -u origin "$BRANCH"
else
  git push
fi

# Create the PR (idempotent: if one exists for this branch, gh exits non-zero and we continue)
if [[ $# -gt 0 ]]; then
  gh pr create --title "$1" --fill || true
else
  gh pr create --fill || true
fi

PR=$(gh pr view --json number -q .number)
echo "PR #$PR"

# Enable auto-merge with retry — GitHub sometimes needs a beat to
# compute mergeability after the PR is created.
for attempt in 1 2 3 4 5; do
  if gh pr merge "$PR" --auto --squash 2>/dev/null; then
    echo "auto-merge enabled"
    break
  fi
  sleep 2
  if [[ $attempt -eq 5 ]]; then
    echo "failed to enable auto-merge after 5 attempts; enable manually on $PR" >&2
    exit 1
  fi
done

# Wait for merge (max ~30s). If it doesn't land, the PR has conflicts
# or failing checks — leave it open for the user to inspect.
for attempt in $(seq 1 15); do
  state=$(gh pr view "$PR" --json state -q .state)
  if [[ "$state" == "MERGED" ]]; then
    echo "merged #$PR"
    # Sync local main so next branch is up to date
    git checkout main --quiet
    git pull --quiet
    exit 0
  fi
  sleep 2
done

echo "PR #$PR did not merge within 30s — check https://github.com/{{GITHUB_ORG}}/{{HUB_NAME}}/pull/$PR" >&2
exit 0
