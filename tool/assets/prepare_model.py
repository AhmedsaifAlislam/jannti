#!/usr/bin/env python3
"""Normalise an externally sourced GLB so `three_dart` can actually draw it.

Why this exists
---------------
Every art pack that reaches this project is exported through `gltfpack`, and
`GLTFLoader` in `three_dart` understands none of what that adds:

* `KHR_mesh_quantization` — positions and normals are integers. The loader
  ignores the `normalized` flag, so the shader receives 127 instead of 0.49 and
  the model comes out black or crumpled.
* `KHR_texture_transform` — the material multiplies the UVs 16x in the material
  graph. The loader drops the extension, so one image is smeared over the whole
  mesh.
* `EXT_texture_webp` — images live inside the GLB as webp. The loader has no webp
  path, and an embedded image is fatal anyway: `repack_glb.py` explains why every
  texture must become a sidecar PNG.

What it does, and what it does not
----------------------------------
Geometry is never rebuilt. The script bakes the texture transform into the UV
attribute, decodes image 0 to a sidecar PNG, drops every image buffer view, and
writes a known-good single-material glTF.

Normal and metal/roughness maps are dropped on purpose: the first needs computed
tangents (the loader does not generate them) and the second arrives with an
undefined `metalness`. Painted art already carries its own shading.

Usage
-----
    # 1) shrink the mesh once, then dequantize
    npx --yes @gltf-transform/cli@4 simplify src.glb /tmp/slim.glb \\
        --ratio 0.006 --error 0.002
    npx --yes @gltf-transform/cli@4 prune /tmp/slim.glb /tmp/slim2.glb
    npx --yes @gltf-transform/cli@4 dequantize /tmp/slim2.glb /tmp/deq.glb
    # 2) convert to the project format
    python tool/assets/prepare_model.py /tmp/deq.glb assets/3d/tier5/palm_large.glb
"""

from __future__ import annotations

import io
import json
import os
import struct
import sys
from typing import Any, Dict, List, Tuple

from PIL import Image

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942

COMPONENT_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
COMPONENT_FMT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
TYPE_COUNT = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
    "MAT2": 4,
    "MAT3": 9,
    "MAT4": 16,
}


def read_glb(path: str) -> Tuple[Dict[str, Any], bytearray]:
    data = open(path, "rb").read()
    magic, _version, _length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC:
        raise ValueError(f"not a GLB file: {path}")
    offset = 12
    gltf: Dict[str, Any] | None = None
    binary = bytearray()
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        body = data[offset + 8 : offset + 8 + chunk_len]
        if chunk_type == CHUNK_JSON:
            gltf = json.loads(body.decode("utf-8"))
        elif chunk_type == CHUNK_BIN:
            binary = bytearray(body)
        offset += 8 + chunk_len + ((4 - chunk_len % 4) % 4 if chunk_len % 4 else 0)
    if gltf is None:
        raise ValueError(f"no JSON chunk in {path}")
    return gltf, binary


def write_glb(path: str, gltf: Dict[str, Any], binary: bytes) -> None:
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    binp = binary + b"\x00" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binp)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", GLB_MAGIC, 2, total))
        f.write(struct.pack("<II", len(js), CHUNK_JSON) + js)
        f.write(struct.pack("<II", len(binp), CHUNK_BIN) + binp)


def accessor_fmt(accessor: Dict[str, Any]) -> str:
    return "<" + COMPONENT_FMT[accessor["componentType"]] * TYPE_COUNT[accessor["type"]]


def accessor_values(gltf: Dict[str, Any], binary: bytearray, index: int) -> List[tuple]:
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    elem = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    stride = view.get("byteStride") or elem
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fmt = accessor_fmt(acc)
    return [
        struct.unpack_from(fmt, binary, base + i * stride) for i in range(acc["count"])
    ]


def bake_texture_transform(
    gltf: Dict[str, Any], binary: bytearray, repeat: float = 1.0
) -> int:
    """Writes `KHR_texture_transform` into the UV attribute itself.

    The loader ignores the extension, so the material's `scale`/`offset` has to
    become part of the coordinates: uv' = uv * scale + offset — exactly what the
    shader would have done. `repeat` multiplies the scale on top, for a model
    that is stretched far past its authored size and would otherwise show a
    texel tens of times coarser than the ground it sits on.
    """
    transformed = 0
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            uv_index = prim["attributes"].get("TEXCOORD_0")
            if uv_index is None:
                continue
            material_index = prim.get("material")
            if material_index is None:
                continue
            material = gltf["materials"][material_index]
            pbr = material.get("pbrMetallicRoughness", {})
            info = (
                pbr.get("baseColorTexture", {})
                .get("extensions", {})
                .get("KHR_texture_transform")
            )
            if not info:
                continue
            uv = accessor_values(gltf, binary, uv_index)
            scale = info.get("scale", [1.0, 1.0])
            offset = info.get("offset", [0.0, 0.0])
            changed = [
                (
                    u * scale[0] * repeat + offset[0],
                    v * scale[1] * repeat + offset[1],
                )
                for u, v in uv
            ]
            _write_uv(gltf, binary, uv_index, changed)
            transformed += 1
    return transformed


def _write_uv(
    gltf: Dict[str, Any], binary: bytearray, index: int, values: List[tuple]
) -> None:
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    elem = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    stride = view.get("byteStride") or elem
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fmt = accessor_fmt(acc)
    for i, value in enumerate(values):
        struct.pack_into(fmt, binary, base + i * stride, *value)


def strip_material(gltf: Dict[str, Any], name: str) -> None:
    """Keeps the colour map alone and makes it readable in `three_dart`."""
    gltf["materials"] = [
        {
            "name": f"{name}_surface",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorFactor": [1.0, 1.0, 1.0, 1.0],
                "baseColorTexture": {"index": 0},
                # The source ships no metallicFactor/roughnessFactor, so both
                # default to 1.0 — fully metallic, and black without an
                # environment map.
                "metallicFactor": 0.0,
                "roughnessFactor": 0.85,
            },
        }
    ]
    gltf["textures"] = [{"sampler": 0, "source": 0}]
    gltf["samplers"] = [
        {"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}
    ]
    for key in ("extensionsUsed", "extensionsRequired"):
        gltf.pop(key, None)
    for material in gltf["materials"]:
        material.pop("extensions", None)


def pack_accessors(gltf: Dict[str, Any], binary: bytearray) -> bytearray:
    """Rewrites every accessor as its own tightly packed buffer view.

    `gltf-transform dequantize` interleaves position, normal and UV into one
    buffer view and marks it with `byteStride`. `InterleavedBuffer` in three_dart
    takes an `int` stride but the port computes `byteStride / elementBytes`,
    which is a double in Dart, so the whole parse throws
    `type 'double' is not a subtype of type 'int?'` and the model never loads.
    One view per accessor, no stride, is the only shape that loader accepts.

    The values themselves are copied bytes for bytes — this step can never
    change geometry, and it also carries the image views away on the way out
    (they become sidecar PNGs).
    """
    image_views = {
        image["bufferView"] for image in gltf.get("images", []) if "bufferView" in image
    }
    new_bin = bytearray()
    views: List[Dict[str, Any]] = []

    for acc in gltf.get("accessors", []):
        view_index = acc.get("bufferView")
        if view_index is None or view_index in image_views:
            continue
        view = gltf["bufferViews"][view_index]
        elem = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
        stride = view.get("byteStride") or elem
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        fmt = "<" + COMPONENT_FMT[acc["componentType"]] * TYPE_COUNT[acc["type"]]

        new_bin += b"\x00" * ((4 - len(new_bin) % 4) % 4)
        offset = len(new_bin)
        for i in range(acc["count"]):
            new_bin += struct.pack(
                fmt, *struct.unpack_from(fmt, binary, base + i * stride)
            )

        packed = {
            "buffer": 0,
            "byteOffset": offset,
            "byteLength": acc["count"] * elem,
        }
        if "target" in view:
            packed["target"] = view["target"]
        acc["bufferView"] = len(views)
        acc["byteOffset"] = 0
        views.append(packed)

    gltf["bufferViews"] = views
    gltf["buffers"] = [{"byteLength": len(new_bin)}]
    return new_bin


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) < 3:
        print(__doc__)
        return 2

    src, dst = sys.argv[1], sys.argv[2]
    texture_size = 1024
    if "--texture-size" in sys.argv:
        texture_size = int(sys.argv[sys.argv.index("--texture-size") + 1])
    uv_repeat = 1.0
    if "--uv-repeat" in sys.argv:
        uv_repeat = float(sys.argv[sys.argv.index("--uv-repeat") + 1])
    jpg_quality = 0
    if "--jpg-quality" in sys.argv:
        jpg_quality = int(sys.argv[sys.argv.index("--jpg-quality") + 1])

    gltf, binary = read_glb(src)

    baked = bake_texture_transform(gltf, binary, uv_repeat)
    print(f"texture transform baked into {baked} primitive(s)")

    # Image 0 is the base colour map in every pack used here.
    image_def = gltf["images"][0]
    view = gltf["bufferViews"][image_def["bufferView"]]
    start = view.get("byteOffset", 0)
    raw = bytes(binary[start : start + view["byteLength"]])
    image = Image.open(io.BytesIO(raw)).convert("RGB")
    if max(image.size) > texture_size:
        scale = texture_size / max(image.size)
        image = image.resize(
            (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
            Image.LANCZOS,
        )
    # JPEG is opt-in: a 2048 colour atlas costs 5.1 MB as PNG and 1.0 MB at
    # quality 88, and both decoders here (the browser <img> and package:image)
    # read it, so a large ground map no longer has to ship as PNG.
    extension = ".jpg" if jpg_quality else ".png"
    texture_name = os.path.splitext(os.path.basename(dst))[0] + extension
    sidecar = os.path.join(os.path.dirname(dst) or ".", texture_name)
    if jpg_quality:
        image.save(sidecar, "JPEG", quality=jpg_quality, subsampling=1, optimize=True)
    else:
        image.save(sidecar, optimize=True)
    print(f"{sidecar} {image.size} {os.path.getsize(sidecar) / 1024:.0f} KB")

    # One tightly packed view per accessor; see pack_accessors for why.
    binary = pack_accessors(gltf, binary)
    name = os.path.splitext(os.path.basename(dst))[0]
    strip_material(gltf, name)
    gltf["images"] = [
        {
            "name": name,
            "uri": texture_name,
            "mimeType": "image/jpeg" if jpg_quality else "image/png",
        }
    ]
    gltf["buffers"] = [{"byteLength": len(binary)}]

    write_glb(dst, gltf, bytes(binary))
    print(f"{dst} {os.path.getsize(dst) / 1024:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
