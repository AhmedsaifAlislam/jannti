#!/usr/bin/env python3
"""Repack GLB files: drop dead bytes from the binary chunk and (optionally)
downscale the embedded PNG textures.

Why this exists
---------------
The models exported for Jannati carry two kinds of waste:

1. The binary chunk is far larger than the accessors actually read. Example:
   `palm_medium.glb` is 1698 KB, the 1024x1024 texture is 719 KB, and the
   geometry the renderer reads (621 vertices x position/normal/uv + 1200
   indices) is about 19 KB. The other ~977 KB is unreachable padding written by
   the exporter.
2. Every texture is 1024x1024. A tree is roughly 100-200 px tall on a phone
   screen, so 512 (or 256) is already more than 1:1 at native resolution.

Safety
------
The repack never touches accessor values. It only:
  * copies the byte span each bufferView is actually read from,
  * re-encodes the PNG at the requested size,
  * rewrites offsets.
`verify()` decodes both files and asserts the geometry is bit-identical
(position, normal, uv, indices), so a regression cannot go unnoticed.

Usage
-----
    python tool/assets/repack_glb.py --out build/asset_repack --size 512 assets/3d
    python tool/assets/repack_glb.py --out build/asset_repack --size 512 --files a.glb b.glb
"""

from __future__ import annotations

import argparse
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


def read_glb(path: str) -> Tuple[Dict[str, Any], bytes]:
    data = open(path, "rb").read()
    magic, _version, _length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC:
        raise ValueError(f"not a GLB file: {path}")
    offset = 12
    gltf: Dict[str, Any] | None = None
    binary = b""
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        body = data[offset + 8 : offset + 8 + chunk_len]
        if chunk_type == CHUNK_JSON:
            gltf = json.loads(body.decode("utf-8"))
        elif chunk_type == CHUNK_BIN:
            binary = body
        offset += 8 + chunk_len + ((4 - chunk_len % 4) % 4 if chunk_len % 4 else 0)
    if gltf is None:
        raise ValueError(f"no JSON chunk in {path}")
    return gltf, binary


def write_glb(path: str, gltf: Dict[str, Any], binary: bytes) -> None:
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    binp = binary + b"\x00" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binp)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", GLB_MAGIC, 2, total))
        f.write(struct.pack("<II", len(js), CHUNK_JSON) + js)
        f.write(struct.pack("<II", len(binp), CHUNK_BIN) + binp)


def accessor_index_views(gltf: Dict[str, Any]) -> Dict[int, List[int]]:
    """Map bufferView index -> list of accessor indexes that read from it."""
    refs: Dict[int, List[int]] = {}
    for i, acc in enumerate(gltf.get("accessors", [])):
        bv = acc.get("bufferView")
        if bv is None:
            continue
        refs.setdefault(bv, []).append(i)
    return refs


def used_span(
    gltf: Dict[str, Any], view_index: int, accessors: List[int]
) -> Tuple[int, int]:
    """Byte range of a bufferView that the given accessors actually read."""
    view = gltf["bufferViews"][view_index]
    stride = view.get("byteStride")
    start = None
    end = None
    for ai in accessors:
        acc = gltf["accessors"][ai]
        elem = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
        acc_stride = stride or elem
        base = acc.get("byteOffset", 0)
        first = base
        last = base + acc_stride * (acc["count"] - 1) + elem
        start = first if start is None else min(start, first)
        end = last if end is None else max(end, last)
    if start is None:
        return 0, view["byteLength"]
    return start, min(end, view["byteLength"])


def texture_views(gltf: Dict[str, Any]) -> Dict[int, Dict[str, Any]]:
    result = {}
    for img in gltf.get("images", []):
        bv = img.get("bufferView")
        if bv is not None:
            result[bv] = img
    return result


def resize_png(raw: bytes, size: int) -> bytes:
    image = Image.open(io.BytesIO(raw)).convert("RGBA")
    if max(image.size) > size:
        scale = size / max(image.size)
        box = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image = image.resize(box, Image.LANCZOS)
    out = io.BytesIO()
    image.save(out, format="PNG", optimize=True)
    return out.getvalue()


def repack(src: str, dst: str, size: int | None) -> Dict[str, Any]:
    gltf, binary = read_glb(src)
    acc_refs = accessor_index_views(gltf)
    img_refs = texture_views(gltf)

    pieces: List[Tuple[int, bytes]] = []  # (old view index, new bytes)
    new_views: List[Dict[str, Any]] = []
    index_map: Dict[int, int] = {}
    offsets: Dict[int, int] = {}

    out = bytearray()
    for old_index, view in enumerate(gltf.get("bufferViews", [])):
        if old_index in img_refs:
            raw = _slice(binary, view)
            data = resize_png(raw, size) if size else raw
            start = 0
        elif old_index in acc_refs:
            start, end = used_span(gltf, old_index, acc_refs[old_index])
            data = _slice(binary, view)[start:end]
        else:
            # unreferenced bufferView: drop it entirely
            continue

        out += b"\x00" * ((4 - len(out) % 4) % 4)
        index_map[old_index] = len(new_views)
        offsets[old_index] = start
        new_view = dict(view)
        new_view["byteOffset"] = len(out)
        new_view["byteLength"] = len(data)
        new_views.append(new_view)
        out += data

    gltf["bufferViews"] = new_views
    gltf["buffers"] = [{"byteLength": len(out)}]

    for i, acc in enumerate(gltf.get("accessors", [])):
        bv = acc.get("bufferView")
        if bv is None:
            continue
        acc["bufferView"] = index_map[bv]
        acc["byteOffset"] = acc.get("byteOffset", 0) - offsets[bv]

    for img in gltf.get("images", []):
        bv = img.get("bufferView")
        if bv is not None:
            img["bufferView"] = index_map[bv]
        if "uri" in img and img["uri"].startswith("data:"):
            raise ValueError("data-URI images are not supported")

    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    write_glb(dst, gltf, bytes(out))
    return gltf


def _slice(binary: bytes, view: Dict[str, Any]) -> bytes:
    start = view.get("byteOffset", 0)
    return binary[start : start + view["byteLength"]]


def read_accessor(gltf: Dict[str, Any], binary: bytes, index: int) -> List[tuple]:
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    elem = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    stride = view.get("byteStride") or elem
    fmt = "<" + COMPONENT_FMT[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = []
    for i in range(acc["count"]):
        out.append(struct.unpack_from(fmt, binary, base + i * stride))
    return out


def geometry_fingerprint(path: str) -> Dict[str, Any]:
    gltf, binary = read_glb(path)
    primitives = []
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            entry = {"mode": prim.get("mode", 4)}
            for name, acc_index in sorted(prim.get("attributes", {}).items()):
                entry[name] = read_accessor(gltf, binary, acc_index)
            if "indices" in prim:
                entry["indices"] = read_accessor(gltf, binary, prim["indices"])
            entry["material"] = prim.get("material")
            primitives.append(entry)
    materials = []
    for mat in gltf.get("materials", []):
        pbr = mat.get("pbrMetallicRoughness", {})
        materials.append(
            {
                "name": mat.get("name"),
                "baseColorFactor": pbr.get("baseColorFactor"),
                "doubleSided": mat.get("doubleSided"),
                "alphaMode": mat.get("alphaMode"),
            }
        )
    images = []
    for img in gltf.get("images", []):
        view = gltf["bufferViews"][img["bufferView"]]
        raw = _slice(binary, view)
        image = Image.open(io.BytesIO(raw))
        images.append({"size": image.size, "mode": image.mode})
    return {"primitives": primitives, "materials": materials, "images": images}


def verify(src: str, dst: str) -> List[str]:
    problems: List[str] = []
    a = geometry_fingerprint(src)
    b = geometry_fingerprint(dst)

    if len(a["primitives"]) != len(b["primitives"]):
        problems.append(
            f"primitive count {len(a['primitives'])} -> {len(b['primitives'])}"
        )
    for i, (pa, pb) in enumerate(zip(a["primitives"], b["primitives"])):
        for key in pa:
            if key == "material":
                continue
            if pa[key] != pb.get(key):
                if key in ("POSITION", "NORMAL", "TEXCOORD_0", "indices"):
                    problems.append(f"primitive {i}: {key} values changed")
                else:
                    problems.append(f"primitive {i}: {key} mismatch")
    if a["materials"] != b["materials"]:
        problems.append("material definitions changed")
    if len(a["images"]) != len(b["images"]):
        problems.append("image count changed")
    return problems


def main() -> int:
    # the asset names include Arabic file names; the default Windows console
    # codepage cannot print them and would abort the run halfway through a batch
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--out", required=True, help="output directory (mirrors the source tree)"
    )
    ap.add_argument(
        "--size", type=int, default=512, help="max texture edge in pixels (0 = keep)"
    )
    ap.add_argument(
        "--root", default=None, help="source root used to mirror relative paths"
    )
    ap.add_argument("targets", nargs="+", help="directories or .glb files")
    args = ap.parse_args()

    files: List[str] = []
    for target in args.targets:
        if os.path.isdir(target):
            for dirpath, _dirnames, filenames in os.walk(target):
                for name in sorted(filenames):
                    if name.lower().endswith(".glb"):
                        files.append(os.path.join(dirpath, name))
        else:
            files.append(target)

    total_before = total_after = 0
    failures = 0
    print(f"{'file':46} {'before':>9} {'after':>9} {'saved':>7}  check")
    print("-" * 88)
    for src in files:
        rel = os.path.relpath(src, args.root) if args.root else os.path.basename(src)
        dst = os.path.join(args.out, rel)
        try:
            repack(src, dst, args.size or None)
            problems = verify(src, dst)
        except Exception as exc:  # noqa: BLE001 - report and continue
            print(f"{rel:46} ERROR {exc}")
            failures += 1
            continue
        before = os.path.getsize(src)
        after = os.path.getsize(dst)
        total_before += before
        total_after += after
        saved = 100 - after * 100 / before
        status = "OK" if not problems else "; ".join(problems)
        if problems:
            failures += 1
        print(
            f"{rel:46} {before / 1024:8.0f}K {after / 1024:8.0f}K {saved:6.0f}%  {status}"
        )

    print("-" * 88)
    print(
        f"TOTAL {total_before / 1024 / 1024:.1f} MB -> {total_after / 1024 / 1024:.1f} MB "
        f"({100 - total_after * 100 / max(total_before, 1):.0f}% smaller), failures: {failures}"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
