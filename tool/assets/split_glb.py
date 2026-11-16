#!/usr/bin/env python3
"""Split a GLB into one GLB per connected island (or per X-band of the sheet).

Why this exists
---------------
The art packs that reach this project are exported as a *sheet*: six palms in a
row, thirty garden props on a grid. The scene needs them one at a time, so the
mesh has to be cut into pieces that do not share vertices.

How
---
The geometry is never rewritten: every piece keeps the original vertex, normal
and UV accessors and only receives a smaller index buffer. That means a split
can never distort a model — the worst case is a stray island in the wrong file.

Two ways to group the geometry along X:

* islands (`--clusters` / `--groups-x`): each connected island goes to the band
  its bounding-box centre falls in. Cheapest, but a long island (a whole frond)
  can be dragged into the neighbouring plant because its *centre* moved.
* whole triangles (`--by-triangle`): each triangle goes to the band of its own
  centroid. Cut planes in the empty corridors between plants then cost a handful
  of triangles instead of a whole leaf, which is what a tightly packed sheet
  needs — the six palms interlock and any island whose centre sits on the wrong
  side of a cut leaves a floating frond behind.

Usage
-----
    python tool/assets/split_glb.py src.glb out_dir --clusters 6
    python tool/assets/split_glb.py src.glb out_dir --groups-x "0,0.3,0.6"
    python tool/assets/split_glb.py src.glb out_dir --by-triangle \\
        --groups-x "2901,5973,9100,12700"
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys
from typing import Any, Dict, List, Tuple

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
        raise ValueError(f"not a GLB: {path}")
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
        offset += 8 + chunk_len
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


def accessor_values(gltf: Dict[str, Any], binary: bytearray, index: int) -> List[tuple]:
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    elem = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    stride = view.get("byteStride") or elem
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fmt = "<" + COMPONENT_FMT[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    return [
        struct.unpack_from(fmt, binary, base + i * stride) for i in range(acc["count"])
    ]


def triangles(
    gltf: Dict[str, Any], binary: bytearray, primitive: Dict[str, Any]
) -> List[Tuple[int, int, int]]:
    """Returns the index triples, synthesising them when the mesh is not indexed."""
    if "indices" in primitive:
        flat = [v[0] for v in accessor_values(gltf, binary, primitive["indices"])]
    else:
        count = gltf["accessors"][primitive["attributes"]["POSITION"]]["count"]
        flat = list(range(count))
    return [(flat[i], flat[i + 1], flat[i + 2]) for i in range(0, len(flat) - 2, 3)]


class UnionFind:
    def __init__(self, n: int) -> None:
        self.parent = list(range(n))

    def find(self, a: int) -> int:
        while self.parent[a] != a:
            self.parent[a] = self.parent[self.parent[a]]
            a = self.parent[a]
        return a

    def union(self, a: int, b: int) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[rb] = ra


def islands(
    tris: List[Tuple[int, int, int]], vertex_count: int
) -> Dict[int, List[int]]:
    uf = UnionFind(vertex_count)
    for a, b, c in tris:
        uf.union(a, b)
        uf.union(a, c)
    groups: Dict[int, List[int]] = {}
    for i, (a, _b, _c) in enumerate(tris):
        groups.setdefault(uf.find(a), []).append(i)
    return groups


def bbox_of(
    tris: List[Tuple[int, int, int]], group: List[int], positions: List[tuple]
) -> Tuple[list, list]:
    lo = [1e30] * 3
    hi = [-1e30] * 3
    for t in group:
        for vertex in tris[t]:
            p = positions[vertex]
            for axis in range(3):
                lo[axis] = min(lo[axis], p[axis])
                hi[axis] = max(hi[axis], p[axis])
    return lo, hi


def _cuts_from(args: argparse.Namespace, centres: List[float]) -> List[float]:
    if args.groups_x:
        return [float(v) for v in args.groups_x.split(",")]
    if args.clusters:
        lo_c, hi_c = min(centres), max(centres)
        step = (hi_c - lo_c) / args.clusters
        return [lo_c + step * (i + 1) for i in range(args.clusters - 1)]
    return []


def plan_by_islands(args: argparse.Namespace, tris, positions):
    """One bucket per band, whole islands only."""
    groups = islands(tris, len(positions))
    items = []
    for root, tri_ids in groups.items():
        lo, hi = bbox_of(tris, tri_ids, positions)
        items.append({"root": root, "tris": tri_ids, "lo": lo, "hi": hi})
    print(f"{len(items)} islands")

    if args.drop_below is not None:
        full_lo = min(item["lo"][1] for item in items)
        full_hi = max(item["hi"][1] for item in items)
        cut = full_lo + (full_hi - full_lo) * args.drop_below
        kept = [item for item in items if item["hi"][1] > cut]
        print(f"dropped {len(items) - len(kept)} islands below y={cut:.0f}")
        items = kept

    items.sort(key=lambda item: (item["lo"][0] + item["hi"][0]) / 2)

    if args.anchors:
        # A sheet can pack its plants so tightly that their crowns interlock and
        # no vertical plane falls in empty space: cutting by bbox centre then
        # hands half a frond to the neighbour and leaves it floating. Every
        # island here grew from a trunk, though, so the island belongs to the
        # trunk it is physically closest to — measured against the trunk's
        # vertical segment, not against its foot. A frond tip that hangs over the
        # next plant is still far from that plant's trunk, while a grass tuft is
        # near the foot it stands on.
        anchors = []
        for part in args.anchors.split(","):
            values = [float(v) for v in part.split(":")]
            anchors.append(
                (values[0], values[1], values[2] if len(values) > 2 else 1e9)
            )

        def gap2(vertex: int, anchor) -> float:
            ax, az, top = anchor
            dx = positions[vertex][0] - ax
            dz = positions[vertex][2] - az
            y = positions[vertex][1]
            dy = 0.0 if 0.0 <= y <= top else min(abs(y), abs(y - top))
            return dx * dx + dz * dz + dy * dy

        slots: List[List[dict]] = [[] for _ in anchors]
        for item in items:
            verts = sorted({v for t in item["tris"] for v in tris[t]})
            best = 0
            best_d = None
            for index, anchor in enumerate(anchors):
                d = min(gap2(v, anchor) for v in verts)
                if best_d is None or d < best_d:
                    best_d = d
                    best = index
            slots[best].append(item)
        plan = []
        for bucket in slots:
            if not bucket:
                plan.append(([], None, None))
                continue
            tri_ids = sorted(t for item in bucket for t in item["tris"])
            lo = [min(item["lo"][axis] for item in bucket) for axis in range(3)]
            hi = [max(item["hi"][axis] for item in bucket) for axis in range(3)]
            plan.append((tri_ids, lo, hi))
        return plan

    cuts = _cuts_from(args, [(item["lo"][0] + item["hi"][0]) / 2 for item in items])

    buckets: List[List[dict]] = [[] for _ in range(len(cuts) + 1)]
    for item in items:
        centre = (item["lo"][0] + item["hi"][0]) / 2
        slot = 0
        while slot < len(cuts) and centre > cuts[slot]:
            slot += 1
        buckets[slot].append(item)

    plan = []
    for bucket in buckets:
        if not bucket:
            plan.append(([], None, None))
            continue
        tri_ids = sorted(t for item in bucket for t in item["tris"])
        lo = [min(item["lo"][axis] for item in bucket) for axis in range(3)]
        hi = [max(item["hi"][axis] for item in bucket) for axis in range(3)]
        plan.append((tri_ids, lo, hi))
    return plan


def plan_by_triangle(args: argparse.Namespace, tris, positions):
    """One bucket per band, decided per triangle centroid.

    A triangle that straddles a cut still lands in exactly one band (the one its
    centroid is in), so the seam is a one-triangle-wide ragged edge rather than a
    missing frond.

    `--drop-straddling` goes one step further and removes every island that
    crosses a cut. A leaf card is a whole island, so cutting it leaves a sliver
    hanging next to the *other* plant's crown with nothing holding it up; the
    sliver is far more noticeable than the shortened frond the drop costs.
    """
    centroids = [
        (positions[a][0] + positions[b][0] + positions[c][0]) / 3 for a, b, c in tris
    ]
    cuts = _cuts_from(args, centroids)

    dropped = set()
    if args.drop_straddling and cuts:
        for tri_ids in islands(tris, len(positions)).values():
            lo, hi = bbox_of(tris, tri_ids, positions)
            if any(lo[0] < cut < hi[0] for cut in cuts):
                dropped.update(tri_ids)
        print(f"dropped {len(dropped)} triangles in islands that cross a cut")

    buckets: List[List[int]] = [[] for _ in range(len(cuts) + 1)]
    for index, centre in enumerate(centroids):
        if index in dropped:
            continue
        slot = 0
        while slot < len(cuts) and centre > cuts[slot]:
            slot += 1
        buckets[slot].append(index)

    plan = []
    for bucket in buckets:
        if not bucket:
            plan.append(([], None, None))
            continue
        used = {v for index in bucket for v in tris[index]}
        lo = [min(positions[v][axis] for v in used) for axis in range(3)]
        hi = [max(positions[v][axis] for v in used) for axis in range(3)]
        plan.append((bucket, lo, hi))
    return plan


def bbox_components(tri_ids: List[int], tris, positions, gap: float):
    """Groups the islands of one bucket by touching bounding boxes.

    Art sheets regularly leave a stray card floating next to the neighbouring
    plant, and after a cut it lands in the wrong file with nothing around it. The
    plant itself is one dense mass — its leaves overlap each other — so these
    outliers show up as tiny separate components.
    """
    local = [tris[i] for i in tri_ids]
    count = max((v for t in local for v in t), default=0) + 1
    groups = islands(local, count)

    boxes = []
    for ids in groups.values():
        lo = [
            min(min(positions[v][axis] for v in local[i]) for i in ids)
            for axis in range(3)
        ]
        hi = [
            max(max(positions[v][axis] for v in local[i]) for i in ids)
            for axis in range(3)
        ]
        boxes.append({"ids": ids, "lo": lo, "hi": hi})
    boxes.sort(key=lambda box: box["lo"][0])

    parent = list(range(len(boxes)))

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for pos, box in enumerate(boxes):
        a = box
        for j in range(pos + 1, len(boxes)):
            b = boxes[j]
            if b["lo"][0] > a["hi"][0] + gap:
                break
            if all(
                a["hi"][axis] + gap >= b["lo"][axis]
                and b["hi"][axis] + gap >= a["lo"][axis]
                for axis in range(3)
            ):
                ra, rb = find(pos), find(j)
                if ra != rb:
                    parent[rb] = ra

    merged: Dict[int, List[int]] = {}
    for index, box in enumerate(boxes):
        merged.setdefault(find(index), []).extend(box["ids"])
    return [[tri_ids[i] for i in ids] for ids in merged.values()]


def in_drop_box(tri: Tuple[int, int, int], positions, boxes) -> bool:
    centre = [
        (positions[tri[0]][axis] + positions[tri[1]][axis] + positions[tri[2]][axis])
        / 3
        for axis in range(3)
    ]
    for lo, hi in boxes:
        if all(lo[axis] <= centre[axis] <= hi[axis] for axis in range(3)):
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("output_dir")
    parser.add_argument(
        "--prefix", default=None, help="output name prefix (default: source stem)"
    )
    parser.add_argument(
        "--clusters", type=int, default=0, help="group islands into N clusters along X"
    )
    parser.add_argument(
        "--min-tris", type=int, default=8, help="islands smaller than this are dropped"
    )
    parser.add_argument("--groups-x", default=None, help="comma-separated X cut points")
    parser.add_argument(
        "--drop-below",
        type=float,
        default=None,
        help="drop islands whose max Y is below this, as a fraction of the full height",
    )
    parser.add_argument(
        "--by-triangle",
        action="store_true",
        help="assign each triangle by its own centroid instead of each island by its centre",
    )
    parser.add_argument(
        "--drop-straddling",
        action="store_true",
        help="with --by-triangle: drop every island that crosses a cut, so no sliced leaf"
        " is left dangling next to the neighbouring plant",
    )
    parser.add_argument(
        "--keep-components",
        type=float,
        default=0.0,
        metavar="SHARE",
        help="drop detached fragments smaller than SHARE of the piece (0.005 = 0.5%%)",
    )
    parser.add_argument(
        "--component-gap",
        type=float,
        default=0.0,
        help="how close two islands must be to count as attached (source units)",
    )
    parser.add_argument(
        "--drop-box",
        action="append",
        metavar="x0,x1,y0,y1,z0,z1",
        help="drop triangles whose centroid falls in this box; repeatable, and only for"
        " leftovers a human has confirmed by eye",
    )
    parser.add_argument(
        "--anchors",
        default=None,
        help="comma-separated trunk axes 'x:z:top'; each island goes to the trunk it is "
        "closest to (use instead of --groups-x for interlocked sheets)",
    )
    args = parser.parse_args()

    gltf, binary = read_glb(args.source)
    mesh = gltf["meshes"][0]
    primitive = mesh["primitives"][0]
    positions = accessor_values(gltf, binary, primitive["attributes"]["POSITION"])
    tris = triangles(gltf, binary, primitive)
    print(f"{args.source}: {len(tris)} triangles, {len(positions)} vertices")

    if args.by_triangle:
        plan = plan_by_triangle(args, tris, positions)
    else:
        plan = plan_by_islands(args, tris, positions)

    prefix = args.prefix or os.path.splitext(os.path.basename(args.source))[0]
    boxes = []
    for raw in args.drop_box or []:
        values = [float(v) for v in raw.split(",")]
        boxes.append(
            (
                [values[0], values[2], values[4]],
                [values[1], values[3], values[5]],
            )
        )

    for index, (tri_ids, _lo, _hi) in enumerate(plan, start=1):
        if not tri_ids:
            print(f"  {prefix}_{index}: empty, skipped")
            continue

        if boxes:
            before = len(tri_ids)
            tri_ids = [i for i in tri_ids if not in_drop_box(tris[i], positions, boxes)]
            if before != len(tri_ids):
                print(
                    f"  {prefix}_{index}: dropped {before - len(tri_ids)} triangles in boxes"
                )

        if args.keep_components:
            before = len(tri_ids)
            tri_ids = [
                i
                for comp in bbox_components(
                    tri_ids, tris, positions, args.component_gap
                )
                if len(comp) >= before * args.keep_components
                for i in comp
            ]
            if before != len(tri_ids):
                print(
                    f"  {prefix}_{index}: dropped {before - len(tri_ids)} triangles"
                    " in detached fragments"
                )

        used = {v for i in tri_ids for v in tris[i]}
        lo = [min(positions[v][axis] for v in used) for axis in range(3)]
        hi = [max(positions[v][axis] for v in used) for axis in range(3)]
        indices = [v for t in tri_ids for v in tris[t]]

        out_gltf = json.loads(json.dumps(gltf))
        out_binary = bytearray(binary)
        out_binary += b"\x00" * ((4 - len(out_binary) % 4) % 4)
        offset = len(out_binary)
        out_binary += struct.pack(f"<{len(indices)}I", *indices)

        out_gltf["bufferViews"].append(
            {"buffer": 0, "byteOffset": offset, "byteLength": len(indices) * 4}
        )
        out_gltf["accessors"].append(
            {
                "bufferView": len(out_gltf["bufferViews"]) - 1,
                "componentType": 5125,
                "count": len(indices),
                "type": "SCALAR",
            }
        )
        out_gltf["meshes"][0]["primitives"][0]["indices"] = (
            len(out_gltf["accessors"]) - 1
        )
        # The old index accessor and its view stay behind — gltf-transform prunes them.
        out_gltf["buffers"] = [{"byteLength": len(out_binary)}]

        # The POSITION accessor still carries the bounds of the whole sheet, and
        # `GLTFLoader` copies those straight into `geometry.boundingBox`. The
        # scene scales a model by that box, so leaving it would shrink this palm
        # to the size of the entire row. The referenced vertices all sit inside
        # the piece's box, so rewriting min/max is exact for what the file draws.
        position_index = out_gltf["meshes"][0]["primitives"][0]["attributes"][
            "POSITION"
        ]
        out_gltf["accessors"][position_index]["min"] = [float(v) for v in lo]
        out_gltf["accessors"][position_index]["max"] = [float(v) for v in hi]

        dst = os.path.join(args.output_dir, f"{prefix}_{index}.glb")
        write_glb(dst, out_gltf, bytes(out_binary))
        size = [round((hi[a] - lo[a]) / 16.383, 1) for a in range(3)]
        print(
            f"  {prefix}_{index}: {len(tri_ids)} tris, "
            f"size {size} (1/100 unit), x[{lo[0]:.0f}..{hi[0]:.0f}] y[{lo[1]:.0f}..{hi[1]:.0f}]"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
