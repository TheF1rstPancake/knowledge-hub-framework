#!/usr/bin/env bash
#
# bootstrap-agent.sh — install the {{ORG}} shared layer for one coding agent.
#
# The canonical skills live under .agents/skills. Claude remains compatible via
# its existing bootstrap script; Codex and Cursor receive user-scope symlinks.
#
# Usage:
#   scripts/bootstrap-agent.sh --agent claude|codex|cursor [--with-mcp]
#   scripts/bootstrap-agent.sh --agent all [--with-mcp]
#   scripts/bootstrap-agent.sh --agent claude|codex|cursor --status
#   scripts/bootstrap-agent.sh --agent claude|codex|cursor --uninstall [--with-mcp]
#
# Existing Claude installations are deliberately left in place. Do not run the
# legacy bootstrap's --uninstall as part of this migration.

set -euo pipefail

HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$HUB_DIR/.agents/skills"
ACTION="install"
WITH_MCP=0
AGENTS=()

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agent)
      value="${2:?--agent needs a value}"; shift
      if [ "$value" = all ]; then AGENTS=(claude codex cursor); else AGENTS+=("$value"); fi
      ;;
    --with-mcp) WITH_MCP=1 ;;
    --status) ACTION="status" ;;
    --uninstall) ACTION="uninstall" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[ ${#AGENTS[@]} -gt 0 ] || { echo "pass --agent claude, codex, cursor, or all" >&2; exit 2; }
for agent in "${AGENTS[@]}"; do
  case "$agent" in claude|codex|cursor) ;; *) echo "unknown agent: $agent" >&2; exit 2 ;; esac
done

link_skills() {
  local destination="$1" skill name
  mkdir -p "$destination"
  for skill in "$SKILLS_SRC"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    if [ -e "$destination/$name" ] && [ ! -L "$destination/$name" ]; then
      echo "SKIP $destination/$name: existing non-symlink directory" >&2
      continue
    fi
    ln -sfn "$skill" "$destination/$name"
  done
}

unlink_skills() {
  local destination="$1" skill name target
  [ -d "$destination" ] || return 0
  for skill in "$SKILLS_SRC"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    target="$destination/$name"
    [ -L "$target" ] && [ "$(readlink "$target")" = "$skill" ] && rm "$target"
  done
}

show_status() {
  local destination="$1" skill name
  for skill in "$SKILLS_SRC"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    if [ -L "$destination/$name" ]; then
      echo "ok    $destination/$name -> $(readlink "$destination/$name")"
    else
      echo "miss  $destination/$name"
    fi
  done
}

for agent in "${AGENTS[@]}"; do
  echo "[$agent]"
  case "$agent:$ACTION" in
    claude:install)
      "$HUB_DIR/scripts/bootstrap-claude.sh"
      ;;
    claude:status)
      "$HUB_DIR/scripts/bootstrap-claude.sh" --status
      ;;
    claude:uninstall) "$HUB_DIR/scripts/bootstrap-claude.sh" --uninstall ;;
    codex:install)
      link_skills "$HOME/.agents/skills"
      link_skills "$HOME/.codex/skills"
      ;;
    codex:status) show_status "$HOME/.codex/skills" ;;
    codex:uninstall) unlink_skills "$HOME/.codex/skills" ;;
    cursor:install)
      link_skills "$HOME/.agents/skills"
      link_skills "$HOME/.cursor/skills"
      ;;
    cursor:status) show_status "$HOME/.cursor/skills" ;;
    cursor:uninstall) unlink_skills "$HOME/.cursor/skills" ;;
  esac
  if [ "$WITH_MCP" = 1 ]; then
    case "$ACTION" in
      install) "$HUB_DIR/scripts/install-agent-mcp.sh" --agent "$agent" ;;
      uninstall) "$HUB_DIR/scripts/install-agent-mcp.sh" --agent "$agent" --remove ;;
      status) "$HUB_DIR/scripts/install-agent-mcp.sh" --agent "$agent" --list ;;
    esac
  fi
done
