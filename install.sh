#!/usr/bin/env bash
# sshls installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cobanov/sshls/main/install.sh | bash
#
# Env vars:
#   PREFIX   install directory (default: $HOME/.local/bin, falls back to /usr/local/bin)
#   REF      git ref to install from (default: main)

set -euo pipefail

REPO="cobanov/sshls"
REF="${REF:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${REF}/sshls"

c_green=$'\033[38;5;46m'; c_red=$'\033[38;5;203m'
c_dim=$'\033[2m';        c_bold=$'\033[1m'; c_reset=$'\033[0m'

say()  { printf "  %s%s%s\n" "$c_dim" "$*" "$c_reset"; }
ok()   { printf "  %s✓%s %s\n" "$c_green" "$c_reset" "$*"; }
die()  { printf "  %s✗%s %s\n" "$c_red"   "$c_reset" "$*" >&2; exit 1; }

printf "\n  %s%ssshls%s installer\n\n" "$c_bold" "$c_green" "$c_reset"

# pick install dir
if [[ -n "${PREFIX:-}" ]]; then
  TARGET_DIR="$PREFIX"
elif [[ -d "$HOME/.local/bin" || ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  TARGET_DIR="$HOME/.local/bin"
else
  TARGET_DIR="/usr/local/bin"
fi

mkdir -p "$TARGET_DIR" 2>/dev/null || die "cannot create $TARGET_DIR"
TARGET="$TARGET_DIR/sshls"
say "installing to $TARGET"

# download
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
if command -v curl >/dev/null; then
  curl -fsSL "$RAW" -o "$TMP" || die "download failed: $RAW"
elif command -v wget >/dev/null; then
  wget -q "$RAW" -O "$TMP" || die "download failed: $RAW"
else
  die "need curl or wget"
fi

# move into place (use sudo if dir not writable)
if [[ -w "$TARGET_DIR" ]]; then
  install -m 0755 "$TMP" "$TARGET"
else
  say "need sudo to write to $TARGET_DIR"
  sudo install -m 0755 "$TMP" "$TARGET"
fi
ok "installed $("$TARGET" -V 2>/dev/null || echo sshls)"

# warn if not on PATH
case ":$PATH:" in
  *":$TARGET_DIR:"*) : ;;
  *)
    printf "\n  %s%s$TARGET_DIR is not on your PATH.%s\n" "$c_bold" "$c_red" "$c_reset"
    printf "  add this to your shell rc:\n\n"
    printf "    %sexport PATH=\"$TARGET_DIR:\$PATH\"%s\n" "$c_bold" "$c_reset"
    ;;
esac

# dependency check: ssh is required; tailscale + jq are optional (without
# them sshls still works, it just shows raw IPs instead of device names).
command -v ssh >/dev/null || die "ssh not found in PATH (required)"
opt_missing=()
command -v tailscale >/dev/null || opt_missing+=("tailscale")
command -v jq        >/dev/null || opt_missing+=("jq")
if (( ${#opt_missing[@]} )); then
  printf "\n  %soptional (for device-name resolution): %s%s\n" \
    "$c_dim" "${opt_missing[*]}" "$c_reset"
  printf "  %son macOS: brew install %s%s\n" "$c_dim" "${opt_missing[*]}" "$c_reset"
fi

printf "\n  run %ssshls --help%s to get started.\n\n" "$c_bold" "$c_reset"
