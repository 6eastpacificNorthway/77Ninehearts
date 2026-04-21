#!/usr/bin/env python3
"""
Write a minimal VTF 7.2 file for our Bayer pattern.
Format: BGRA8888 (easiest, no DXT compression needed for 64x64).

VTF 7.2 header layout (80 bytes):
  0x00  'VTF\0'            magic
  0x04  uint32[2]          version (7, 2)
  0x0C  uint32             header_size (80)
  0x10  uint16 width
  0x12  uint16 height
  0x14  uint32 flags
  0x18  uint16 frames
  0x1A  uint16 first_frame
  0x1C  padding[4]
  0x20  float[3]           reflectivity
  0x2C  padding[4]
  0x30  float              bumpmap_scale
  0x34  uint32             high_res_image_format (IMAGE_FORMAT_BGRA8888 = 1... actually 1 is ABGR8888; BGRA8888 is 12, RGBA8888 is 0, let me use BGRA8888 code 12)
  0x38  uint8              mipmap_count (1)
  0x39  uint32             low_res_image_format (0xFFFFFFFF = none)
  0x3D  uint8              low_res_width (0)
  0x3E  uint8              low_res_height (0)
  0x3F  uint16             depth (1)

Actually the format IDs per Valve docs:
  IMAGE_FORMAT_NONE = -1
  IMAGE_FORMAT_RGBA8888 = 0
  IMAGE_FORMAT_ABGR8888 = 1
  IMAGE_FORMAT_RGB888 = 2
  IMAGE_FORMAT_BGR888 = 3
  IMAGE_FORMAT_RGB565 = 4
  IMAGE_FORMAT_I8 = 5
  IMAGE_FORMAT_IA88 = 6
  IMAGE_FORMAT_P8 = 7
  IMAGE_FORMAT_A8 = 8
  ...
  IMAGE_FORMAT_BGRA8888 = 12

We'll use IMAGE_FORMAT_BGRA8888 (12) since it's the safest and always supported.
"""

import struct
import os
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
IN_PNG = os.path.join(SCRIPT_DIR, "materials/ps2_horror/bayer8x8.png")
OUT_VTF = os.path.join(SCRIPT_DIR, "materials/ps2_horror/bayer8x8.vtf")

def write_vtf(in_png, out_vtf):
    img = Image.open(in_png).convert("RGBA")
    w, h = img.size

    # Swizzle RGBA -> BGRA
    r, g, b, a = img.split()
    bgra = Image.merge("RGBA", (b, g, r, a))
    pixel_data = bgra.tobytes()

    header_size = 80

    # VTF flags: TEXTUREFLAGS_NOMIP = 0x100, TEXTUREFLAGS_NOLOD = 0x200, TEXTUREFLAGS_CLAMPS/T = 0x4/0x8
    # We want tiling so skip CLAMPS/T. Add POINTSAMPLE = 0x1000 for crisp dither
    flags = 0x100 | 0x200 | 0x1000

    header = bytearray(header_size)
    header[0:4] = b"VTF\x00"
    struct.pack_into("<II", header, 4, 7, 2)      # version 7.2
    struct.pack_into("<I",  header, 12, header_size)
    struct.pack_into("<HH", header, 16, w, h)
    struct.pack_into("<I",  header, 20, flags)
    struct.pack_into("<HH", header, 24, 1, 0)     # frames, first_frame
    struct.pack_into("<fff", header, 32, 1.0, 1.0, 1.0)  # reflectivity
    struct.pack_into("<f",  header, 48, 1.0)      # bumpmap scale
    struct.pack_into("<I",  header, 52, 12)       # BGRA8888
    struct.pack_into("<B",  header, 56, 1)        # mipmap count
    struct.pack_into("<I",  header, 57, 0xFFFFFFFF)  # low res format = none
    struct.pack_into("<BB", header, 61, 0, 0)     # low res w/h
    struct.pack_into("<H",  header, 63, 1)        # depth

    with open(out_vtf, "wb") as f:
        f.write(header)
        f.write(pixel_data)

    print(f"Wrote VTF {w}x{h} BGRA8888 to {out_vtf} ({len(header) + len(pixel_data)} bytes)")

write_vtf(IN_PNG, OUT_VTF)
