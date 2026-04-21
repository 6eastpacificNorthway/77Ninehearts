#!/usr/bin/env python3
"""
Generate a Source Engine .raw color correction LUT tuned to Haunting Ground's palette.
Characteristics:
  - Crushed blacks with cyan push in shadows
  - Desaturated midtones
  - Warm, slightly crushed highlights
  - Overall reduced saturation (~65%)
  - Slight green-cyan bias in midtones (that musty stone look)
Output: materials/correction/ps2_horror.raw (32x32x32 cube, 98304 bytes)
"""

import struct
import os
import math

LUT_SIZE = 32
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(SCRIPT_DIR, "materials/correction/ps2_horror.raw")

def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))

def srgb_to_linear(c):
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4

def linear_to_srgb(c):
    if c <= 0.0031308:
        return c * 12.92
    return 1.055 * (c ** (1/2.4)) - 0.055

def grade(r, g, b):
    """Apply Haunting Ground color grade to an input RGB triplet (0-1).

    Matches the master shader's grading order (v2 corrected):
    desaturate -> contrast -> brightness -> shadow/highlight tint split.
    Applying tint AFTER contrast means dark pixels retain their cyan shift
    instead of being crushed to pure black first.
    """
    # Work in linear space for the shadow/highlight splits
    lr, lg, lb = srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)

    # Luminance (Rec.709)
    lum = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb

    # 1. Desaturate toward luminance
    sat_keep = 0.45
    lr = lum + (lr - lum) * sat_keep
    lg = lum + (lg - lum) * sat_keep
    lb = lum + (lb - lum) * sat_keep

    # 2. Contrast around mid-gray (FIRST, so dark pixels aren't crushed before tinting)
    mid = 0.18  # 18% gray in linear space
    contrast = 1.18
    lr = mid + (lr - mid) * contrast
    lg = mid + (lg - mid) * contrast
    lb = mid + (lb - mid) * contrast

    # 3. Overall slight darken
    lr *= 0.95
    lg *= 0.95
    lb *= 0.97

    # 4. Shadow/midtone/highlight split (after contrast, luma recomputed)
    lum2 = 0.2126 * clamp(lr) + 0.7152 * clamp(lg) + 0.0722 * clamp(lb)
    shadow_w = clamp(1.0 - lum2 * 2.2) ** 2
    highlight_w = clamp((lum2 - 0.55) * 2.2) ** 2
    mid_w = 1.0 - shadow_w - highlight_w

    # Shadows: cyan push
    lr += shadow_w * -0.03
    lg += shadow_w * 0.015
    lb += shadow_w * 0.055

    # Midtones: slight green-cyan (musty stone) — unique to LUT, shader doesn't do this
    lr += mid_w * -0.015
    lg += mid_w * 0.01
    lb += mid_w * 0.02

    # Highlights: warm, slightly crushed
    lr += highlight_w * 0.04
    lg += highlight_w * 0.02
    lb += highlight_w * -0.03

    # 5. Gentle black lift/crush
    lr = clamp(lr - 0.01)
    lg = clamp(lg - 0.01)
    lb = clamp(lb - 0.005)

    # Back to sRGB
    r2 = clamp(linear_to_srgb(clamp(lr)))
    g2 = clamp(linear_to_srgb(clamp(lg)))
    b2 = clamp(linear_to_srgb(clamp(lb)))

    return r2, g2, b2

def main():
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)

    # Source Engine .raw LUT format:
    # 32*32*32 RGB triplets, uint8 each, stored as B-major
    # Layout: for b in 0..31: for g in 0..31: for r in 0..31: write RGB
    data = bytearray()
    for b_idx in range(LUT_SIZE):
        for g_idx in range(LUT_SIZE):
            for r_idx in range(LUT_SIZE):
                r = r_idx / (LUT_SIZE - 1)
                g = g_idx / (LUT_SIZE - 1)
                b = b_idx / (LUT_SIZE - 1)

                nr, ng, nb = grade(r, g, b)

                data.append(int(round(nr * 255)))
                data.append(int(round(ng * 255)))
                data.append(int(round(nb * 255)))

    with open(OUT_PATH, "wb") as f:
        f.write(data)

    print(f"Wrote {len(data)} bytes to {OUT_PATH}")
    expected = LUT_SIZE ** 3 * 3
    assert len(data) == expected, f"Expected {expected} bytes, got {len(data)}"

if __name__ == "__main__":
    main()
