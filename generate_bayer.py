#!/usr/bin/env python3
"""
Generate a tiling 8x8 Bayer dither pattern as a PNG. Used by the Lua fallback
renderer to overlay ordered dithering when native shaders aren't installed.

After running, convert to VTF via generate_vtf.py.
"""

from PIL import Image
import os

# Write into the repo's materials/ directory regardless of where this runs from
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_PNG = os.path.join(SCRIPT_DIR, "materials/ps2_horror/bayer8x8.png")

# Canonical 8x8 Bayer matrix (values 0-63)
BAYER = [
    [ 0, 32,  8, 40,  2, 34, 10, 42],
    [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44,  4, 36, 14, 46,  6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22],
    [ 3, 35, 11, 43,  1, 33,  9, 41],
    [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47,  7, 39, 13, 45,  5, 37],
    [63, 31, 55, 23, 61, 29, 53, 21],
]

# Tile the 8x8 pattern into a 64x64 image so UV wraps neatly
SIZE = 64
img = Image.new('L', (SIZE, SIZE))
pixels = img.load()
for y in range(SIZE):
    for x in range(SIZE):
        v = BAYER[y % 8][x % 8]
        pixels[x, y] = int(v * (255 / 63))  # map 0-63 -> 0-255

os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
img.save(OUT_PNG)
print(f"Wrote Bayer pattern to {OUT_PNG}")
