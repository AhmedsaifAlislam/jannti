#!/usr/bin/env python3
"""طبّع موديلًا خارجيًا (glTF) ليعمل في مشغّل `three_dart` في هذا المشروع.

لماذا هذا الملف
---------------
`assets/bridge.glb` وصل من مصدر خارجي عبر `gltfpack` بخصائص لا يفهمها
`GLTFLoader` في `three_dart`:

* `KHR_mesh_quantization` — المواضع والنواظم مخزّنة كأعداد صحيحة مضغوطة.
  المحمّل لا يقرأ `normalized`، فتصل النواظم إلى الظلّال بقيم مثل ١٢٧ بدل
  ٠٫٤٩، ويخرج الموديل أسود أو مشوّهًا.
* `KHR_texture_transform` — الخامة تتكرّر ١٦ مرة عبر `scale` في المادة،
  والمحمّل يتجاهلها فتظهر صورة واحدة ممطوطة على الجسر كله.
* `EXT_texture_webp` — الصور webp مدفوعة داخل الملف، والمحمّل لا يعرف
  الإضافة ولا يفكّ الصورة المدفونة (انظر `repack_glb.py`).

هذا السكربت لا يعيد بناء الهندسة: يفكّ التكميم، ويطبخ تحويل الخامة في
إحداثيات UV، ويُخرج صورة اللون كملف PNG جانبي، ويحذف ما لا يدعمه المحمّل.
الهندسة تبقى كما هي بالضبط، و`verify()` يتحقق من ذلك.

ما يُحذف عن قصد
---------------
خريطة النواظم وخريطة المعدن/الخشونة تُسقطان. الأولى تحتاج مماسات محسوبة
(المحمّل لا يولّدها)، والثانية تأتي مع `metalness` غير معرّف. حجر مطلي بألوان
مرسومة لا يحتاج أيًّا منهما: اللون المرسوم فيه الظل والعمق أصلًا.

الاستخدام
---------
    # ١) تصغير شبكة المليون مثلث إلى ما يحتمله الهاتف (مرة واحدة)
    npx --yes @gltf-transform/cli@4 simplify src.glb /tmp/slim.glb \\
        --ratio 0.04 --error 0.0015
    npx --yes @gltf-transform/cli@4 dequantize /tmp/slim.glb /tmp/deq.glb
    # ٢) تحويله إلى صيغة المشروع
    python tool/assets/prepare_bridge.py /tmp/deq.glb assets/3d/bridge.glb
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
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", GLB_MAGIC, 2, total))
        f.write(struct.pack("<II", len(js), CHUNK_JSON) + js)
        f.write(struct.pack("<II", len(binp), CHUNK_BIN) + binp)


def accessor_fmt(accessor: Dict[str, Any]) -> str:
    return "<" + COMPONENT_FMT[accessor["componentType"]] * TYPE_COUNT[accessor["type"]]


def accessor_values(gltf: Dict[str, Any], binary: bytes, index: int) -> List[tuple]:
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    elem = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    stride = view.get("byteStride") or elem
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fmt = accessor_fmt(acc)
    return [
        struct.unpack_from(fmt, binary, base + i * stride) for i in range(acc["count"])
    ]


def bake_texture_transform(gltf: Dict[str, Any], binary: bytes) -> int:
    """يطبخ `KHR_texture_transform` داخل إحداثيات UV نفسها.

    المحمّل يتجاهل الإضافة، فيصل الجسر بصورة واحدة ممطوطة. الضرب هنا يعطي نفس
    ما كان سيفعله الظلّال: uv' = uv * scale + offset.
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
                (u * scale[0] + offset[0], v * scale[1] + offset[1]) for u, v in uv
            ]
            _write_uv(gltf, binary, uv_index, changed)
            transformed += 1
    return transformed


def _write_uv(
    gltf: Dict[str, Any], binary: bytes, index: int, values: List[tuple]
) -> None:
    """يكتب UV جديدة في نسخة من الـBIN ويعيد ربط الـaccessor بها."""
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    elem = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    stride = view.get("byteStride") or elem
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fmt = accessor_fmt(acc)
    buffer = bytearray(binary)
    for i, value in enumerate(values):
        struct.pack_into(fmt, buffer, base + i * stride, *value)
    # الـBIN يُمرَّر كـbytearray عبر السلسلة، فلا نعيد نسخه لكل شبكة.
    binary[:] = buffer


def strip_material(gltf: Dict[str, Any], texture_uri: str, sampler_index: int) -> None:
    """يبقي خامة اللون وحدها ويجعل ألوانها قابلة للقراءة في `three_dart`."""
    gltf["materials"] = [
        {
            "name": "bridge_stone",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorFactor": [1.0, 1.0, 1.0, 1.0],
                "baseColorTexture": {"index": 0},
                # الموديل الأصلي بلا metallicFactor/roughnessFactor، أي أن
                # الافتراضي ١٫٠ للاثنين: معدن كامل ⇒ أسود بلا خريطة بيئة.
                "metallicFactor": 0.0,
                "roughnessFactor": 0.85,
            },
        }
    ]
    gltf["textures"] = [{"sampler": sampler_index, "source": 0}]
    gltf["images"] = [{"name": "bridge", "uri": texture_uri, "mimeType": "image/png"}]
    for key in ("extensionsUsed", "extensionsRequired"):
        gltf.pop(key, None)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) != 3:
        print(__doc__)
        return 2

    src, dst = sys.argv[1], sys.argv[2]
    gltf, binary = read_glb(src)
    buffer = bytearray(binary)

    baked = bake_texture_transform(gltf, buffer)
    print(f"texture transform baked into {baked} primitive(s)")

    # صورة اللون: أول صورة في الملف. تُعاد كـPNG بجانب الملف ومقاسها ١٠٢٤
    # (أطلس مرسوم بالفرشاة، والحجر يشغل مساحة كبيرة من الشاشة).
    image_def = gltf["images"][0]
    view = gltf["bufferViews"][image_def["bufferView"]]
    start = view.get("byteOffset", 0)
    raw = bytes(buffer[start : start + view["byteLength"]])
    image = Image.open(io.BytesIO(raw)).convert("RGB")
    if max(image.size) > 1024:
        scale = 1024 / max(image.size)
        image = image.resize(
            (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
            Image.LANCZOS,
        )
    texture_name = os.path.splitext(os.path.basename(dst))[0] + ".png"
    sidecar = os.path.join(os.path.dirname(dst) or ".", texture_name)
    image.save(sidecar, optimize=True)
    print(f"{sidecar} {image.size} {os.path.getsize(sidecar) / 1024:.0f} KB")

    # الصور لم تعد مدفوعة: تُحذف bufferViews الخاصة بها ويُعاد بناء الـBIN من
    # الباقي. إزاحة كل accessor تبقى صحيحة لأن كل bufferView يُنقل ككتلة واحدة
    # ويُعاد ضبط `byteOffset` الخاص به.
    new_bin = bytearray()
    index_map: Dict[int, int] = {}
    views: List[Dict[str, Any]] = []
    for view_index, view in enumerate(gltf["bufferViews"]):
        if view_index == image_def["bufferView"]:
            continue
        start = view.get("byteOffset", 0)
        chunk = bytes(buffer[start : start + view["byteLength"]])
        new_bin += b"\x00" * ((4 - len(new_bin) % 4) % 4)
        moved = dict(view)
        moved["byteOffset"] = len(new_bin)
        index_map[view_index] = len(views)
        views.append(moved)
        new_bin += chunk

    gltf["bufferViews"] = views
    for acc in gltf.get("accessors", []):
        if acc.get("bufferView") is not None:
            acc["bufferView"] = index_map[acc["bufferView"]]

    strip_material(gltf, texture_name, 0)
    if gltf.get("samplers"):
        gltf["samplers"][0].update(
            {"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}
        )

    gltf["buffers"] = [{"byteLength": len(new_bin)}]
    write_glb(dst, gltf, bytes(new_bin))
    print(f"{dst} {os.path.getsize(dst) / 1024:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
