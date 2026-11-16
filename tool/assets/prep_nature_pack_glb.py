"""Turns the converted FreeLowPoly nature-pack GLBs into two-tone models.

The pack's FBX files reference a ``base_color_texture`` that is **not** in the
download, so FBX2glTF writes one white material per model.  ``PP_Color_Palette``
is only a colour chart, not that texture: pointing the material at it makes the
mountain orange because its UVs land on an arbitrary swatch.

What the meshes *do* keep is the artist's material split.  Every model's UVs sit
on exactly two windows of the missing atlas:

    band A   v 0.150..0.233   the moss / grass faces (the top of a mountain)
    band B   v 0.457..0.535   the rock faces (the sides), or the dirt of a path

So each triangle is routed to one of two primitives by its average V, and each
primitive gets a flat colour taken from the pack's own palette.  The result is
the low-poly look of the reference demo without the lost texture, and the GLBs
ship with no texture at all — no sidecar PNG needed.

    python tool/assets/prep_nature_pack_glb.py --src C:/temp/fbxwork/out
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942

# Source stem -> output stem. The output name is what the scene references.
NAMES = {
    "PP_Forest_Mountain_Moss_01": "floating_moss_1",
    "PP_Forest_Mountain_Moss_02": "floating_moss_2",
    "PP_Meadow_07": "floating_meadow_1",
    "PP_Meadow_08": "floating_meadow_2",
    "PP_Meadow_Path_05": "floating_meadow_path",
    "PP_Floor_Tile_05": "floor_tile_1",
    "PP_Floor_Tile_06": "floor_tile_2",
    "PP_Floor_Tile_15": "floor_tile_3",
    "PP_Floor_Tile_16": "floor_tile_4",
}

# The split point between the two UV bands, halfway between 0.24 and 0.45.
BAND_SPLIT_V = 0.35

# Flat colours for the two bands, sampled from PP_Color_Palette.png. Keyed by
# output stem prefix so the paving stones do not come out moss green.
COLORS = {
    "default": (
        [0x6A / 255, 0x96 / 255, 0x34 / 255, 1.0],  # moss green
        [0x80 / 255, 0x5F / 255, 0x44 / 255, 1.0],  # warm rock brown
    ),
    "floor": (
        [0x9A / 255, 0x96 / 255, 0x8C / 255, 1.0],  # cut stone
        [0x6E / 255, 0x6A / 255, 0x60 / 255, 1.0],  # stone in shadow
    ),
}


def colors_for(target: str) -> tuple[list[float], list[float]]:
    return COLORS["floor" if target.startswith("floor") else "default"]


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC or version != 2:
        raise SystemExit(f"{path}: not a glTF 2.0 binary")
    offset = 12
    doc: dict | None = None
    binary = b""
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + chunk_len]
        if chunk_type == JSON_CHUNK:
            doc = json.loads(chunk.decode("utf-8"))
        elif chunk_type == BIN_CHUNK:
            binary = chunk
        offset += 8 + chunk_len
    if doc is None:
        raise SystemExit(f"{path}: no JSON chunk")
    return doc, binary


def write_glb(path: Path, doc: dict, binary: bytes) -> None:
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\x00" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + (8 + len(binary) if binary else 0)
    out = bytearray()
    out += struct.pack("<III", GLB_MAGIC, 2, total)
    out += struct.pack("<II", len(text), JSON_CHUNK) + text
    if binary:
        out += struct.pack("<II", len(binary), BIN_CHUNK) + binary
    path.write_bytes(bytes(out))


def accessor_view(doc: dict, accessor_index: int) -> tuple[bytes, int, int, int]:
    """Returns (raw component bytes, component type, count, component size)."""
    accessor = doc["accessors"][accessor_index]
    view = doc["bufferViews"][accessor["bufferView"]]
    size = {5121: 1, 5123: 2, 5125: 4, 5126: 4}[accessor["componentType"]]
    return accessor, view, size, accessor["count"]


def read_floats(binary: bytes, doc: dict, accessor_index: int, components: int):
    accessor, view, size, count = accessor_view(doc, accessor_index)
    base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride") or size * components
    out = []
    for i in range(count):
        out.append(
            struct.unpack_from("<" + "f" * components, binary, base + i * stride)
        )
    return out


def read_indices(binary: bytes, doc: dict, accessor_index: int):
    accessor, view, size, count = accessor_view(doc, accessor_index)
    base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    fmt = {1: "B", 2: "H", 4: "I"}[size]
    return list(struct.unpack_from("<" + fmt * count, binary, base))


def add_material(doc: dict, name: str, color: list[float]) -> int:
    for index, material in enumerate(doc.get("materials", [])):
        if material.get("name") == name:
            return index
    doc.setdefault("materials", []).append(
        {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": color,
                # No environment map in the scene: metallic reads as black.
                "metallicFactor": 0.0,
                "roughnessFactor": 1.0,
            },
            "doubleSided": True,
        }
    )
    return len(doc["materials"]) - 1


def split_mesh(
    doc: dict,
    binary: bytearray,
    mesh: dict,
    top_color: list[float],
    side_color: list[float],
) -> None:
    primitives = []
    for primitive in mesh["primitives"]:
        attributes = primitive["attributes"]
        if "TEXCOORD_0" not in attributes or "indices" not in primitive:
            primitives.append(primitive)
            continue

        uvs = read_floats(binary, doc, attributes["TEXCOORD_0"], 2)
        indices = read_indices(binary, doc, primitive["indices"])

        top: list[int] = []
        side: list[int] = []
        for t in range(0, len(indices), 3):
            tri = indices[t : t + 3]
            # Average V of the three corners: the two bands never mix inside a
            # triangle (the exports are flat-shaded polygons), so this is exact.
            v = sum(uvs[i][1] for i in tri) / 3
            (top if v < BAND_SPLIT_V else side).append(t)

        for bucket, color, name in (
            (top, top_color, "nature_top"),
            (side, side_color, "nature_side"),
        ):
            if not bucket:
                continue
            flat = [indices[t + k] for t in bucket for k in range(3)]
            offset = len(binary)
            binary += struct.pack("<" + "I" * len(flat), *flat)
            binary += b"\x00" * (-len(binary) % 4)

            doc["bufferViews"].append(
                {
                    "buffer": 0,
                    "byteOffset": offset,
                    "byteLength": len(flat) * 4,
                    "target": 34963,  # ELEMENT_ARRAY_BUFFER
                }
            )
            doc["accessors"].append(
                {
                    "bufferView": len(doc["bufferViews"]) - 1,
                    "componentType": 5125,
                    "count": len(flat),
                    "type": "SCALAR",
                }
            )

            new = {
                "attributes": attributes,
                "indices": len(doc["accessors"]) - 1,
                "material": add_material(doc, name, color),
                "mode": 4,
            }
            primitives.append(new)

    mesh["primitives"] = primitives


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--src", required=True, type=Path, help="folder of FBX2glTF output"
    )
    parser.add_argument("--out", type=Path, default=Path("assets/3d"))
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)

    for source, target in NAMES.items():
        glb = args.src / f"{source}.glb"
        if not glb.exists():
            print(f"MISSING {glb.name}")
            continue
        doc, raw = read_glb(glb)
        binary = bytearray(raw)

        # The unused chart texture reference goes away with the texture.
        for key in ("images", "samplers", "textures"):
            doc.pop(key, None)

        top_color, side_color = colors_for(target)
        for mesh in doc.get("meshes", []):
            split_mesh(doc, binary, mesh, top_color, side_color)

        # Drop the white material FBX2glTF wrote: no primitive points at it now.
        used = sorted(
            {
                primitive["material"]
                for mesh in doc.get("meshes", [])
                for primitive in mesh.get("primitives", [])
                if "material" in primitive
            }
        )
        remap = {old: new for new, old in enumerate(used)}
        doc["materials"] = [doc["materials"][old] for old in used]
        for mesh in doc.get("meshes", []):
            for primitive in mesh["primitives"]:
                if "material" in primitive:
                    primitive["material"] = remap[primitive["material"]]

        doc["buffers"] = [{"byteLength": len(binary)}]
        out = args.out / f"{target}.glb"
        write_glb(out, doc, bytes(binary))
        print(
            f"{target}.glb  {len(doc['materials'])} materials  {out.stat().st_size // 1024} KB"
        )


if __name__ == "__main__":
    main()
