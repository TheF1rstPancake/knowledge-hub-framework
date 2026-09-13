#!/usr/bin/env bash
#
# instantiate.sh — turn this starter kit into a real hub for one organization.
#
# Substitutes every {{PLACEHOLDER}} you supply, renames the ORGSLUG-* skill
# directories, and creates the two symlinks the layout depends on. Anything you
# don't supply is left as a visible {{PLACEHOLDER}} and reported at the end, so
# nothing goes silently blank.
#
# Required:
#   --org NAME            Organization/product name, e.g. Acme
#   --github-org SLUG     GitHub org, e.g. acme-ai
#   --owner NAME          The human who owns published words + gets filed tickets
#
# Optional (left as placeholders if omitted):
#   --hub-name NAME       Hub repo name            [default: <slug>-workspace]
#   --slug SLUG           Lowercase slug           [default: lowercased --org]
#   --app-repo REPO       Repo needing the review gate, e.g. app.acme.com
#   --handbook-repo REPO  Operating-model repo, e.g. acme-os
#   --artifacts-repo REPO Published-pages repo, e.g. engineering-artifacts
#   --artifacts-domain D  Where those pages serve, e.g. artifacts.acme.com
#   --backend-host HOST   Backend host used in MCP examples
#   --reviewer NAME       Whose review patterns the PR checklist encodes
#   --catchall-project P  Tracker project for unfiled work, e.g. "Ops Log"
#
#   --dry-run             Print what would change, change nothing
#   --keep-blueprint      Keep BLUEPRINT.md at the root as well as docs/
#
# Example:
#   ./instantiate.sh --org Acme --github-org acme-ai --owner "Jane Doe" \
#       --app-repo app.acme.com --handbook-repo acme-os --reviewer "Sam"

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
KEEP_BLUEPRINT=0

ORG=""; GITHUB_ORG=""; OWNER=""; HUB_NAME=""; SLUG=""
APP_REPO=""; HANDBOOK_REPO=""; ARTIFACTS_REPO=""; ARTIFACTS_DOMAIN=""
BACKEND_HOST=""; REVIEWER=""; CATCHALL_PROJECT=""

usage() { sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --org)              ORG="${2:?}"; shift ;;
    --github-org)       GITHUB_ORG="${2:?}"; shift ;;
    --owner)            OWNER="${2:?}"; shift ;;
    --hub-name)         HUB_NAME="${2:?}"; shift ;;
    --slug)             SLUG="${2:?}"; shift ;;
    --app-repo)         APP_REPO="${2:?}"; shift ;;
    --handbook-repo)    HANDBOOK_REPO="${2:?}"; shift ;;
    --artifacts-repo)   ARTIFACTS_REPO="${2:?}"; shift ;;
    --artifacts-domain) ARTIFACTS_DOMAIN="${2:?}"; shift ;;
    --backend-host)     BACKEND_HOST="${2:?}"; shift ;;
    --reviewer)         REVIEWER="${2:?}"; shift ;;
    --catchall-project) CATCHALL_PROJECT="${2:?}"; shift ;;
    --dry-run)          DRY_RUN=1 ;;
    --keep-blueprint)   KEEP_BLUEPRINT=1 ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[ -n "$ORG" ] && [ -n "$GITHUB_ORG" ] && [ -n "$OWNER" ] || {
  echo "error: --org, --github-org and --owner are required" >&2; usage >&2; exit 2; }

# Derived defaults.
[ -n "$SLUG" ] || SLUG="$(printf '%s' "$ORG" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
[ -n "$HUB_NAME" ] || HUB_NAME="${SLUG}-workspace"
ORG_UPPER="$(printf '%s' "$SLUG" | tr '[:lower:]-' '[:upper:]_')"
HUB_ENV_VAR="${ORG_UPPER}_HUB"

log() { printf '%s\n' "$*"; }
run() { if [ "$DRY_RUN" = 1 ]; then log "  [dry-run] $*"; else eval "$*"; fi; }

# sed -i takes an argument on BSD/macOS and none on GNU.
if sed --version >/dev/null 2>&1; then SED_INPLACE=(sed -i); else SED_INPLACE=(sed -i ''); fi

log "Instantiating hub for '${ORG}' (slug: ${SLUG}, hub: ${HUB_NAME}, env: \$${HUB_ENV_VAR})"

# 1. CLAUDE.md from the template.
if [ -f "$KIT_DIR/CLAUDE.md.template" ]; then
  log "CLAUDE.md <- CLAUDE.md.template"
  run "mv '$KIT_DIR/CLAUDE.md.template' '$KIT_DIR/CLAUDE.md'"
fi

# 2. Substitute placeholders. Only the ones actually supplied: an omitted value
#    must stay a visible {{PLACEHOLDER}} rather than becoming an empty string.
subs=()
add_sub() { [ -n "$2" ] && subs+=("-e" "s|{{$1}}|$2|g") || true; }
add_sub ORG               "$ORG"
add_sub org               "$SLUG"
add_sub ORG_UPPER         "$ORG_UPPER"
add_sub HUB_NAME          "$HUB_NAME"
add_sub HUB_ENV_VAR       "$HUB_ENV_VAR"
add_sub GITHUB_ORG        "$GITHUB_ORG"
add_sub OWNER_NAME        "$OWNER"
add_sub OWNER             "$OWNER"
add_sub APP_REPO          "$APP_REPO"
add_sub HANDBOOK_REPO     "$HANDBOOK_REPO"
add_sub ARTIFACTS_REPO    "$ARTIFACTS_REPO"
add_sub ARTIFACTS_DOMAIN  "$ARTIFACTS_DOMAIN"
add_sub BACKEND_HOST      "$BACKEND_HOST"
add_sub REVIEWER          "$REVIEWER"
add_sub CATCHALL_PROJECT  "$CATCHALL_PROJECT"

files="$(grep -rl '{{[A-Za-z_]*}}' "$KIT_DIR" \
           --exclude-dir=.git --exclude-dir=__pycache__ \
           --exclude='*.pyc' --exclude=instantiate.sh --exclude=README.md 2>/dev/null || true)"
if [ -n "$files" ]; then
  log "Substituting $(printf '%s\n' "$files" | wc -l | tr -d ' ') files"
  if [ "$DRY_RUN" = 1 ]; then
    printf '%s\n' "$files" | sed 's/^/  [dry-run] /'
  else
    printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 "${SED_INPLACE[@]}" "${subs[@]}"
  fi
fi

# 3. Rename the ORGSLUG-* paths (a token, not a placeholder, so it is safe in a filename).
for path in "$KIT_DIR"/.agents/skills/ORGSLUG-* "$KIT_DIR"/scripts/ORGSLUG-*; do
  [ -e "$path" ] || continue
  new="$(dirname "$path")/$(basename "$path" | sed "s/^ORGSLUG-/${SLUG}-/")"
  log "rename $(basename "$path") -> $(basename "$new")"
  run "mv '$path' '$new'"
done

# 4. The two symlinks the layout depends on (zip archives don't carry them reliably).
[ -e "$KIT_DIR/AGENTS.md" ]        || { log "symlink AGENTS.md -> CLAUDE.md"; run "ln -s CLAUDE.md '$KIT_DIR/AGENTS.md'"; }
[ -e "$KIT_DIR/.claude/skills" ]   || { log "symlink .claude/skills -> ../.agents/skills"; run "ln -s ../.agents/skills '$KIT_DIR/.claude/skills'"; }

# 5. The blueprint belongs under docs/ in a real hub.
if [ -f "$KIT_DIR/BLUEPRINT.md" ] && [ "$KEEP_BLUEPRINT" = 0 ]; then
  log "BLUEPRINT.md -> docs/HUB-BLUEPRINT.md"
  run "mv '$KIT_DIR/BLUEPRINT.md' '$KIT_DIR/docs/HUB-BLUEPRINT.md'"
fi

run "chmod +x '$KIT_DIR'/scripts/*.sh '$KIT_DIR'/.claude/hooks/*.sh '$KIT_DIR'/.claude/autonomous-gate/*.sh 2>/dev/null || true"

# 6. Report what is still unfilled — the honest part.
log ""
if [ "$DRY_RUN" = 1 ]; then log "[dry-run] nothing changed."; exit 0; fi
remaining="$(grep -rho '{{[A-Za-z_]*}}' "$KIT_DIR" \
              --exclude-dir=.git --exclude-dir=__pycache__ \
              --exclude='*.pyc' --exclude=instantiate.sh --exclude=README.md \
              --exclude=HUB-BLUEPRINT.md 2>/dev/null | sort -u || true)"
if [ -n "$remaining" ]; then
  log "STILL UNFILLED — supply these or edit by hand:"
  printf '%s\n' "$remaining" | sed 's/^/  /'
  log ""
fi
log "Done. Next:"
log "  1. Write CLAUDE.md's RULE 0 and Mission sections. They are prompts, not prose —"
log "     a sed cannot fill them and the agent needs them most."
log "  2. git init && git add -A && git commit"
log "  3. scripts/bootstrap-agent.sh --agent claude"
log "  4. Author your first skill. .agents/skills/ is empty on purpose; its README.md"
log "     has the anatomy, the naming rule that silently breaks skills, and a"
log "     starter roster of five."
