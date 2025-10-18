#!/usr/bin/env python3
"""Simple script to output the current cover path"""
import os
from pathlib import Path

XDG_RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR")
if XDG_RUNTIME_DIR and Path(XDG_RUNTIME_DIR).is_dir():
    CACHE_DIR = Path(XDG_RUNTIME_DIR) / "waybar-mpris-covers"
else:
    CACHE_DIR = Path(f"/tmp/waybar-mpris-covers-{os.getuid()}")

CURRENT_COVER = CACHE_DIR / "current_cover.txt"
TRANSPARENT_PNG = CACHE_DIR / "transparent.1x1.png"

def main():
    if CURRENT_COVER.exists():
        cover_path = CURRENT_COVER.read_text().strip()
        if Path(cover_path).exists():
            print(cover_path)
            return
    
    # Fallback
    if TRANSPARENT_PNG.exists():
        print(TRANSPARENT_PNG)
    else:
        print("")

if __name__ == "__main__":
    main()
