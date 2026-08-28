#!/usr/bin/env bash
# Development link: symlink this checkout into ~/.config/omarchy/plugins/<id>
# so the shell hot-reloads edits on save. Run once per machine; safe to re-run.
set -euo pipefail

id="joshuaswarren.codexbar"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/${id}"

mkdir -p "$(dirname "$dest")"

if [[ -e "$dest" && ! -L "$dest" ]]; then
  printf '\033[31m%s exists and is not a symlink. Move it aside and re-run.\033[0m\n' "$dest" >&2
  exit 1
fi

ln -snf "$repo_root" "$dest"
printf '\033[32mlinked\033[0m %s -> %s\n' "$dest" "$repo_root"
printf 'Run: omarchy-shell shell rescanPlugins\n'
