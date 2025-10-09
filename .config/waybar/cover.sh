#!/usr/bin/env bash
# cover.sh - robust album-art fetcher + square-cropper for Waybar
# Writes the path to a cached square thumbnail (or a 1x1 transparent PNG when no cover).
# Cache lives in $XDG_RUNTIME_DIR (preferred) or /tmp fallback and will be auto-cleaned on reboot/expiry.

set -euo pipefail

# --- configuration ---
SQUARE_SIZE=32            # final square size in px (match Waybar image size)
MAX_DOWNLOAD_SIZE=1048576 # 1 MiB, change if you want bigger covers
STALE_DAYS=7              # fallback cleanup: remove files older than this (only in fallback/defensive mode)
# ----------------------

# Resolve script directory for dynamic CSS output
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
COLOR_CSS="$SCRIPT_DIR/music-color.css"

# Prefer XDG_RUNTIME_DIR which is per-login and normally cleared by the system on logout/reboot
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
  CACHE_DIR="$XDG_RUNTIME_DIR/waybar-mpris-covers"
  RUNTIME_BACKED=1
else
  # fallback to /tmp with UID suffix so multiple users don't collide
  CACHE_DIR="/tmp/waybar-mpris-covers-$UID"
  RUNTIME_BACKED=0
fi

mkdir -p "$CACHE_DIR"

# Transparent PNG path (used to clear Waybar image). This is 1x1 so Waybar won't reserve the thumbnail size.
TRANSPARENT_SIZE=1
TRANSPARENT_PNG="$CACHE_DIR/transparent.${TRANSPARENT_SIZE}x${TRANSPARENT_SIZE}.png"

# Create a 1x1 transparent PNG (prefer ImageMagick/convert, else base64 fallback)
ensure_transparent_png() {
  if [ -f "$TRANSPARENT_PNG" ]; then
    return 0
  fi
  if command -v magick >/dev/null 2>&1; then
    magick -size "${TRANSPARENT_SIZE}x${TRANSPARENT_SIZE}" xc:none "$TRANSPARENT_PNG" 2>/dev/null || true
  elif command -v convert >/dev/null 2>&1; then
    convert -size "${TRANSPARENT_SIZE}x${TRANSPARENT_SIZE}" xc:none "$TRANSPARENT_PNG" 2>/dev/null || true
  else
    # Minimal 1x1 transparent PNG in base64
    tmp_b64="${CACHE_DIR}/transparent.b64.$$"
    cat > "$tmp_b64" <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=
B64
    if command -v base64 >/dev/null 2>&1; then
      base64 --decode "$tmp_b64" > "$TRANSPARENT_PNG" 2>/dev/null || true
    else
      # try perl decode if base64 not present
      perl -MMIME::Base64 -e 'print decode_base64(join("", <>))' "$tmp_b64" > "$TRANSPARENT_PNG" 2>/dev/null || true
    fi
    rm -f "$tmp_b64" 2>/dev/null || true
  fi

  # final guard: ensure file exists
  if [ ! -f "$TRANSPARENT_PNG" ]; then
    : > "$TRANSPARENT_PNG"
  fi
}

# Defensive cleanup for fallback cases: remove old files older than $STALE_DAYS
if [ "$RUNTIME_BACKED" -eq 0 ]; then
  if command -v find >/dev/null 2>&1; then
    find "$CACHE_DIR" -mindepth 1 -type f -mtime +"$STALE_DAYS" -delete 2>/dev/null || true
  fi
fi

# Ensure required utilities; if missing, behave safely (return transparent png)
command -v playerctl >/dev/null 2>&1 || { ensure_transparent_png; printf '%s' "$TRANSPARENT_PNG"; exit 0; }
command -v md5sum >/dev/null 2>&1 || { ensure_transparent_png; printf '%s' "$TRANSPARENT_PNG"; exit 0; }

TMP_PREFIX="$CACHE_DIR/tmp.$$"
TMP="$TMP_PREFIX"
trap 'rm -f "${TMP_PREFIX}"* 2>/dev/null || true' EXIT

safe_mv() {
  mv -f "$1" "$2" 2>/dev/null || ( cp -f "$1" "$2" && rm -f "$1" )
}

extract_dominant_color() {
  local img="$1"
  local color_file="$2"
  local IMGCMD=""
  if command -v magick >/dev/null 2>&1; then
    IMGCMD="magick"
  elif command -v convert >/dev/null 2>&1; then
    IMGCMD="convert"
  else
    echo "transparent" > "$color_file"
    return 1
  fi

  hex=$($IMGCMD "$img" -auto-orient -resize 1x1\! -format "%[hex:p{0,0}]" info:- 2>/dev/null || echo "")
  if [ -n "$hex" ]; then
    hex="${hex#\#}"
    if [ ${#hex} -eq 3 ]; then
      hex="$(printf "%c%c%c%c%c%c" "${hex:0:1}" "${hex:0:1}" "${hex:1:1}" "${hex:1:1}" "${hex:2:1}" "${hex:2:1}")"
    fi
    if [ ${#hex} -eq 6 ] || [ ${#hex} -eq 8 ]; then
      local r=$((16#${hex:0:2}))
      local g=$((16#${hex:2:2}))
      local b=$((16#${hex:4:2}))
      local a=0.6
      if [ ${#hex} -eq 8 ]; then
        a=$(awk "BEGIN{printf \"%.3f\", strtonum(\"0x${hex:6:2}\")/255}")
      fi
      printf 'rgba(%d,%d,%d,%.3f)\n' "$r" "$g" "$b" "$a" > "$color_file"
      return 0
    fi
  fi

  local px
  px=$($IMGCMD "$img" -auto-orient -resize 1x1\! -format "%[pixel:p{0,0}]" info:- 2>/dev/null || echo "")
  if [ -n "$px" ]; then
    if [[ "$px" =~ ([0-9]+)%.*,([0-9]+)%.*,([0-9]+)% ]]; then
      local pr=${BASH_REMATCH[1]}; local pg=${BASH_REMATCH[2]}; local pb=${BASH_REMATCH[3]}
      local r=$(( (pr * 255 + 50) / 100 ))
      local g=$(( (pg * 255 + 50) / 100 ))
      local b=$(( (pb * 255 + 50) / 100 ))
      printf 'rgba(%d,%d,%d,0.6)\n' "$r" "$g" "$b" > "$color_file"
      return 0
    fi

    if [[ "$px" =~ ([0-9]+)[^0-9]+([0-9]+)[^0-9]+([0-9]+) ]]; then
      local r=${BASH_REMATCH[1]}; local g=${BASH_REMATCH[2]}; local b=${BASH_REMATCH[3]}
      printf 'rgba(%d,%d,%d,0.6)\n' "$r" "$g" "$b" > "$color_file"
      return 0
    fi
  fi

  echo "transparent" > "$color_file"
  return 1
}

# Extract a representative color from the dark areas of the image (now using 25% darkest)
# Writes rgba(...) to $out or "transparent" on failure.
extract_dark_area_color() {
  local img="$1"
  local out="$2"
  local IMGCMD=""
  if command -v magick >/dev/null 2>&1; then
    IMGCMD="magick"
  elif command -v convert >/dev/null 2>&1; then
    IMGCMD="convert"
  else
    echo "transparent" > "$out"
    return 1
  fi

  local histf="${TMP_PREFIX}.hist"
  local colors="${TMP_PREFIX}.colors"
  local sorted="${TMP_PREFIX}.colors.sorted"

  # quantize and histogram
  if ! "$IMGCMD" "$img" -auto-orient -resize 200x200\> -colors 64 -format "%c\n" histogram:info:- 2> /dev/null > "$histf"; then
    echo "transparent" > "$out"
    return 1
  fi

  awk '{
    if (match($0, /^[[:space:]]*([0-9]+):.*#([0-9A-Fa-f]{6})/, m)) {
      cnt = m[1]; hex = m[2];
      r = strtonum("0x" substr(hex,1,2));
      g = strtonum("0x" substr(hex,3,2));
      b = strtonum("0x" substr(hex,5,2));
      lum = 0.2126*r + 0.7152*g + 0.0722*b;
      printf("%.6f %d %d %d %d\n", lum, cnt, r, g, b);
    }
  }' "$histf" > "$colors" || { echo "transparent" > "$out"; return 1; }

  total=$(awk '{s+=$2}END{print s+0}' "$colors")
  if [ -z "$total" ] || [ "$total" -eq 0 ]; then
    echo "transparent" > "$out"
    return 1
  fi

  sort -n "$colors" > "$sorted"

  # Use 25% darkest pixels (user request)
  target=$(awk -v t="$total" 'BEGIN{printf "%.0f", t*0.25}')

  awk -v target="$target" '
    BEGIN { cum=0; rsum=0; gsum=0; bsum=0; }
    {
      if (cum < target) {
        cnt = $2; r=$3; g=$4; b=$5;
        rsum += r*cnt; gsum += g*cnt; bsum += b*cnt;
        cum += cnt;
      }
    }
    END {
      if (cum == 0) { print "transparent"; exit }
      r = int(rsum / cum + 0.5); g = int(gsum / cum + 0.5); b = int(bsum / cum + 0.5);
      # slight darken factor to make it a tad more background-like
      df = 0.85;
      r = int(r*df + 0.5); g = int(g*df + 0.5); b = int(b*df + 0.5);
      printf("rgba(%d,%d,%d,1.0)\n", r, g, b);
    }
  ' "$sorted" > "$out" || { echo "transparent" > "$out"; return 1; }

  return 0
}

# Update CSS. args: hover_color background_color
# hover_color defaults to rgba(170,160,120,0.5) when "transparent"
# background_color defaults to transparent when "transparent"
update_css() {
  local hover="$1"
  local bg="$2"

  local hover_css
  local bg_css

  if [ "$hover" = "transparent" ]; then
    hover_css="rgba(170,160,120,0.5)"
  else
    hover_css="$hover"
  fi

  if [ "$bg" = "transparent" ]; then
    bg_css="transparent"
  else
    bg_css="$bg"
  fi

  cat > "$COLOR_CSS" << EOF
/* Auto-generated by cover.sh - album art colors */
#music {
  background: $bg_css;
  transition: background 180ms ease;
}
#music:hover {
  background: $hover_css;
}
EOF
}

# Get active player; exit if none
player=$(playerctl metadata --format '{{playerName}}' 2>/dev/null || true)
if [ -z "$player" ]; then
  ensure_transparent_png
  update_css "transparent" "transparent"
  printf '%s' "$TRANSPARENT_PNG"
  exit 0
fi

# Get art URL; exit if none
art=$(playerctl metadata --format '{{mpris:artUrl}}' 2>/dev/null || true)
if [ -z "$art" ]; then
  ensure_transparent_png
  update_css "transparent" "transparent"
  printf '%s' "$TRANSPARENT_PNG"
  exit 0
fi

# Hash art URL for stable cache key
hash=$(printf '%s' "$art" | md5sum | awk '{print $1}')
OUT_BASE="$CACHE_DIR/$hash"

# Helper: safe glob find cached file
find_cached() {
  local arr=( "$OUT_BASE".* )
  if [ "${#arr[@]}" -gt 0 ] && [ -e "${arr[0]}" ]; then
    printf '%s' "${arr[0]}"
    return 0
  fi
  return 1
}

OUT=""

case "$art" in
  data:*)
    if printf '%s' "$art" | grep -q ';base64,'; then
      payload="${art#*,}"
      if printf '%s' "$art" | grep -q '^data:image/png'; then ext=png
      elif printf '%s' "$art" | grep -q '^data:image/webp'; then ext=webp
      elif printf '%s' "$art" | grep -q '^data:image/svg'; then ext=svg
      else ext=jpg; fi
      OUT="$OUT_BASE.$ext"
      if [ ! -f "$OUT" ]; then
        if printf '%s' "$payload" | base64 --decode > "$TMP" 2>/dev/null; then
          safe_mv "$TMP" "$OUT"
        else
          rm -f "$TMP" 2>/dev/null || true
          OUT=""
        fi
      fi
    fi
    ;;
  file://*)
    file="${art#file://}"
    if printf '%s' "$file" | grep -q '%'; then
      if command -v python3 >/dev/null 2>&1; then
        file="$(python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.argv[1]))" "$file")"
      else
        file=$(printf '%b' "${file//%/\\x}")
      fi
    fi
    if [ -f "$file" ]; then
      ext="${file##*.}"
      OUT="$OUT_BASE.$ext"
      if [ ! -f "$OUT" ]; then
        cp -f "$file" "$OUT" 2>/dev/null || true
      fi
    else
      OUT=""
    fi
    ;;
  http*|https*)
    if find_cached >/dev/null 2>&1; then
      OUT="$(find_cached)"
    else
      if command -v curl >/dev/null 2>&1 && curl -sL --fail --max-filesize "$MAX_DOWNLOAD_SIZE" -o "$TMP" "$art"; then
        mimetype=$(file --mime-type -b "$TMP" 2>/dev/null || echo "image/jpeg")
        case "$mimetype" in
          image/png) ext=png;;
          image/webp) ext=webp;;
          image/svg+xml) ext=svg;;
          image/jpeg) ext=jpg;;
          image/*) ext="${mimetype#image/}";;
          *) ext=jpg;;
        esac
        OUT="$OUT_BASE.$ext"
        safe_mv "$TMP" "$OUT"
      else
        rm -f "$TMP" 2>/dev/null || true
        OUT=""
      fi
    fi
    ;;
  *)
    OUT=""
    ;;
esac

# Process image if we have one
if [ -n "${OUT:-}" ] && [ -f "$OUT" ]; then
  # Create square thumbnail
  OUT_SQUARE="${OUT%.*}.square.${SQUARE_SIZE}.png"
  if [ ! -f "$OUT_SQUARE" ]; then
    if command -v convert >/dev/null 2>&1; then
      if convert "$OUT" -auto-orient -background none -resize "${SQUARE_SIZE}x${SQUARE_SIZE}^" -gravity center -extent "${SQUARE_SIZE}x${SQUARE_SIZE}" "$OUT_SQUARE" 2>/dev/null; then
        :
      else
        rm -f "$OUT_SQUARE" 2>/dev/null || true
      fi
    elif command -v ffmpeg >/dev/null 2>&1; then
      if ffmpeg -y -i "$OUT" -vf "scale=w=${SQUARE_SIZE}:h=${SQUARE_SIZE}:force_original_aspect_ratio=decrease,pad=${SQUARE_SIZE}:${SQUARE_SIZE}:(ow-iw)/2:(oh-ih)/2" -vframes 1 "$OUT_SQUARE" >/dev/null 2>&1; then
        :
      else
        rm -f "$OUT_SQUARE" 2>/dev/null || true
      fi
    else
      OUT_SQUARE=""
    fi
  fi

  COLOR_FILE="${OUT_BASE}.color"
  DARK_COLOR_FILE="${OUT_BASE}.darkcolor"

  if [ ! -f "$COLOR_FILE" ]; then
    if [ -n "${OUT_SQUARE:-}" ] && [ -f "$OUT_SQUARE" ]; then
      extract_dominant_color "$OUT_SQUARE" "$COLOR_FILE" || echo "transparent" > "$COLOR_FILE"
    else
      extract_dominant_color "$OUT" "$COLOR_FILE" || echo "transparent" > "$COLOR_FILE"
    fi
  fi

  if [ ! -f "$DARK_COLOR_FILE" ]; then
    if [ -n "${OUT_SQUARE:-}" ] && [ -f "$OUT_SQUARE" ]; then
      extract_dark_area_color "$OUT_SQUARE" "$DARK_COLOR_FILE" || echo "transparent" > "$DARK_COLOR_FILE"
    else
      extract_dark_area_color "$OUT" "$DARK_COLOR_FILE" || echo "transparent" > "$DARK_COLOR_FILE"
    fi
  fi

  if [ -f "$COLOR_FILE" ]; then hover_color=$(cat "$COLOR_FILE"); else hover_color="transparent"; fi
  if [ -f "$DARK_COLOR_FILE" ]; then bg_color=$(cat "$DARK_COLOR_FILE"); else bg_color="transparent"; fi

  update_css "$hover_color" "$bg_color"

  # Output image path (square thumbnail preferred)
  if [ -n "${OUT_SQUARE:-}" ] && [ -f "$OUT_SQUARE" ]; then
    printf '%s' "$OUT_SQUARE"
  else
    printf '%s' "$OUT"
  fi
else
  # No cover - return 1x1 transparent PNG so Waybar clears the image and won't reserve thumbnail space
  ensure_transparent_png
  update_css "transparent" "transparent"
  printf '%s' "$TRANSPARENT_PNG"
fi

exit 0

