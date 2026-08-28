import struct
from pathlib import Path

OUT_DIR = Path("output")
OUT_DIR.mkdir(exist_ok=True)

A_FILE = OUT_DIR / "MinecraftCube_a.3d"
D_FILE = OUT_DIR / "MinecraftCube_d.3d"


def pack_vertex(x, y, z):
    # UE1 FJSMeshVert:
    # X = signed 11 bit
    # Y = signed 11 bit
    # Z = signed 10 bit
    return struct.pack(
        "<I",
        (x & 0x7FF) |
        ((y & 0x7FF) << 11) |
        ((z & 0x3FF) << 22)
    )


# Cube in packed vertex coordinates.
# Z has half the numerical range, compensated by MESHMAP SCALE.
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


# 256x256 texture atlas:
#
#         TOP
#
# LEFT FRONT RIGHT BACK
#
#       BOTTOM
#
# Avoid UV=256 because UV coordinates are bytes: 0..255.

TOP    = (64,   0, 127,  63)
LEFT   = (0,   64,  63, 127)
FRONT  = (64,  64, 127, 127)
RIGHT  = (128, 64, 191, 127)
BACK   = (192, 64, 255, 127)
BOTTOM = (64, 128, 127, 191)


faces = []


def add_quad(a, b, c, d, rect):
    x1, y1, x2, y2 = rect

    uv0 = (x1, y1)
    uv1 = (x2, y1)
    uv2 = (x2, y2)
    uv3 = (x1, y2)

    faces.append((a, b, c, uv0, uv1, uv2))
    faces.append((a, c, d, uv0, uv2, uv3))


# Outward-facing triangles
add_quad(0, 3, 2, 1, BOTTOM)
add_quad(4, 5, 6, 7, TOP)

add_quad(0, 1, 5, 4, FRONT)
add_quad(1, 2, 6, 5, RIGHT)
add_quad(2, 3, 7, 6, BACK)
add_quad(3, 0, 4, 7, LEFT)


# ------------------------------------------------------------
# Animation file: MinecraftCube_a.3d
# ------------------------------------------------------------

with A_FILE.open("wb") as f:
    num_frames = 1
    frame_size = len(vertices) * 4

    # FJSAnivHeader
    f.write(struct.pack("<HH", num_frames, frame_size))

    for x, y, z in vertices:
        f.write(pack_vertex(x, y, z))


# ------------------------------------------------------------
# Data file: MinecraftCube_d.3d
# ------------------------------------------------------------

with D_FILE.open("wb") as f:
    num_polys = len(faces)
    num_vertices = len(vertices)

    # FJSDataHeader as actually serialized by UE1:
    #
    # WORD NumPolys
    # WORD NumVertices
    # WORD BogusRot
    # WORD BogusFrame
    # DWORD BogusNormX
    # DWORD BogusNormY
    # DWORD BogusNormZ
    # DWORD FixScale
    # DWORD Unused1
    # DWORD Unused2
    # DWORD Unused3
    # DWORD MagicMushroom
    # DWORD MagicMushroom
    # DWORD MagicMushroom
    #
    # Total: 48 bytes

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
        # FJSMeshTri = 16 bytes:
        #
        # WORD vertex[3]       6
        # BYTE Type            1
        # BYTE Color           1
        # UV[3]                6
        # BYTE TextureNum      1
        # BYTE Flags           1

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
print(A_FILE, A_FILE.stat().st_size, "bytes")
print(D_FILE, D_FILE.stat().st_size, "bytes")

print()
print("Expected:")
print("_a.3d:", 4 + len(vertices) * 4, "bytes")
print("_d.3d:", 48 + len(faces) * 16, "bytes")