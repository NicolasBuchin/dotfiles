#!/usr/bin/env bash
set -euo pipefail

# Location of this repo:
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
# where to store static files like wallpapers
STATIC_DIR="$REPO_DIR/static"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
  DRY_RUN=1
fi

# Items to collect (edit this list if you want to add/remove)
items=(
  "$HOME/.bashrc"
  "$HOME/.config/hypr"
  "$HOME/.config/waybar"
  "$HOME/.config/alacritty"
  "$HOME/.config/nvim"
  "$HOME/.config/fastfetch"
  "$HOME/.config/nemo"
  "$HOME/.config/gtk-3.0"
  "$HOME/.config/swaync"
)

# helper to run or echo
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "+ $*"
  else
    echo "=> $*"
    eval "$@"
  fi
}

# Choose copy program - prefer rsync if available
if command -v rsync >/dev/null 2>&1; then
  COPY_CMD="rsync -a --delete"
else
  COPY_CMD="cp -a"
fi

echo "Repo: $REPO_DIR"
echo "Dry run: $DRY_RUN"

# Copy items into repo, preserving path under repo (strip $HOME)
for src in "${items[@]}"; do
  if [[ -e "$src" ]]; then
    rel="${src/#$HOME\//}"      # strip leading $HOME/
    dest="$REPO_DIR/$rel"
    destdir="$(dirname "$dest")"
    run mkdir -p "$(printf '%q' "$destdir")"
    if [[ "$COPY_CMD" == rsync* ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "+ $COPY_CMD --dry-run \"$src\" \"$destdir/\""
      else
        rsync -a "$src" "$destdir/"
      fi
    else
      # cp fallback
      if [[ -d "$src" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          echo "+ cp -a \"$src\" \"$destdir/\""
        else
          cp -a "$src" "$destdir/"
        fi
      else
        if [[ $DRY_RUN -eq 1 ]]; then
          echo "+ cp -a \"$src\" \"$dest\""
        else
          cp -a "$src" "$dest"
        fi
      fi
    fi
  else
    echo "warning: source not found: $src"
  fi
done

