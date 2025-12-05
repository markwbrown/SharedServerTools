#!/usr/bin/env bash
set -euo pipefail

# install.sh - symlink server-tools/bin/* into a target directory (default: /usr/local/bin or ~/.local/bin)

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --user              Install for current user under ~/.local/bin (default if not root)
  --system            Install under /usr/local/bin (default if root)
  --target-dir DIR    Install into DIR explicitly
  -h, --help          Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --user
  $(basename "$0") --system
  $(basename "$0") --target-dir /opt/server-tools/bin
EOF
  exit 0
}

# Resolve repo root (where install.sh lives)
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ "$SCRIPT_SOURCE" != /* ]] && SCRIPT_SOURCE="$DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

BIN_SOURCE_DIR="$REPO_ROOT/bin"

if [ ! -d "$BIN_SOURCE_DIR" ]; then
  echo "Error: bin/ directory not found under $REPO_ROOT" >&2
  exit 1
fi

TARGET_DIR=""
MODE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --user)
      MODE="user"
      shift
      ;;
    --system)
      MODE="system"
      shift
      ;;
    --target-dir)
      [ $# -ge 2 ] || { echo "Error: --target-dir requires a path" >&2; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

# Decide default mode if not specified
if [ -z "$MODE" ]; then
  if [ "$EUID" -eq 0 ]; then
    MODE="system"
  else
    MODE="user"
  fi
fi

# Decide default target dir if not specified
if [ -z "$TARGET_DIR" ]; then
  if [ "$MODE" = "system" ]; then
    TARGET_DIR="/usr/local/bin"
  else
    TARGET_DIR="$HOME/.local/bin"
  fi
fi

echo "Installing symlinks from:"
echo "  $BIN_SOURCE_DIR"
echo "into:"
echo "  $TARGET_DIR"
echo

# Helper to run a command with sudo if needed
run_cmd() {
  local cmd=("$@")

  if [ -w "$TARGET_DIR" ] || [ ! -e "$TARGET_DIR" ] && [ -w "$(dirname "$TARGET_DIR")" ]; then
    "${cmd[@]}"
  else
    if command -v sudo >/dev/null 2>&1; then
      echo "Using sudo for: ${cmd[*]}"
      sudo "${cmd[@]}"
    else
      echo "Error: Cannot write to $TARGET_DIR and sudo is not available." >&2
      exit 1
    fi
  fi
}

# Create target dir
if [ ! -d "$TARGET_DIR" ]; then
  echo "Creating $TARGET_DIR..."
  run_cmd mkdir -p "$TARGET_DIR"
fi

# Install symlinks for each file in bin/
echo "Linking scripts:"
for src in "$BIN_SOURCE_DIR"/*; do
  [ -f "$src" ] || continue
  base="$(basename "$src")"
  dest="$TARGET_DIR/$base"

  # Ensure executable bit
  if [ ! -x "$src" ]; then
    echo "  Making $src executable"
    chmod +x "$src"
  fi

  # Backup existing non-matching file
  if [ -e "$dest" ]; then
    # If it is already the correct symlink, skip
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      echo "  $base already linked, skipping"
      continue
    fi

    backup="${dest}.bak.$(date +%s)"
    echo "  Backing up existing $dest to $backup"
    run_cmd mv "$dest" "$backup"
  fi

  echo "  -> $base"
  run_cmd ln -s "$src" "$dest"
done

echo
# PATH hint
case ":$PATH:" in
  *":$TARGET_DIR:"*)
    echo "Done. $TARGET_DIR is already in your PATH."
    ;;
  *)
    echo "Done, but $TARGET_DIR is not in your PATH."
    echo "Add this line to your shell config (~/.bashrc, ~/.zshrc, etc):"
    echo "  export PATH=\"$TARGET_DIR:\$PATH\""
    ;;
esac
