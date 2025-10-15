#!/usr/bin/env python3
"""
Script to replace hex colors in a YML file with the closest Nord palette colors.
Creates a backup before modifying the file.
"""

import re
import shutil
from pathlib import Path
from datetime import datetime
from typing import Tuple, List
import sys

# Nordic color palette
NORD_PALETTE = {
    'black0': '#191D24',
    'black1': '#1E222A',
    'black2': '#222630',
    'gray0': '#242933',
    'gray1': '#2E3440',
    'gray2': '#3B4252',
    'gray3': '#434C5E',
    'gray4': '#8D9096',
    'gray5': '#60728A',
    'white0_normal': '#BBC3D4',
    'white0_reduce_blue': '#C0C8D8',
    'white1': '#D8DEE9',
    'white2': '#E5E9F0',
    'white3': '#ECEFF4',
    'blue0': '#5E81AC',
    'blue1': '#81A1C1',
    'blue2': '#88C0D0',
    'cyan_base': '#8FBCBB',
    'cyan_bright': '#9FC6C5',
    'cyan_dim': '#80B3B2',
    'red_base': '#BF616A',
    'red_bright': '#C5727A',
    'red_dim': '#B74E58',
    'orange_base': '#D08770',
    'orange_bright': '#D79784',
    'orange_dim': '#CB775D',
    'yellow_base': '#EBCB8B',
    'yellow_bright': '#EFD49F',
    'yellow_dim': '#E7C173',
    'green_base': '#A3BE8C',
    'green_bright': '#B1C89D',
    'green_dim': '#97B67C',
    'magenta_base': '#B48EAD',
    'magenta_bright': '#BE9DB8',
    'magenta_dim': '#A97EA1',
}


def hex_to_rgb(hex_color: str) -> Tuple[int, int, int]:
    """Convert hex color to RGB tuple."""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))


def color_distance(color1: Tuple[int, int, int], color2: Tuple[int, int, int]) -> float:
    """Calculate Euclidean distance between two RGB colors."""
    return sum((a - b) ** 2 for a, b in zip(color1, color2)) ** 0.5


def find_closest_nord_color(hex_color: str) -> str:
    """Find the closest Nord palette color to the given hex color."""
    target_rgb = hex_to_rgb(hex_color)
    
    closest_color = None
    min_distance = float('inf')
    
    for color_hex in NORD_PALETTE.values():
        palette_rgb = hex_to_rgb(color_hex)
        distance = color_distance(target_rgb, palette_rgb)
        
        if distance < min_distance:
            min_distance = distance
            closest_color = color_hex
    
    return closest_color


def create_backup(file_path: Path) -> Path:
    """Create a backup of the file with timestamp."""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = file_path.with_suffix(f'.backup_{timestamp}{file_path.suffix}')
    shutil.copy2(file_path, backup_path)
    print(f"✓ Backup created: {backup_path}")
    return backup_path


def replace_colors_in_file(file_path: Path, dry_run: bool = False) -> None:
    """Replace hex colors in the file with closest Nord colors."""
    # Regex to match hex colors (with or without #, 3 or 6 digits)
    # Matches: #ABC, #AABBCC, ABC, AABBCC (case insensitive)
    hex_pattern = re.compile(r'#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})(?=\s|$|"|\'|,|;|}|])')
    
    # Read the file
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    replacements = []
    
    def replace_match(match):
        hex_color = match.group(1)
        
        # Expand 3-digit hex to 6-digit
        if len(hex_color) == 3:
            hex_color = ''.join([c*2 for c in hex_color])
        
        # Normalize to uppercase with #
        normalized = f'#{hex_color.upper()}'
        
        # Find closest Nord color
        closest = find_closest_nord_color(normalized)
        
        # Track replacement
        if normalized != closest:
            replacements.append((normalized, closest))
        
        # Return with the original prefix (# or not)
        if match.group(0).startswith('#'):
            return closest
        else:
            return closest.lstrip('#')
    
    # Replace all hex colors
    new_content = hex_pattern.sub(replace_match, content)
    
    # Print summary
    if replacements:
        print(f"\n{'DRY RUN - ' if dry_run else ''}Replacements made:")
        unique_replacements = list(set(replacements))
        for old, new in sorted(unique_replacements):
            print(f"  {old} → {new}")
        print(f"\nTotal: {len(replacements)} replacements ({len(unique_replacements)} unique)")
    else:
        print("\nNo colors needed replacement (all already match Nord palette)")
    
    # Write back to file (unless dry run)
    if not dry_run:
        if replacements:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"\n✓ File updated: {file_path}")
        else:
            print(f"\n✓ No changes needed for: {file_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python script.py <yml_file_path> [--dry-run]")
        print("\nOptions:")
        print("  --dry-run    Show what would be changed without modifying the file")
        sys.exit(1)
    
    file_path = Path(sys.argv[1])
    dry_run = '--dry-run' in sys.argv
    
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)
    
    print(f"Processing: {file_path}")
    print(f"Nord palette colors loaded: {len(NORD_PALETTE)}")
    
    if not dry_run:
        create_backup(file_path)
    else:
        print("\n*** DRY RUN MODE - No files will be modified ***\n")
    
    replace_colors_in_file(file_path, dry_run)


if __name__ == '__main__':
    main()
