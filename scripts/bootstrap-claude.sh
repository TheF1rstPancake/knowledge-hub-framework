#!/usr/bin/env bash
#
# bootstrap-claude.sh — install (or remove) the {{ORG}} hub into ~/.claude/
#
# Legacy Claude entry point. For new multi-agent setup use
# scripts/bootstrap-agent.sh --agent claude|codex|cursor.
#
# Wires this hub repo's skills and CLAUDE.md into user-scope Claude config so
# they load in EVERY repo, not just under this directory. Everything it creates
# is recorded in a manifest, so `--uninstall` removes exactly what it added and
# nothing else — no orphaned symlinks, no guessing.
#
# Usage:
#   scripts/bootstrap-claude.sh              install / refresh (idempotent)
#   scripts/bootstrap-claude.sh --dry-run    print what would change, do nothing
#   scripts/bootstrap-claude.sh --uninstall  remove everything this script created
#   scripts/bootstrap-claude.sh --status     show current manifest + link state
#
# Safe to re-run. Re-running after editing skills or CLAUDE.md refreshes links.

set -euo pipefail

HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SKILLS_SRC="${HUB_DIR}/.agents/skills"
SKILLS_DST="${CLAUDE_DIR}/skills"
PORTABLE_SKILLS_DST="${HOME}/.agents/skills"
CLAUDEMD_SRC="${HUB_DIR}/CLAUDE.md"
CLAUDEMD_DST="${CLAUDE_DIR}/CLAUDE.md"
SETTINGS_DST="${CLAUDE_DIR}/settings.json"
MANIFEST="${CLAUDE_DIR}/.{{org}}-hub-manifest"

DRY_RUN=0
MODE="install"
CLONE_REPOS=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=1 ;;
    --uninstall)  MODE="uninstall" ;;
    --status)     MODE="status" ;;
    --with-repos) CLONE_REPOS=1 ;;
    -h|--help)    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '%s\n' "$*"; }
run()  { if [ "$DRY_RUN" = 1 ]; then log "  [dry-run] $*"; else eval "$*"; fi; }

# install_env_key KEY VALUE
# Additively merge a single env var into settings.json without disturbing any
# other key. Claims ownership (records `settings-env:KEY` in the manifest) only
# if we set it. If the key already holds VALUE and a prior manifest shows we own
# it, ownership is preserved across re-runs. If it pre-exists independently, we
# leave it and never remove it on uninstall. A conflicting value is left alone.
# Reads: SETTINGS_DST, MANIFEST (old), TMP_MANIFEST. Honors DRY_RUN via run().
install_env_key() {
  local key="$1" val="$2" we_own=0 existing
  if [ -f "$MANIFEST" ] && grep -qx "settings-env:${key}" "$MANIFEST" 2>/dev/null; then
    we_own=1
  fi
  if [ ! -f "$SETTINGS_DST" ]; then
    log "  create ${SETTINGS_DST} with env.${key}"
    run "printf '%s' '{}' | jq '.env.\"${key}\" = \$v' --arg v '${val}' > '$SETTINGS_DST'"
    printf 'settings-env:%s\n' "$key" >> "$TMP_MANIFEST"
    return
  fi
  existing="$(jq -r ".env[\"$key\"] // \"<unset>\"" "$SETTINGS_DST" 2>/dev/null || echo "<unset>")"
  if [ "$existing" = "<unset>" ]; then
    log "  set env.${key} in ${SETTINGS_DST}"
    run "tmp=\$(mktemp); jq '.env = (.env // {}) | .env.\"${key}\" = \$v' --arg v '${val}' '$SETTINGS_DST' > \"\$tmp\" && mv \"\$tmp\" '$SETTINGS_DST'"
    printf 'settings-env:%s\n' "$key" >> "$TMP_MANIFEST"
  elif [ "$existing" = "$val" ]; then
    if [ "$we_own" = 1 ]; then
      log "  env.${key} already = expected (we own it); keeping ownership"
      printf 'settings-env:%s\n' "$key" >> "$TMP_MANIFEST"
    else
      log "  env.${key} already set (pre-existing, not ours); leaving it, won't remove on uninstall"
    fi
  else
    log "  WARN env.${key} already set to '${existing}' (expected '${val}') — leaving your value untouched"
  fi
}

# --- status -----------------------------------------------------------------
if [ "$MODE" = "status" ]; then
  log "hub:      ${HUB_DIR}"
  log "manifest: ${MANIFEST}"
  if [ -f "$MANIFEST" ]; then
    log "--- managed entries ---"
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      case "$entry" in
        settings-env:*)
          key="${entry#settings-env:}"
          cur="$(jq -r ".env[\"$key\"] // \"<unset>\"" "$SETTINGS_DST" 2>/dev/null || echo "<no settings.json>")"
          log "  env   ${key}=${cur} (in ${SETTINGS_DST})"
          ;;
        *)
          if [ -L "$entry" ]; then
            log "  ok    $entry -> $(readlink "$entry")"
          elif [ -e "$entry" ]; then
            log "  ?     $entry (exists, not a symlink)"
          else
            log "  gone  $entry"
          fi
          ;;
      esac
    done < "$MANIFEST"
  else
    log "no manifest — hub not installed"
  fi
  exit 0
fi

# --- uninstall --------------------------------------------------------------
if [ "$MODE" = "uninstall" ]; then
  if [ ! -f "$MANIFEST" ]; then
    log "no manifest at ${MANIFEST} — nothing to remove"
    exit 0
  fi
  log "Removing hub entries recorded in ${MANIFEST}:"
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    case "$entry" in
      settings-env:*)
        key="${entry#settings-env:}"
        if [ -f "$SETTINGS_DST" ]; then
          log "  unset env ${key} in ${SETTINGS_DST} (we added it)"
          run "tmp=\$(mktemp); jq 'if has(\"env\") then (.env |= del(.[\"$key\"])) else . end | if (.env // {}) == {} then del(.env) else . end' '$SETTINGS_DST' > \"\$tmp\" && mv \"\$tmp\" '$SETTINGS_DST'"
        fi
        ;;
      *)
        if [ -L "$entry" ]; then
          log "  rm symlink $entry"
          run "rm '$entry'"
        elif [ -e "$entry" ]; then
          log "  SKIP $entry — exists but is not a symlink (not touching it)"
        else
          log "  (already gone) $entry"
        fi
        ;;
    esac
  done < "$MANIFEST"
  # restore a backed-up CLAUDE.md if we made one
  if [ -e "${CLAUDEMD_DST}.{{org}}-bak" ]; then
    log "  restoring ${CLAUDEMD_DST} from backup"
    run "mv '${CLAUDEMD_DST}.{{org}}-bak' '${CLAUDEMD_DST}'"
  fi
  run "rm -f '$MANIFEST'"
  log "Done. ~/.claude/ is back to its pre-hub state for everything this script managed."
  exit 0
fi

# --- install ----------------------------------------------------------------
log "Installing {{ORG}} hub from ${HUB_DIR} into ${CLAUDE_DIR}"
run "mkdir -p '$SKILLS_DST'"
run "mkdir -p '$PORTABLE_SKILLS_DST'"

# Fresh manifest each install; we rebuild it from the current hub skill set.
TMP_MANIFEST="$(mktemp)"

# 1. Skills — one symlink per hub skill. Refuse to clobber a non-symlink
#    (e.g. a real skill dir that didn't come from the hub).
for skill_path in "$SKILLS_SRC"/*/; do
  [ -d "$skill_path" ] || continue
  name="$(basename "$skill_path")"
  for dst in "${SKILLS_DST}/${name}" "${PORTABLE_SKILLS_DST}/${name}"; do
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      log "  SKIP skill '${name}' — ${dst} exists and is NOT a symlink (a real dir lives there; not overwriting)"
      continue
    fi
    log "  link skill ${name}"
    run "ln -sfn '${skill_path%/}' '$dst'"
    printf '%s\n' "$dst" >> "$TMP_MANIFEST"
  done
done

# 2. CLAUDE.md — symlink into user scope. Back up any pre-existing real file.
if [ -e "$CLAUDEMD_DST" ] && [ ! -L "$CLAUDEMD_DST" ]; then
  log "  backing up existing ${CLAUDEMD_DST} -> ${CLAUDEMD_DST}.{{org}}-bak"
  run "mv '$CLAUDEMD_DST' '${CLAUDEMD_DST}.{{org}}-bak'"
fi
log "  link CLAUDE.md"
run "ln -sfn '$CLAUDEMD_SRC' '$CLAUDEMD_DST'"
printf '%s\n' "$CLAUDEMD_DST" >> "$TMP_MANIFEST"

# 3. settings.json env vars — additive, surgical, ownership-tracked.
#    CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 → /add-dir loads the added
#      repo's CLAUDE.md, so one session spans sibling repos with full context.
#    {{HUB_ENV_VAR}}=<hub path> → lets skills/scripts resolve hub-relative paths
#      (findings, docs, ship.sh) from any repo cwd.
install_env_key "CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD" "1"
install_env_key "{{HUB_ENV_VAR}}" "$HUB_DIR"

# 4. Sibling repo locations — {{ORG_UPPER}}_BACKEND / {{ORG_UPPER}}_APP / {{ORG_UPPER}}_INFRA,
#    plus {{ORG_UPPER}}_OS (the company operating model; see CLAUDE.md).
#    Resolved by git remote, not by path convention, so a checkout in ~/dev or
#    ~/code works exactly as well as one beside the hub. Pinning them here means
#    skills never search at runtime and nobody edits a skill file to correct a
#    path. --with-repos clones whatever is missing (beside the hub) first.
#    Cloned something later? Re-run this script to pick it up.
#    --refresh is always passed: it fast-forwards only the read-only repos
#    ({{HANDBOOK_REPO}} today) and only when clean and on their default branch, so
#    re-running this script is how stale playbooks get current. Product repos
#    are never touched.
repo_args="--refresh"
[ "$CLONE_REPOS" = 1 ] && repo_args="--refresh --clone"
clone_note=""
[ "$CLONE_REPOS" = 1 ] && clone_note=" (cloning any that are missing)"
log "Resolving sibling repos${clone_note}"

# Capture once and split, rather than piping through grep: the clone/refresh
# notices are the half that matters when something is skipped, and filtering for
# {{ORG_UPPER}}_ lines would swallow them silently. A stale playbook that nobody was
# told about is exactly the failure {{HANDBOOK_REPO}}'s "true today" invariant is about.
repos_out="$("${HUB_DIR}/scripts/{{org}}-repos.sh" $repo_args 2>&1 || true)"
while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in
    {{ORG_UPPER}}_*=*) install_env_key "${line%%=*}" "${line#*=}" ;;
    *)           log "  ${line#  }" ;;
  esac
done <<<"$repos_out"

if [ "$DRY_RUN" = 1 ]; then
  log "[dry-run] manifest that would be written to ${MANIFEST}:"
  sed 's/^/  /' "$TMP_MANIFEST"
  rm -f "$TMP_MANIFEST"
else
  mv "$TMP_MANIFEST" "$MANIFEST"
  log "Done. Wrote manifest ${MANIFEST}."
  log "Skills and CLAUDE.md now load in every repo. Re-run --uninstall to fully reverse."
fi
