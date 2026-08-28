#!/usr/bin/env python3
r"""
Generate a corrected UT99/UE1 cube mesh for the MinecraftBlocks project.

This version fixes:
- side faces upright instead of upside down
- the face directly in front of you when summoned is FRONT
- top and bottom are oriented consistently relative to the side faces

Outputs:
    MinecraftCube_a.3d
    MinecraftCube_d.3d

Place this script in your MinecraftBlocks folder and run it.
Then copy/overwrite the files into your MODELS folder and re-run ucc make.

Expected UnrealScript usage afterwards:

#exec MESH IMPORT MESH=MinecraftCube ANIVFILE=MODELS\MinecraftCube_a.3D DATAFILE=MODELS\MinecraftCube_d.3D X=0 Y=0 Z=0
#exec MESH ORIGIN MESH=MinecraftCube X=0 Y=0 Z=0
#exec MESH SEQUENCE MESH=MinecraftCube SEQ=All STARTFRAME=0 NUMFRAMES=1
#exec MESH SEQUENCE MESH=MinecraftCube SEQ=Still STARTFRAME=0 NUMFRAMES=1
#exec MESHMAP SCALE MESHMAP=MinecraftCube X=0.125 Y=0.125 Z=0.250

No texture regeneration is needed; this only fixes the cube UV mapping.
"""

from __future__ import annotations

import struct
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
OUT_A = BASE_DIR / "MinecraftCube_a.3d"
OUT_D = BASE_DIR / "MinecraftCube_d.3d"


def pack_vertex(x: int, y: int, z: int) -> bytes:
    # UE1 packed mesh vertex:
    # X = signed 11 bits
    # Y = signed 11 bits
    # Z = signed 10 bits
    packed = (
        (x & 0x7FF) |
        ((y & 0x7FF) << 11) |
        ((z & 0x3FF) << 22)
    )
    return struct.pack("<I", packed)


# Same geometry as before:
# X/Y use ±256, Z uses ±128; MESHMAP SCALE compensates to a perfect cube.
vertices = [
    (-256, -256, -128),  # 0
    ( 256, -256, -128),  # 1
    ( 256,  256, -128),  # 2
    (-256,  256, -128),  # 3
    (-256, -256,  128),  # 4
    ( 256, -256,  128),  # 5
    ( 256,  256,  128),  # 6
    (-256,  256,  128),  # 7
]

# 256x256 atlas:
#
#         TOP
#
# LEFT  FRONT  RIGHT  BACK
#
#       BOTTOM
#
# Use 0..255 UV bytes only.
TOP    = (64,   0, 127,  63)
LEFT   = (0,   64,  63, 127)
FRONT  = (64,  64, 127, 127)
RIGHT  = (128, 64, 191, 127)
BACK   = (192, 64, 255, 127)
BOTTOM = (64, 128, 127, 191)

faces = []


def rect_corners(rect):
    x1, y1, x2, y2 = rect
    return {
        "TL": (x1, y1),
        "TR": (x2, y1),
        "BR": (x2, y2),
        "BL": (x1, y2),
    }


def add_quad(a, b, c, d, rect, corner_names):
    """
    Add a quad as two triangles.

    a,b,c,d are the quad vertices in polygon order.
    corner_names is a 4-item tuple telling which atlas corner belongs to
    each of a,b,c,d. Example:
        ("BR", "BL", "TL", "TR")
    """
    rc = rect_corners(rect)
    uv_a = rc[corner_names[0]]
    uv_b = rc[corner_names[1]]
    uv_c = rc[corner_names[2]]
    uv_d = rc[corner_names[3]]

    faces.append((a, b, c, uv_a, uv_b, uv_c))
    faces.append((a, c, d, uv_a, uv_c, uv_d))


# ----------------------------------------------------------------------
# Corrected face mapping
#
# Observed in-game from the debug cube:
# - the side directly in front when summoned corresponds to the old "left"
#   polygon, so we map FRONT there
# - side faces were upside down, so their UV corner order is corrected
# - top and bottom get a consistent orientation relative to the sides
# ----------------------------------------------------------------------

# TOP face:
# visible from above, with FRONT at the near edge and BACK at the far edge.
# For polygon order 4,5,6,7 the right mapping is BL,TL,TR,BR.
add_quad(4, 5, 6, 7, TOP, ("BL", "TL", "TR", "BR"))

# BOTTOM face:
# consistent world direction relative to TOP.
# For polygon order 0,3,2,1 the right mapping is BL,BR,TR,TL.
add_quad(0, 3, 2, 1, BOTTOM, ("BL", "BR", "TR", "TL"))

# SIDE faces:
# All side faces use the same corrected upright corner mapping:
# for polygon order a,b,c,d -> BR,BL,TL,TR.
SIDE_MAP = ("BR", "BL", "TL", "TR")

# Actual FRONT face when summoned
add_quad(3, 0, 4, 7, FRONT, SIDE_MAP)

# Actual RIGHT face
add_quad(2, 3, 7, 6, RIGHT, SIDE_MAP)

# Actual BACK face
add_quad(1, 2, 6, 5, BACK, SIDE_MAP)

# Actual LEFT face
add_quad(0, 1, 5, 4, LEFT, SIDE_MAP)


# ------------------------------------------------------------
# Write MinecraftCube_a.3d
# ------------------------------------------------------------
with OUT_A.open("wb") as f:
    num_frames = 1
    frame_size = len(vertices) * 4
    f.write(struct.pack("<HH", num_frames, frame_size))

    for x, y, z in vertices:
        f.write(pack_vertex(x, y, z))


# ------------------------------------------------------------
# Write MinecraftCube_d.3d
# ------------------------------------------------------------
with OUT_D.open("wb") as f:
    num_polys = len(faces)
    num_vertices = len(vertices)

    # FJSDataHeader, 48 bytes
    f.write(struct.pack(
        "<HHHHIIIIIIIIII",
        num_polys,
        num_vertices,
        0,  # BogusRot
        0,  # BogusFrame
        0,  # BogusNormX
        0,  # BogusNormY
        0,  # BogusNormZ
        0,  # FixScale
        0,  # Unused1
        0,  # Unused2
        0,  # Unused3
        0,  # MagicMushroom
        0,  # MagicMushroom
        0   # MagicMushroom
    ))

    for a, b, c, uv0, uv1, uv2 in faces:
        poly_type = 0
        color = 0
        texture_num = 0
        flags = 0

        f.write(struct.pack(
            "<HHHBBBBBBBBBB",
            a, b, c,
            poly_type,
            color,
            uv0[0], uv0[1],
            uv1[0], uv1[1],
            uv2[0], uv2[1],
            texture_num,
            flags
        ))

print("Generated:")
print(OUT_A)
print(OUT_D)
print()
print("Expected sizes:")
print("  MinecraftCube_a.3d =", OUT_A.stat().st_size, "bytes")
print("  MinecraftCube_d.3d =", OUT_D.stat().st_size, "bytes")
print()
print("Now overwrite the files in your MODELS folder and run ucc make.")
