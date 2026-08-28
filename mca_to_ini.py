#!/usr/bin/env python3
"""
Convert a Minecraft 1.12.2 Anvil region file directly to MinecraftChunk.ini
for the UT99 MinecraftBlocks project.

Default:
    python mca_to_ini.py r.0.0.mca

This reads chunk 0,0 and writes MinecraftChunk.ini.

Other chunk:
    python mca_to_ini.py r.0.0.mca --chunk-x 1 --chunk-z 0
"""

from __future__ import annotations

import argparse
import gzip
import io
import struct
import zlib
from collections import defaultdict
from pathlib import Path

TAG_END        = 0
TAG_BYTE       = 1
TAG_SHORT      = 2
TAG_INT        = 3
TAG_LONG       = 4
TAG_FLOAT      = 5
TAG_DOUBLE     = 6
TAG_BYTE_ARRAY = 7
TAG_STRING     = 8
TAG_LIST       = 9
TAG_COMPOUND   = 10
TAG_INT_ARRAY  = 11
TAG_LONG_ARRAY = 12


class NBTReader:
    def __init__(self, data: bytes):
        self.f = io.BytesIO(data)

    def read(self, n: int) -> bytes:
        b = self.f.read(n)
        if len(b) != n:
            raise EOFError("Unexpected end of NBT data")
        return b

    def u8(self): return self.read(1)[0]
    def i8(self): return struct.unpack(">b", self.read(1))[0]
    def i16(self): return struct.unpack(">h", self.read(2))[0]
    def u16(self): return struct.unpack(">H", self.read(2))[0]
    def i32(self): return struct.unpack(">i", self.read(4))[0]
    def i64(self): return struct.unpack(">q", self.read(8))[0]
    def f32(self): return struct.unpack(">f", self.read(4))[0]
    def f64(self): return struct.unpack(">d", self.read(8))[0]

    def string(self):
        n = self.u16()
        return self.read(n).decode("utf-8")

    def payload(self, tag_type):
        if tag_type == TAG_BYTE: return self.i8()
        if tag_type == TAG_SHORT: return self.i16()
        if tag_type == TAG_INT: return self.i32()
        if tag_type == TAG_LONG: return self.i64()
        if tag_type == TAG_FLOAT: return self.f32()
        if tag_type == TAG_DOUBLE: return self.f64()

        if tag_type == TAG_BYTE_ARRAY:
            return self.read(self.i32())

        if tag_type == TAG_STRING:
            return self.string()

        if tag_type == TAG_LIST:
            element_type = self.u8()
            count = self.i32()
            return [self.payload(element_type) for _ in range(count)]

        if tag_type == TAG_COMPOUND:
            result = {}
            while True:
                child_type = self.u8()
                if child_type == TAG_END:
                    break
                name = self.string()
                result[name] = self.payload(child_type)
            return result

        if tag_type == TAG_INT_ARRAY:
            return [self.i32() for _ in range(self.i32())]

        if tag_type == TAG_LONG_ARRAY:
            return [self.i64() for _ in range(self.i32())]

        raise ValueError(f"Unsupported NBT tag type {tag_type}")

    def root(self):
        tag_type = self.u8()
        if tag_type == TAG_END:
            return None
        self.string()  # root name
        return self.payload(tag_type)


def parse_region_coords(region_file: Path):
    parts = region_file.name.split(".")
    if len(parts) < 4 or parts[0] != "r" or parts[-1].lower() != "mca":
        raise ValueError(f"Expected filename like r.0.0.mca, got {region_file.name}")
    return int(parts[1]), int(parts[2])


def read_chunk_nbt(region_file: Path, chunk_x: int, chunk_z: int):
    region_x, region_z = parse_region_coords(region_file)

    local_x = chunk_x - region_x * 32
    local_z = chunk_z - region_z * 32

    if not (0 <= local_x < 32 and 0 <= local_z < 32):
        raise ValueError(
            f"Chunk {chunk_x},{chunk_z} is not in region "
            f"r.{region_x}.{region_z}.mca"
        )

    index = local_x + local_z * 32

    with region_file.open("rb") as f:
        f.seek(index * 4)
        location = f.read(4)

        offset = (location[0] << 16) | (location[1] << 8) | location[2]
        sectors = location[3]

        if offset == 0 or sectors == 0:
            raise ValueError(f"Chunk {chunk_x},{chunk_z} is not present")

        f.seek(offset * 4096)

        length = struct.unpack(">I", f.read(4))[0]
        compression = f.read(1)[0]
        payload = f.read(length - 1)

    if compression == 1:
        raw = gzip.decompress(payload)
    elif compression == 2:
        raw = zlib.decompress(payload)
    elif compression == 3:
        raw = payload
    else:
        raise ValueError(f"Unknown compression type {compression}")

    return NBTReader(raw).root()


def nibble(data: bytes, index: int):
    b = data[index >> 1]
    return ((b >> 4) & 0x0F) if (index & 1) else (b & 0x0F)


def iter_blocks(root, chunk_x, chunk_z):
    level = root.get("Level", root)

    for section in level.get("Sections", []):
        sy = section["Y"]
        if sy < 0:
            sy += 256

        blocks = section.get("Blocks")
        data = section.get("Data")
        add = section.get("Add")

        if blocks is None or data is None:
            continue

        for y in range(16):
            for z in range(16):
                for x in range(16):
                    i = (y << 8) | (z << 4) | x

                    block_id = blocks[i]
                    if add is not None:
                        block_id |= nibble(add, i) << 8

                    meta = nibble(data, i)

                    if block_id == 0:
                        continue

                    yield (
                        chunk_x * 16 + x,
                        sy * 16 + y,
                        chunk_z * 16 + z,
                        block_id,
                        meta,
                    )


CODE_ORDER = [
    "Air",
    "Stone",
    "Grass",
    "Dirt",
    "Bedrock",
    "Granite",
    "Diorite",
    "Andesite",
    "BirchPlanks",
    "BirchLog",
    "BirchLeaves",
    "CoalOre",
    "IronOre",
    "GoldOre",
    "RedstoneOre",
    "Gravel",
    "TallGrass",
    "Dandelion",
    "CraftingTable",
]

NAME_TO_CODE = {name: i for i, name in enumerate(CODE_ORDER)}


def map_block(block_id, meta):
    # Leaves: bits 2/3 are decay/check-decay flags. Species is lower 2 bits.
    if block_id == 18:
        meta &= 3

    mapping = {
        (1, 0): "Stone",
        (1, 1): "Granite",
        (1, 3): "Diorite",
        (1, 5): "Andesite",
        (2, 0): "Grass",
        (3, 0): "Dirt",
        (5, 2): "BirchPlanks",
        (7, 0): "Bedrock",
        (13, 0): "Gravel",
        (14, 0): "GoldOre",
        (15, 0): "IronOre",
        (16, 0): "CoalOre",
        (17, 2): "BirchLog",
        (18, 2): "BirchLeaves",
        (31, 1): "TallGrass",
        (37, 0): "Dandelion",
        (58, 0): "CraftingTable",
        (73, 0): "RedstoneOre",
    }

    return mapping.get((block_id, meta))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("region", type=Path, help="Minecraft region file, e.g. r.0.0.mca")
    ap.add_argument("--chunk-x", type=int, default=0)
    ap.add_argument("--chunk-z", type=int, default=0)
    ap.add_argument("-o", "--output", type=Path, default=Path("MinecraftChunk.ini"))
    args = ap.parse_args()

    root = read_chunk_nbt(args.region, args.chunk_x, args.chunk_z)

    layers = defaultdict(lambda: [0] * 256)
    unknown = defaultdict(int)
    min_y = None
    max_y = None
    mapped_count = 0

    for world_x, world_y, world_z, block_id, meta in iter_blocks(
        root, args.chunk_x, args.chunk_z
    ):
        name = map_block(block_id, meta)

        if name is None:
            unknown[(block_id, meta)] += 1
            continue

        local_x = world_x - args.chunk_x * 16
        local_z = world_z - args.chunk_z * 16

        layers[world_y][local_z * 16 + local_x] = NAME_TO_CODE[name]

        min_y = world_y if min_y is None else min(min_y, world_y)
        max_y = world_y if max_y is None else max(max_y, world_y)
        mapped_count += 1

    if unknown:
        print("ERROR: unmapped Minecraft block IDs:")
        for (block_id, meta), count in sorted(unknown.items()):
            print(f"  {block_id}:{meta} -> {count}")
        raise SystemExit(1)

    if min_y is None:
        raise SystemExit("ERROR: chunk contains no mapped non-air blocks")

    lines = [
        "[MinecraftBlocks.MinecraftChunkLoader]",
        f"ChunkX={args.chunk_x}",
        f"ChunkZ={args.chunk_z}",
        f"MinY={min_y}",
        f"MaxY={max_y}",
        "",
    ]

    for i, name in enumerate(CODE_ORDER):
        lines.append(f"BlockName[{i}]={name}")

    lines.append("")

    for y in range(min_y, max_y + 1):
        lines.append(
            f"Layer[{y}]=" + ",".join(str(v) for v in layers[y])
        )

    args.output.write_text("\r\n".join(lines) + "\r\n", encoding="ascii")

    print(f"Source : {args.region}")
    print(f"Chunk  : {args.chunk_x},{args.chunk_z}")
    print(f"Blocks : {mapped_count}")
    print(f"Y range: {min_y}..{max_y}")
    print(f"Output : {args.output.resolve()}")


if __name__ == "__main__":
    main()
