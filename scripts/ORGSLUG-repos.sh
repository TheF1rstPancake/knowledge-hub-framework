#!/usr/bin/env bash
#
# {{org}}-repos.sh — find (or clone) the {{ORG}} sibling repos and report where
# they are, so nothing has to hardcode a checkout path.
#
# Identity is the git remote, never the directory name or location. A directory
# called `backend` that isn't ours is rejected; one called `{{org}}-be` in
# ~/code is accepted. That means people can lay their machine out however they
# like — ~/dev, ~/code, ~/work — and everything still resolves.
#
#   backend            -> ${{ORG_UPPER}}_BACKEND
#   {{APP_REPO}}    -> ${{ORG_UPPER}}_APP
#   infrastructure     -> ${{ORG_UPPER}}_INFRA
#   {{HANDBOOK_REPO}}         -> ${{ORG_UPPER}}_OS
#
# The first three are product repos: we write code in them, so this script never
# touches their working tree. `{{HANDBOOK_REPO}}` is the company operating model — the
# hub consumes it read-only and contributes upstream by PR, never by editing a
# local checkout — which is why it is the one repo `--refresh` will fast-forward.
# Its playbooks are only useful if they are current (its own first invariant is
# "true today"), so a stale clone is a correctness problem, not an inconvenience.
#
# Usage:
#   scripts/{{org}}-repos.sh              report what resolved, KEY=PATH lines
#   scripts/{{org}}-repos.sh --clone      clone whatever is missing, beside the hub
#   scripts/{{org}}-repos.sh --refresh    fast-forward the read-only repos ({{HANDBOOK_REPO}})
#   scripts/{{org}}-repos.sh --path KEY   print one path (exit 1 if unresolved)
#
# bootstrap-claude.sh calls this and pins the results into ~/.claude/settings.json,
# so resolution happens once at install rather than on every skill invocation.
# Cloned a repo later? Re-run bootstrap-claude.sh.

set -euo pipefail

HUB_DIR="${{{HUB_ENV_VAR}}:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PARENT="$(dirname "$HUB_DIR")"          # where the hub lives = where siblings go
ORG="{{org}}-ai"

# key|repo-name|refresh  (refresh=yes means the hub only ever reads it — safe to
# fast-forward on request; product repos are ours to edit, so they stay untouched)
REPOS=(
  "{{ORG_UPPER}}_BACKEND|backend|no"
  "{{ORG_UPPER}}_APP|{{APP_REPO}}|no"
  "{{ORG_UPPER}}_INFRA|infrastructure|no"
  "{{ORG_UPPER}}_OS|{{HANDBOOK_REPO}}|yes"
)

MODE="report"; WANT_KEY=""; REFRESH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --clone) MODE="clone" ;;
    --refresh) REFRESH=1 ;;
    --path)  MODE="path"; WANT_KEY="${2:?--path needs a KEY}"; shift ;;
    -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,"");print;next} {exit}' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

say() { [ "$MODE" = "path" ] || printf '%s\n' "$*"; }

# Is $1 a checkout of $ORG/$2? The remote is the only thing we trust.
is_repo() {
  [ -d "$1/.git" ] || return 1
  git -C "$1" remote get-url origin 2>/dev/null \
    | grep -qE "[:/]${ORG}/$(printf '%s' "$2" | sed 's/\./\\./g')(\.git)?/?$"
}

# Print the resolved path for repo $2, or nothing.
locate() {
  local key="$1" name="$2" cand
  # 1. an explicit override already in the environment
  cand="${!key:-}"
  if [ -n "$cand" ] && is_repo "$cand" "$name"; then printf '%s' "$cand"; return; fi
  # 2. beside the hub — the documented layout, and works under any parent dir
  if is_repo "$PARENT/$name" "$name"; then printf '%s' "$PARENT/$name"; return; fi
  # 3. the usual places people keep code
  for p in "$HOME/dev" "$HOME/code" "$HOME/src" "$HOME/work" "$HOME/projects" \
           "$HOME/repos" "$HOME/git" "$HOME/Developer" "$HOME/scratch" "$HOME"; do
    if is_repo "$p/$name" "$name"; then printf '%s' "$p/$name"; return; fi
  done
  # 4. last resort: a bounded sweep. Depth-limited and pruned so it stays quick.
  while IFS= read -r g; do
    cand="$(dirname "$g")"
    if is_repo "$cand" "$name"; then printf '%s' "$cand"; return; fi
  done < <(find "$HOME" -maxdepth 4 -type d -name .git \
             -not -path '*/node_modules/*' -not -path '*/Library/*' \
             -not -path '*/.Trash/*' -not -path '*/.cache/*' 2>/dev/null || true)
}

# Fast-forward $1 to its remote default branch, but only when that is provably
# safe: a clean tree, sitting on that branch, and a real fast-forward. Anything
# else (dirty, detached, on a feature branch, diverged) is reported and skipped —
# we would rather run a stale playbook knowingly than eat someone's work.
fast_forward() {
  local dir="$1" nm="$2" branch cur
  branch="$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
  [ -n "$branch" ] || branch="$(git -C "$dir" remote show origin 2>/dev/null | awk '/HEAD branch/{print $NF}')"
  [ -n "$branch" ] || { say "  SKIP $nm — cannot determine its default branch"; return; }

  cur="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  if [ "$cur" != "$branch" ]; then
    say "  SKIP $nm — on '$cur', not '$branch'"; return
  fi
  if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
    say "  SKIP $nm — working tree is dirty"; return
  fi
  if ! git -C "$dir" fetch --quiet origin "$branch" 2>/dev/null; then
    say "  SKIP $nm — fetch failed"; return
  fi
  if ! git -C "$dir" merge --ff-only --quiet "origin/$branch" 2>/dev/null; then
    say "  SKIP $nm — $branch has diverged from origin; resolve it by hand"; return
  fi
  say "  refreshed $nm -> $(git -C "$dir" rev-parse --short HEAD) ($branch)"
}

resolved=(); missing=()
for entry in "${REPOS[@]}"; do
  IFS='|' read -r key name refreshable <<<"$entry"
  path="$(locate "$key" "$name" || true)"

  if [ -z "$path" ] && [ "$MODE" = "clone" ]; then
    target="$PARENT/$name"
    if [ -e "$target" ]; then
      say "  SKIP $name — $target exists but is not an $ORG/$name checkout"
    else
      say "  cloning $name -> $target"
      if git clone --quiet "git@github.com:${ORG}/${name}.git" "$target"; then
        path="$target"
      else
        say "  FAILED to clone $name (SSH access to $ORG/$name?)"
      fi
    fi
  fi

  if [ -n "$path" ] && [ "$REFRESH" = 1 ] && [ "$refreshable" = yes ] && [ "$MODE" != path ]; then
    fast_forward "$path" "$name"
  fi

  if [ -n "$path" ]; then resolved+=("$key=$path"); else missing+=("$key|$name"); fi
done

if [ "$MODE" = "path" ]; then
  # Guard the expansion: bash 3.2 (macOS system bash) treats "${arr[@]}" on an
  # empty array as unbound under `set -u`. Zero resolved repos is the normal
  # state on a fresh machine, not an error.
  if [ ${#resolved[@]} -gt 0 ]; then
    for r in "${resolved[@]}"; do
      [ "${r%%=*}" = "$WANT_KEY" ] && { printf '%s\n' "${r#*=}"; exit 0; }
    done
  fi
  echo "{{org}}-repos: could not resolve $WANT_KEY. Clone it, or export $WANT_KEY=/path" >&2
  exit 1
fi

if [ ${#resolved[@]} -gt 0 ]; then
  for r in "${resolved[@]}"; do printf '%s\n' "$r"; done
fi

if [ ${#missing[@]} -gt 0 ]; then
  say ""
  say "Not found:"
  for m in "${missing[@]}"; do
    say "  ${m%%|*}  (${ORG}/${m##*|})"
  done
  say ""
  say "Get them with:  $(basename "${BASH_SOURCE[0]}") --clone"
  say "Or point at an existing checkout:  export ${missing[0]%%|*}=/path/to/repo"
fi
