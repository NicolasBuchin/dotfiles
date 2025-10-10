#!/usr/bin/env bash
# cover.sh - robust album-art fetcher + square-cropper for Waybar
# Optimized version: Updates CSS variables inline in style.css instead of separate file

set -euo pipefail

# --- configuration ---
SQUARE_SIZE=32            
MAX_DOWNLOAD_SIZE=1048576 
STALE_DAYS=7              
# ----------------------

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
STYLE_CSS="$SCRIPT_DIR/style.css"

# Prefer XDG_RUNTIME_DIR
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
  CACHE_DIR="$XDG_RUNTIME_DIR/waybar-mpris-covers"
  RUNTIME_BACKED=1
else
  CACHE_DIR="/tmp/waybar-mpris-covers-$UID"
  RUNTIME_BACKED=0
fi

mkdir -p "$CACHE_DIR"

TRANSPARENT_SIZE=1
TRANSPARENT_PNG="$CACHE_DIR/transparent.${TRANSPARENT_SIZE}x${TRANSPARENT_SIZE}.png"

ensure_transparent_png() {
  if [ -f "$TRANSPARENT_PNG" ]; then
    return 0
  fi
  if command -v magick >/dev/null 2>&1; then
    magick -size "${TRANSPARENT_SIZE}x${TRANSPARENT_SIZE}" xc:none "$TRANSPARENT_PNG" 2>/dev/null || true
  elif command -v convert >/dev/null 2>&1; then
    convert -size "${TRANSPARENT_SIZE}x${TRANSPARENT_SIZE}" xc:none "$TRANSPARENT_PNG" 2>/dev/null || true
  else
    tmp_b64="${CACHE_DIR}/transparent.b64.$$"
    cat > "$tmp_b64" <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=
B64
    if command -v base64 >/dev/null 2>&1; then
      base64 --decode "$tmp_b64" > "$TRANSPARENT_PNG" 2>/dev/null || true
    else
      perl -MMIME::Base64 -e 'print decode_base64(join("", <>))' "$tmp_b64" > "$TRANSPARENT_PNG" 2>/dev/null || true
    fi
    rm -f "$tmp_b64" 2>/dev/null || true
  fi

  if [ ! -f "$TRANSPARENT_PNG" ]; then
    : > "$TRANSPARENT_PNG"
  fi
}

if [ "$RUNTIME_BACKED" -eq 0 ]; then
  if command -v find >/dev/null 2>&1; then
    find "$CACHE_DIR" -mindepth 1 -type f -mtime +"$STALE_DAYS" -delete 2>/dev/null || true
  fi
fi

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
      df = 0.85;
      r = int(r*df + 0.5); g = int(g*df + 0.5); b = int(b*df + 0.5);
      printf("rgba(%d,%d,%d,1.0)\n", r, g, b);
    }
  ' "$sorted" > "$out" || { echo "transparent" > "$out"; return 1; }

  return 0
}

# NEW: Update CSS variables inline in style.css
update_css_variables() {
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

  # Use sed to update the CSS variables in place
  # This is much faster than @import as it doesn't trigger a full reload
  sed -i \
    -e "s|@define-color music-bg .*|@define-color music-bg $bg_css;|" \
    -e "s|@define-color music-hover .*|@define-color music-hover $hover_css;|" \
    "$STYLE_CSS" 2>/dev/null || true
}

player=$(playerctl metadata --format '{{playerName}}' 2>/dev/null || true)
if [ -z "$player" ]; then
  ensure_transparent_png
  update_css_variables "transparent" "transparent"
  printf '%s' "$TRANSPARENT_PNG"
  exit 0
fi

art=$(playerctl metadata --format '{{mpris:artUrl}}' 2>/dev/null || true)
if [ -z "$art" ]; then
  ensure_transparent_png
  update_css_variables "transparent" "transparent"
  printf '%s' "$TRANSPARENT_PNG"
  exit 0
fi

hash=$(printf '%s' "$art" | md5sum | awk '{print $1}')
OUT_BASE="$CACHE_DIR/$hash"

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

if [ -n "${OUT:-}" ] && [ -f "$OUT" ]; then
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

  update_css_variables "$hover_color" "$bg_color"

  if [ -n "${OUT_SQUARE:-}" ] && [ -f "$OUT_SQUARE" ]; then
    printf '%s' "$OUT_SQUARE"
  else
    printf '%s' "$OUT"
  fi
else
  ensure_transparent_png
  update_css_variables "transparent" "transparent"
  printf '%s' "$TRANSPARENT_PNG"
fi

exit 0
