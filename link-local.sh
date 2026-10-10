#!/usr/bin/env bash
# Symlink every skill in this repo into ~/.claude/skills so edits here are live
# in Claude Code without reinstalling the plugin.
#
# Usage: ./link-local.sh [--force]
#   --force  replace an existing non-symlink entry with the same name
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
force=false
[[ "${1:-}" == "--force" ]] && force=true

mkdir -p "$target_dir"

shopt -s nullglob
for skill in "$repo_root"/*/skills/*/; do
  skill="${skill%/}"
  [[ -f "$skill/SKILL.md" ]] || continue
  name="$(basename "$skill")"
  dest="$target_dir/$name"

  if [[ -L "$dest" ]]; then
    ln -sfn "$skill" "$dest"
    echo "relinked  $name"
  elif [[ -e "$dest" ]]; then
    if $force; then
      rm -rf "$dest"
      ln -s "$skill" "$dest"
      echo "replaced  $name"
    else
      echo "skipped   $name ($dest exists and is not a symlink; use --force)" >&2
    fi
  else
    ln -s "$skill" "$dest"
    echo "linked    $name"
  fi
done
