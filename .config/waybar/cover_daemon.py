#!/usr/bin/env python3
"""Background daemon that monitors playerctl and updates cover/colors"""
import os, io, re, hashlib, subprocess, base64, urllib.parse, sys, signal
from pathlib import Path
import modern_colorthief
from PIL import Image
import requests

SQUARE_SIZE = 18
MAX_DOWNLOAD_SIZE = 1048576
DOWNLOAD_TIMEOUT = 3
CHUNK_SIZE = 8192

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

def try_get_smaller_url(url):
    if "i.scdn.co" in url:
        url = re.sub(r'/\d+x\d+/', '/64x64/', url)
        return url
    if "googleusercontent.com" in url or "ytimg.com" in url:
        if "=s" not in url:
            url = f"{url}=s64"
        else:
            url = re.sub(r'=s\d+', '=s64', url)
        return url
    if "lastfm" in url:
        url = re.sub(r'/\d+s/', '/64s/', url)
        return url
    return url

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

def download_and_resize_direct(url, out_path):
    try:
        url = try_get_smaller_url(url)
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
        if img.mode not in ('RGB', 'RGBA'):
            img = img.convert('RGBA')
        img = resize_square(img)
        img.save(out_path, 'PNG', optimize=True)
        return out_path
    except:
        return None

def _average_border_color(path):
    try:
        img = Image.open(path).convert("RGBA")
    except:
        return None
    w, h = img.size
    bw = max(1, min(w, h)//6)
    pixels = img.load()
    total_r = total_g = total_b = total_a = 0
    count = 0
    for y in range(h):
        for x in range(w):
            if x < bw or x >= w-bw or y < bw or y >= h-bw:
                r,g,b,a = pixels[x,y]
                if a == 0:
                    continue
                total_r += r * a
                total_g += g * a
                total_b += b * a
                total_a += a
                count += 1
    if total_a == 0 or count == 0:
        img2 = img.convert("RGB")
        pixels2 = img2.load()
        total_r = total_g = total_b = 0
        count = 0
        for y in range(h):
            for x in range(w):
                r,g,b = pixels2[x,y]
                total_r += r
                total_g += g
                total_b += b
                count += 1
        if count == 0:
            return (0,0,0)
        return (int(total_r/count), int(total_g/count), int(total_b/count))
    r = int(total_r/total_a)
    g = int(total_g/total_a)
    b = int(total_b/total_a)
    return (r,g,b)

def get_palette_colors(path, color_file):
    if color_file.exists():
        lines = color_file.read_text().splitlines()
        if len(lines) >= 2:
            return lines[0], lines[1]
    with open(path, "rb") as f:
        image_bytes = io.BytesIO(f.read())
    palette = modern_colorthief.get_palette(image_bytes, 3)
    if not palette:
        palette = [(170,160,120)]
    while len(palette) < 3:
        palette.append(palette[-1])
    avg = _average_border_color(path)
    if avg is None:
        avg = (0,0,0)
    def dist2(c1, c2):
        return (c1[0]-c2[0])**2 + (c1[1]-c2[1])**2 + (c1[2]-c2[2])**2
    bg_idx = min(range(len(palette)), key=lambda i: dist2(avg, palette[i]))
    hover_idx = max(range(len(palette)), key=lambda i: dist2(palette[bg_idx], palette[i]))
    hover_rgb = palette[hover_idx]
    bg_rgb = palette[bg_idx]
    def rgba(rgb, alpha=1.0): return f"rgba({rgb[0]},{rgb[1]},{rgb[2]},{alpha:.3f})"
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
                if img.mode not in ('RGB', 'RGBA'):
                    img = img.convert('RGBA')
                img = resize_square(img)
                img.save(OUT_SQUARE, 'PNG', optimize=True)
                return True
            except:
                return False
        return False
    if art.startswith("file://"):
        file = urllib.parse.unquote(art[7:])
        if os.path.isfile(file):
            try:
                img = Image.open(file)
                if img.mode not in ('RGB', 'RGBA'):
                    img = img.convert('RGBA')
                img = resize_square(img)
                img.save(OUT_SQUARE, 'PNG', optimize=True)
                return True
            except:
                pass
        return False
    return None

def process_cover():
    """Process current cover and update cache"""
    art = get_art_url()
    if not art:
        ensure_transparent_png()
        update_css_variables("transparent", "transparent")
        CURRENT_COVER.write_text(str(TRANSPARENT_PNG))
        return
    
    key = hash_str(art)
    OUT_BASE = CACHE_DIR / key
    OUT_SQUARE = OUT_BASE.with_suffix(f".square.{SQUARE_SIZE}.png")
    color_file = OUT_BASE.with_suffix(".colors")
    
    if OUT_SQUARE.exists():
        hover, bg = get_palette_colors(OUT_SQUARE, color_file)
        update_css_variables(hover, bg)
        CURRENT_COVER.write_text(str(OUT_SQUARE))
        return
    
    res_local = handle_local_or_data(art, OUT_SQUARE)
    if res_local is True:
        hover, bg = get_palette_colors(OUT_SQUARE, color_file)
        update_css_variables(hover, bg)
        CURRENT_COVER.write_text(str(OUT_SQUARE))
        return
    if res_local is False:
        ensure_transparent_png()
        update_css_variables("transparent", "transparent")
        CURRENT_COVER.write_text(str(TRANSPARENT_PNG))
        return
    
    if art.startswith("http"):
        if download_and_resize_direct(art, OUT_SQUARE):
            hover, bg = get_palette_colors(OUT_SQUARE, color_file)
            update_css_variables(hover, bg)
            CURRENT_COVER.write_text(str(OUT_SQUARE))
            return
    
    ensure_transparent_png()
    update_css_variables("transparent", "transparent")
    CURRENT_COVER.write_text(str(TRANSPARENT_PNG))

def signal_waybar():
    """Send signal to waybar to refresh"""
    try:
        subprocess.run(["pkill", "-RTMIN+5", "waybar"], 
                      stderr=subprocess.DEVNULL, timeout=1)
    except:
        pass

def main():
    # Write PID file
    PID_FILE.write_text(str(os.getpid()))
    
    # Initial process
    process_cover()
    signal_waybar()
    
    # Monitor playerctl for changes
    try:
        proc = subprocess.Popen(
            ["playerctl", "metadata", "--follow", "--format", "{{mpris:artUrl}}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1
        )
        
        last_art = None
        for line in proc.stdout:
            art = line.strip()
            if art != last_art:
                last_art = art
                process_cover()
                signal_waybar()
    except KeyboardInterrupt:
        pass
    finally:
        if PID_FILE.exists():
            PID_FILE.unlink()

if __name__ == "__main__":
    main()
