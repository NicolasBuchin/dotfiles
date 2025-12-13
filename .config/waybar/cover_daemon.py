#!/usr/bin/env python3
import os, io, re, hashlib, subprocess, base64, urllib.parse, sys, signal
from pathlib import Path
import modern_colorthief
from PIL import Image
import requests

SQUARE_SIZE = 64
MAX_DOWNLOAD_SIZE = 1048576
DOWNLOAD_TIMEOUT = 3
CHUNK_SIZE = 8192
CORNER_RADIUS = 6
FADE_START = 0.6

SCRIPT_DIR = Path(__file__).resolve().parent
STYLE_CSS = SCRIPT_DIR / "style.css"

XDG_RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR")
if XDG_RUNTIME_DIR and Path(XDG_RUNTIME_DIR).is_dir():
    CACHE_DIR = Path(XDG_RUNTIME_DIR) / "waybar-mpris-covers"
else:
    CACHE_DIR = Path(f"/tmp/waybar-mpris-covers-{os.getuid()}")
CACHE_DIR.mkdir(parents=True, exist_ok=True)

TRANSPARENT_PNG = CACHE_DIR / "transparent.1x1.png"
CURRENT_COVER = CACHE_DIR / "current_cover.txt"
PID_FILE = CACHE_DIR / "daemon.pid"

def ensure_transparent_png():
    if TRANSPARENT_PNG.exists():
        return
    b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
    TRANSPARENT_PNG.write_bytes(base64.b64decode(b64))

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
    except subprocess.CalledProcessError:
        return ""

def update_css_variables(hover, bg):
    hover_css = hover or "rgba(170,160,120,0.5)"
    bg_css = bg or "transparent"
    if not STYLE_CSS.exists():
        return
    with open(STYLE_CSS, "r", encoding="utf-8") as f:
        text = f.read()
    new_text = re.sub(r"@define-color music-bg .*;", f"@define-color music-bg {bg_css};", text)
    new_text = re.sub(r"@define-color music-hover .*;", f"@define-color music-hover {hover_css};", new_text)
    if new_text != text:
        with open(STYLE_CSS, "w", encoding="utf-8") as f:
            f.write(new_text)

def get_art_url():
    return run(["playerctl", "metadata", "--format", "{{mpris:artUrl}}"])

def hash_str(s):
    return hashlib.md5(s.encode()).hexdigest()

def resize_square(img):
    w, h = img.size
    if w == h == SQUARE_SIZE:
        return img
    scale = SQUARE_SIZE / min(w, h)
    new_size = (int(w*scale+0.5), int(h*scale+0.5))
    img = img.resize(new_size, Image.Resampling.LANCZOS)
    left = (img.width - SQUARE_SIZE)//2
    top = (img.height - SQUARE_SIZE)//2
    return img.crop((left, top, left+SQUARE_SIZE, top+SQUARE_SIZE))

def apply_right_fade(img):
    img = img.convert("RGBA")
    w, h = img.size
    mask = Image.new("L", (w, h))
    mw = w
    half = mw * FADE_START
    denom = (mw - half - 1) if (mw - half - 1) > 0 else 1
    cols = []
    for x in range(mw):
        if x < half:
            a = 255
        else:
            t = (x - half) / denom
            t = min(max(t, 0.0), 1.0)
            a = int(255 * (1.0 - t**2 * (3 - 2*t)))  # smoothstep
            if a < 0:
                a = 0
        cols.append(a)
    mask_pixels = mask.load()
    for x in range(mw):
        col_val = cols[x]
        for y in range(h):
            mask_pixels[x, y] = col_val
    img.putalpha(mask)
    return img

def apply_left_rounded_corners(img, radius=CORNER_RADIUS):
    img = img.convert("RGBA")
    w, h = img.size
    pixels = img.load()
    
    # Round top-left corner
    for y in range(min(radius, h)):
        for x in range(min(radius, w)):
            dx = radius - x
            dy = radius - y
            dist = (dx * dx + dy * dy) ** 0.5
            if dist > radius:
                r, g, b, a = pixels[x, y]
                pixels[x, y] = (r, g, b, 0)
    
    # Round bottom-left corner
    for y in range(max(0, h - radius), h):
        for x in range(min(radius, w)):
            dx = radius - x
            dy = (y - (h - radius - 1))
            dist = (dx * dx + dy * dy) ** 0.5
            if dist > radius:
                r, g, b, a = pixels[x, y]
                pixels[x, y] = (r, g, b, 0)
    
    return img

def save_square_variants(img, out_faded):
    """Resize, apply effects, and save only the faded version"""
    if img.mode not in ('RGB', 'RGBA'):
        img = img.convert('RGBA')
    sq = resize_square(img)
    faded = apply_right_fade(sq.copy())
    faded = apply_left_rounded_corners(faded)
    faded.save(out_faded, 'PNG', optimize=True)
    return sq  # Return the square image for color extraction

def download_and_resize(url, out_faded):
    try:
        response = requests.get(
            url,
            timeout=DOWNLOAD_TIMEOUT,
            stream=True,
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        response.raise_for_status()
        img_data = io.BytesIO()
        total = 0
        for chunk in response.iter_content(CHUNK_SIZE):
            total += len(chunk)
            if total > MAX_DOWNLOAD_SIZE:
                return None
            img_data.write(chunk)
        img_data.seek(0)
        img = Image.open(img_data)
        sq = save_square_variants(img, out_faded)
        return sq
    except:
        return None

def _average_border_color(img):
    """Calculate average border color from PIL Image object"""
    try:
        if img.mode != "RGB":
            img = img.convert("RGB")
    except:
        return None
    w, h = img.size
    pixels = img.load()
    total_r = total_g = total_b = 0
    count = 0
    for x in range(max(0, w-2), w):
        for y in range(h):
            r, g, b = pixels[x, y]
            total_r += r
            total_g += g
            total_b += b
            count += 1
    if count == 0:
        return (0, 0, 0)
    return (
        int(total_r / count),
        int(total_g / count),
        int(total_b / count)
    )

def get_palette_colors(img, color_file):
    """Extract palette colors from PIL Image object"""
    if color_file.exists():
        lines = color_file.read_text().splitlines()
        if len(lines) >= 2:
            return lines[0], lines[1]
    
    # Convert image to bytes for modern_colorthief
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='PNG')
    img_bytes.seek(0)
    
    palette = modern_colorthief.get_palette(img_bytes, 6)
    if not palette:
        palette = [(170,160,120)]
    while len(palette) < 3:
        palette.append(palette[-1])
    
    avg = _average_border_color(img)
    if avg is None:
        avg = (0,0,0)
    
    def dist2(c1, c2):
        return (c1[0]-c2[0])**2 + (c1[1]-c2[1])**2 + (c1[2]-c2[2])**2
    
    bg_idx = min(range(len(palette)), key=lambda i: dist2(avg, palette[i]))
    hover_idx = max(range(len(palette)), key=lambda i: dist2(palette[bg_idx], palette[i]))
    hover_rgb = palette[hover_idx]
    bg_rgb = avg
    
    def rgba(rgb, alpha=1.0): 
        return f"rgba({rgb[0]},{rgb[1]},{rgb[2]},{alpha:.3f})"
    
    hover = rgba(hover_rgb, 1.0)
    bg = rgba(bg_rgb, 1.0)
    color_file.write_text(f"{hover}\n{bg}\n")
    return hover, bg

def handle_local_or_data(art, OUT_SQUARE):
    if art.startswith("data:"):
        if ";base64," in art:
            payload = art.split(",", 1)[1]
            img_data = io.BytesIO(base64.b64decode(payload))
            try:
                img = Image.open(img_data)
                sq = save_square_variants(img, OUT_SQUARE)
                return sq
            except:
                return False
        return False
    if art.startswith("file://"):
        file = urllib.parse.unquote(art[7:])
        if os.path.isfile(file):
            try:
                img = Image.open(file)
                sq = save_square_variants(img, OUT_SQUARE)
                return sq
            except:
                pass
        return False
    return None

def process_cover(art):
    # If no art URL provided, keep the current cover (don't change anything)
    if not art:
        return
    
    key = hash_str(art)
    OUT_BASE = CACHE_DIR / key
    OUT_SQUARE = OUT_BASE.with_suffix(f".square.{SQUARE_SIZE}.png")
    color_file = OUT_BASE.with_suffix(".colors")
    
    # Check if processed image and colors already exist
    if OUT_SQUARE.exists() and color_file.exists():
        lines = color_file.read_text().splitlines()
        if len(lines) >= 2:
            update_css_variables(lines[0], lines[1])
            CURRENT_COVER.write_text(str(OUT_SQUARE))
            return
    
    # Process new image
    result = handle_local_or_data(art, OUT_SQUARE)
    if isinstance(result, Image.Image):
        hover, bg = get_palette_colors(result, color_file)
        update_css_variables(hover, bg)
        CURRENT_COVER.write_text(str(OUT_SQUARE))
        return
    if result is False:
        # Failed to process local/data URI - keep previous cover
        return
    
    # Try HTTP download
    if art.startswith("http"):
        sq = download_and_resize(art, OUT_SQUARE)
        if sq:
            hover, bg = get_palette_colors(sq, color_file)
            update_css_variables(hover, bg)
            CURRENT_COVER.write_text(str(OUT_SQUARE))
            return
    
    # If all processing failed, keep the previous cover (don't change anything)

def signal_waybar():
    try:
        subprocess.run(["pkill", "-RTMIN+5", "waybar"], stderr=subprocess.DEVNULL, timeout=1)
    except:
        pass

def main():
    PID_FILE.write_text(str(os.getpid()))
    
    # On initial startup, only process if we have art
    art = get_art_url()
    if art:
        process_cover(art)
    elif not CURRENT_COVER.exists():
        # Only set transparent if there's no previous cover at all
        ensure_transparent_png()
        update_css_variables("transparent", "transparent")
        CURRENT_COVER.write_text(str(TRANSPARENT_PNG))
    
    signal_waybar()
    try:
        proc = subprocess.Popen(
            ["playerctl", "--follow", "metadata", "--format", "{{playerName}}|{{status}}|{{mpris:artUrl}}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1
        )
        last_art = art
        last_line = ""
        for line in proc.stdout:
            line = line.strip()
            if line != last_line:
                last_line = line
                parts = line.split("|")
                if len(parts) < 3:
                    continue
                art_url = parts[2]
                if art_url != last_art:
                    last_art = art_url
                    process_cover(art_url)
                signal_waybar()
    except KeyboardInterrupt:
        pass
    finally:
        if PID_FILE.exists():
            PID_FILE.unlink()

if __name__ == "__main__":
    main()
