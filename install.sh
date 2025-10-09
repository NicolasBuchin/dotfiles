#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

DRY_RUN=0
FORCE=0
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
  DRY_RUN=1
elif [[ "${1:-}" == "--force" ]]; then
  FORCE=1
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<EOF
Usage: install_dotfiles.sh [--dry-run|-n] [--force]
  --dry-run, -n   show what would be done
  --force         overwrite without making backups
EOF
  exit 0
fi

# items to restore (mirror collect_dotfiles.sh)
items=(
  ".bashrc"
  ".config/hypr"
  ".config/waybar"
  ".config/alacritty"
  ".config/nvim"
  ".config/fastfetch"
  ".config/nemo"
  ".config/gtk-3.0"
  ".config/swaync"
)

# choose copy method
if command -v rsync >/dev/null 2>&1; then
  COPY_CMD="rsync -a --delete"
else
  COPY_CMD="cp -a"
fi

# backup folder
BACKUP_BASE="$HOME/dotfiles-backup-$(date +%Y%m%dT%H%M%S)"
if [[ $FORCE -eq 0 && $DRY_RUN -eq 0 ]]; then
  echo "Backups of overwritten files will be placed in: $BACKUP_BASE"
fi

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "+ $*"
  else
    echo "=> $*"
    eval "$@"
  fi
}

for rel in "${items[@]}"; do
  src="$REPO_DIR/$rel"
  dst="$HOME/$rel"

  if [[ ! -e "$src" ]]; then
    echo "skip (not in repo): $rel"
    continue
  fi

  dstdir="$(dirname "$dst")"
  # prepare destination dir
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "+ mkdir -p \"$dstdir\""
  else
    mkdir -p "$dstdir"
  fi

  # backup existing files if not forcing
  if [[ -e "$dst" && $FORCE -eq 0 ]]; then
    echo "existing: $dst"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "+ mkdir -p \"$BACKUP_BASE/$(dirname "$rel")\""
      echo "+ mv -v \"$dst\" \"$BACKUP_BASE/$rel\""
    else
      mkdir -p "$BACKUP_BASE/$(dirname "$rel")"
      mv -v "$dst" "$BACKUP_BASE/$rel"
    fi
  elif [[ -e "$dst" && $FORCE -eq 1 ]]; then
    echo "overwriting (force): $dst"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "+ rm -rf \"$dst\""
    else
      rm -rf "$dst"
    fi
  fi

  # copy from repo to home
  if command -v rsync >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "+ rsync -a --dry-run \"$src/\" \"$dstdir/\""
    else
      rsync -a "$src/" "$dstdir/"
    fi
  else
    # cp fallback
    if [[ -d "$src" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "+ cp -a \"$src\" \"$dstdir/\""
      else
        cp -a "$src" "$dstdir/"
      fi
    else
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "+ cp -a \"$src\" \"$dst\""
      else
        cp -a "$src" "$dst"
      fi
    fi
  fi
done

echo "Done. If you ran without --dry-run, review and reload relevant apps (Hyprland, Waybar, Neovim, etc)."

