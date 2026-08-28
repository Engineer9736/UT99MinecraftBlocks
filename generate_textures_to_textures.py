#!/usr/bin/env python3
"""
Generate UT99-ready 256x256 PCX texture atlases from Minecraft 1.12.2 block textures.

Expected project layout:

    MinecraftBlocks\
        generate_textures.py
        texturemap.json
        MinecraftTextures\
            stone.png
            grass_top.png
            ...
        Textures\               <- PCX output goes here
        GeneratedPreviews\      <- created automatically
        generated_manifest.json <- created automatically

Requires:
    pip install pillow

The cube UV atlas layout is:

             TOP
    LEFT   FRONT   RIGHT   BACK
            BOTTOM

Each face occupies 64x64 pixels inside a 256x256 texture.
Minecraft's 16x16 textures are enlarged with nearest-neighbour filtering.

Transparent pixels are converted to palette index 0. This makes the generated
PCX suitable for UT99 masked textures later. The manifest records which blocks
contained transparency.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Dict, Any

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow is required. Install it with:")
    print("       py -m pip install pillow")
    raise SystemExit(1)


BASE_DIR = Path(__file__).resolve().parent
TEXTURE_MAP_FILE = BASE_DIR / "texturemap.json"
SOURCE_DIR = BASE_DIR / "MinecraftTextures"
OUTPUT_DIR = BASE_DIR / "Textures"
PREVIEW_DIR = BASE_DIR / "GeneratedPreviews"
MANIFEST_FILE = BASE_DIR / "generated_manifest.json"

FACE_SIZE = 64
ATLAS_SIZE = 256

# UV regions used by our MinecraftCube mesh.
ATLAS_POSITIONS = {
    "top":    (64,   0),
    "left":   (0,   64),
    "front":  (64,  64),
    "right":  (128, 64),
    "back":   (192, 64),
    "bottom": (64, 128),
}

# A neutral Minecraft-ish plains grass tint.
# This is only used because vanilla Minecraft normally applies biome tinting
# at runtime, while UT99 needs the final color baked into the texture.
GRASS_TINT = (124, 189, 107)

# Approximate vanilla leaf tint fallback. Spruce and birch have special fixed
# colors in Minecraft; the others normally use biome colors.
LEAF_TINTS = {
    "leaves_spruce.png": (97, 153, 97),
    "leaves_birch.png":  (128, 167, 85),
    "_default":           (89, 174, 74),
}


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def first_animation_frame(img: Image.Image) -> Image.Image:
    """
    Minecraft animated block textures are commonly vertical strips where each
    frame is one square. We only need one static frame for UT99.
    """
    w, h = img.size
    if h > w and h % w == 0:
        return img.crop((0, 0, w, w))
    return img


def multiply_tint(img: Image.Image, tint: tuple[int, int, int]) -> Image.Image:
    """Multiply RGB by a tint while preserving alpha."""
    rgba = img.convert("RGBA")
    pixels = rgba.load()

    tr, tg, tb = tint

    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (
                r * tr // 255,
                g * tg // 255,
                b * tb // 255,
                a,
            )

    return rgba


def load_source(filename: str) -> Image.Image:
    path = SOURCE_DIR / filename
    if not path.exists():
        raise FileNotFoundError(path)

    img = Image.open(path).convert("RGBA")
    return first_animation_frame(img)


def make_grass_side() -> Image.Image:
    """
    Vanilla 1.12.2 grass sides are made from grass_side.png plus the biome-
    tinted grass_side_overlay.png. Recreate that here if the overlay exists.
    """
    base = load_source("grass_side.png")
    overlay_path = SOURCE_DIR / "grass_side_overlay.png"

    if not overlay_path.exists():
        # Fallback if a resource pack does not contain the overlay.
        return base

    overlay = load_source("grass_side_overlay.png")
    overlay = multiply_tint(overlay, GRASS_TINT)

    result = base.copy()
    result.alpha_composite(overlay)
    return result


def prepare_face(filename: str, block_name: str, spec: Dict[str, Any], face: str) -> Image.Image:
    """
    Load and perform Minecraft-specific color processing for one cube face.
    """
    # Grass needs separate handling because only the grassy pixels are tinted.
    if block_name == "Grass":
        if face == "top":
            img = multiply_tint(load_source("grass_top.png"), GRASS_TINT)
        elif face == "bottom":
            img = load_source("dirt.png")
        else:
            img = make_grass_side()
    else:
        img = load_source(filename)

        if spec.get("tint") == "leaves":
            tint = LEAF_TINTS.get(filename, LEAF_TINTS["_default"])
            img = multiply_tint(img, tint)

    return img.resize((FACE_SIZE, FACE_SIZE), Image.Resampling.NEAREST)


def resolve_faces(spec: Dict[str, Any]) -> Dict[str, str]:
    """
    Expand {"all": "..."} into six faces and provide a sensible fallback for
    incomplete mappings such as 1.12.2 shulker-box tile-entity textures.
    """
    if "all" in spec:
        tex = spec["all"]
        return {face: tex for face in ATLAS_POSITIONS}

    faces = {face: spec.get(face) for face in ATLAS_POSITIONS}

    # Shulker boxes in the supplied block directory only have shulker_top_*.
    # Use that texture on all missing faces so every requested block still
    # produces a usable cube rather than aborting the entire generation.
    fallback = (
        faces.get("front")
        or faces.get("top")
        or faces.get("left")
        or faces.get("right")
        or faces.get("back")
        or faces.get("bottom")
    )

    if fallback is None:
        raise ValueError("Mapping contains no usable face texture")

    for face in faces:
        if faces[face] is None:
            faces[face] = fallback

    return faces


def has_real_transparency(img: Image.Image) -> bool:
    alpha = img.getchannel("A")
    lo, hi = alpha.getextrema()
    return lo < 255


def quantize_for_ut(atlas: Image.Image, transparent: bool) -> Image.Image:
    """
    Convert RGBA atlas to an 8-bit indexed image suitable for PCX.

    When transparency exists, palette index 0 is deliberately reserved for
    transparent pixels. UT99 can later interpret that index as transparent for
    a masked texture.
    """
    rgba = atlas.convert("RGBA")

    if not transparent:
        rgb = rgba.convert("RGB")
        return rgb.quantize(colors=256, method=Image.Quantize.MEDIANCUT)

    # Binary alpha is the practical option for classic UT99 masked textures.
    # Reserve index 0 by quantizing opaque colors to 255 entries, then shift all
    # their indexes up by one.
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)

    q = rgb.quantize(colors=255, method=Image.Quantize.MEDIANCUT)

    old_palette = q.getpalette()[:255 * 3]
    new_palette = [0, 0, 0] + old_palette
    new_palette += [0] * (768 - len(new_palette))

    src = q.load()
    a = alpha.load()

    out = Image.new("P", rgba.size, 0)
    out.putpalette(new_palette)
    dst = out.load()

    for y in range(rgba.height):
        for x in range(rgba.width):
            # Minecraft transparency becomes binary UT masked transparency.
            if a[x, y] < 128:
                dst[x, y] = 0
            else:
                dst[x, y] = src[x, y] + 1

    return out


def make_atlas(block_name: str, spec: Dict[str, Any]) -> tuple[Image.Image, bool, list[str]]:
    face_files = resolve_faces(spec)

    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (0, 0, 0, 0))
    used_files = []
    transparent = False

    for face, pos in ATLAS_POSITIONS.items():
        filename = face_files[face]
        face_img = prepare_face(filename, block_name, spec, face)

        used_files.append(filename)
        transparent = transparent or has_real_transparency(face_img)

        atlas.alpha_composite(face_img, dest=pos)

    return atlas, transparent, sorted(set(used_files))


def main() -> int:
    if not TEXTURE_MAP_FILE.exists():
        print(f"ERROR: Missing {TEXTURE_MAP_FILE}")
        return 1

    if not SOURCE_DIR.is_dir():
        print(f"ERROR: Missing source directory {SOURCE_DIR}")
        return 1

    data = load_json(TEXTURE_MAP_FILE)
    blocks = data.get("blocks", {})

    if not blocks:
        print("ERROR: texturemap.json contains no blocks")
        return 1

    OUTPUT_DIR.mkdir(exist_ok=True)
    PREVIEW_DIR.mkdir(exist_ok=True)

    manifest = {
        "source": str(SOURCE_DIR),
        "count": 0,
        "blocks": {},
        "warnings": [],
    }

    failures = []

    for index, (block_name, spec) in enumerate(blocks.items(), start=1):
        try:
            atlas, transparent, used_files = make_atlas(block_name, spec)

            # Keep a true-color PNG preview; useful for checking UV orientation
            # and colors without involving UnrealEd.
            preview_path = PREVIEW_DIR / f"MC{block_name}.png"
            atlas.save(preview_path)

            pcx = quantize_for_ut(atlas, transparent)
            pcx_path = OUTPUT_DIR / f"MC{block_name}.pcx"
            pcx.save(pcx_path, format="PCX")

            entry = {
                "pcx": pcx_path.name,
                "preview": preview_path.name,
                "transparent": transparent,
                "source_files": used_files,
            }

            if spec.get("special"):
                entry["special"] = spec["special"]
                manifest["warnings"].append(
                    f"{block_name}: {spec['special']}"
                )

            manifest["blocks"][block_name] = entry
            manifest["count"] += 1

            transparency_note = " [masked]" if transparent else ""
            print(f"[{index:3}/{len(blocks)}] {block_name}{transparency_note}")

        except Exception as exc:
            failures.append((block_name, str(exc)))
            print(f"[FAIL] {block_name}: {exc}")

    MANIFEST_FILE.write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8"
    )

    print()
    print(f"Generated {manifest['count']} / {len(blocks)} blocks")
    print(f"PCX output (Textures) : {OUTPUT_DIR}")
    print(f"PNG preview: {PREVIEW_DIR}")
    print(f"Manifest   : {MANIFEST_FILE}")

    if failures:
        print()
        print("Failures:")
        for block_name, reason in failures:
            print(f"  {block_name}: {reason}")
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
