#!/usr/bin/env bash
# Smoke test: confirm codexbar is installed, on PATH, and the JSON subcommand works.
# Exits non-zero on any failure so CI can fail fast.
set -euo pipefail

ok()   { printf '\033[32m  ✓\033[0m %s\n' "$1"; }
fail() { printf '\033[31m  ✗\033[0m %s\n' "$1"; exit 1; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

hdr "binary"
if command -v codexbar >/dev/null 2>&1; then
  ok "codexbar on PATH ($(command -v codexbar))"
else
  cat <<EOF
  \033[33mcodexbar not installed.\033[0m
  Install via:
    yay -S codexbar-cli
    brew install steipete/tap/codexbar
  Then re-run this script.
EOF
  exit 1
fi

hdr "version"
if codexbar --version >/dev/null 2>&1; then
  ok "codexbar --version → $(codexbar --version)"
else
  fail "codexbar --version failed"
fi

hdr "providers list"
if codexbar providers list --format json >/dev/null 2>&1; then
  n=$(codexbar providers list --format json 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))')
  ok "providers list returned ${n} providers"
else
  fail "codexbar providers list --format json failed — check CLI version >= 0.x"
fi

hdr "config"
if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/codexbar/config.json" ]]; then
  ok "config.json present"
else
  printf '  \033[33m~ no config.json yet (run: codexbar config providers)\033[0m\n'
fi

hdr "ok"
