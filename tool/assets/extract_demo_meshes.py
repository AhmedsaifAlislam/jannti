"""Turns the FreeLowPoly demo scene into per-model GLBs + a Dart layout.

`PP_FreeLowPolyForest_v3.0_Demo_01.fbx` is the artist's own composition: 1228
placements of 24 unique meshes, all sharing one material that samples
`PP_Color_Palette.png` (256x256, an 8x8 chart of flat swatches).  The reference
render everybody compares against *is* that composition, so instead of
rebuilding the look by hand the scene is imported as data:

* every unique mesh becomes `assets/3d/nature/<name>.glb` with the palette
  beside it as a sidecar PNG (a model texture must never be embedded: the web
  loader chokes on its own blob wrapper, see AGENTS.md);
* every placement becomes one row in `lib/three/nature_layout.dart`, carrying
  the original node matrix scaled uniformly.

Why instances and not one baked mesh: the file stores 24 geometries and repeats
them 1228 times, so it is 2.4 M vertices / 72 MB if flattened, but only ~2 MB
when the geometries are shared and cloned at runtime.

The conversion from FBX has to happen first, and FBX2glTF only finds the
palette when the FBX's relative texture path exists:

    FBX2glTF --binary --input PP_FreeLowPolyForest_v3.0_Demo_01.fbx --output demo.glb

    python tool/assets/extract_demo_meshes.py \\
        --demo-glb C:/temp/fbxwork/out/demo3.glb \\
        --palette assets/اضافي/PP_Color_Palette/PP_Color_Palette.png
"""

from __future__ import annotations

import argparse
import json
import math
import struct
from pathlib import Path

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942

# Output file name per source mesh. Lower-case and short: they are referenced
# from Dart and bundled one by one in pubspec.yaml.
NAMES = {
    "PP_Meadow_07": "meadow_a",
    "PP_Meadow_08": "meadow_b",
    "PP_Meadow_Path_05": "meadow_path",
    "PP_Lake_Ground_04": "lake_shore",
    "PP_Lake_Ground_Water_04": "lake_water",
    "PP_Forest_Mountain_Moss_01": "mountain_a",
    "PP_Forest_Mountain_Moss_02": "mountain_b",
    "PP_Birch_Tree_05": "birch_a",
    "PP_Birch_Tree_06": "birch_b",
    "PP_Tree_02": "tree_a",
    "PP_Tree_10": "tree_b",
    "PP_Rock_Moss_Grown_09": "rock_moss_a",
    "PP_Rock_Moss_Grown_11": "rock_moss_b",
    "PP_Rock_Pile_Forest_Moss_05": "rock_pile_a",
    "PP_Rock_Pile_Forest_Moss_10": "rock_pile_b",
    "PP_Grass_11": "grass_a",
    "PP_Grass_15": "grass_b",
}

# Meshes that make the ground itself: all of them, every instance.
TERRAIN = {
    "PP_Meadow_07",
    "PP_Meadow_08",
    "PP_Meadow_Path_05",
    "PP_Lake_Ground_04",
    "PP_Lake_Ground_Water_04",
    "PP_Forest_Mountain_Moss_01",
    "PP_Forest_Mountain_Moss_02",
}

# Scenery along the rim. The garden's own trees are the reward models, so the
# demo's forest is kept only as a thin silhouette line at the mountains' feet
# and never in the middle where the player plants.
EDGE_TREES = {"PP_Birch_Tree_05", "PP_Birch_Tree_06", "PP_Tree_02", "PP_Tree_10"}
EDGE_ROCKS = {
    "PP_Rock_Moss_Grown_09",
    "PP_Rock_Moss_Grown_11",
    "PP_Rock_Pile_Forest_Moss_05",
    "PP_Rock_Pile_Forest_Moss_10",
}
EDGE_GRASS = {"PP_Grass_11", "PP_Grass_15"}

# Extra uniform scale per family, applied around each instance's own origin.
# The demo's trees are 8 m at scale 1; at the island's 1.95x they would be 16 m
# and dwarf the 3-9 m reward palms, so they come down to a background silhouette.
FAMILY_SCALE = {"tree": 0.52, "rock": 0.75, "grass": 0.85}


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


def read_vec(binary: bytes, doc: dict, index: int, components: int) -> list[tuple]:
    accessor = doc["accessors"][index]
    view = doc["bufferViews"][accessor["bufferView"]]
    base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride") or 4 * components
    fmt = "<" + "f" * components
    return [
        struct.unpack_from(fmt, binary, base + i * stride)
        for i in range(accessor["count"])
    ]


def read_indices(binary: bytes, doc: dict, index: int) -> list[int]:
    accessor = doc["accessors"][index]
    view = doc["bufferViews"][accessor["bufferView"]]
    size = {5121: 1, 5123: 2, 5125: 4}[accessor["componentType"]]
    fmt = {1: "B", 2: "H", 4: "I"}[size]
    base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return list(struct.unpack_from("<" + fmt * accessor["count"], binary, base))


def node_matrix(node: dict) -> list[float]:
    """glTF node matrix, column-major, 16 floats."""
    if "matrix" in node:
        return [float(v) for v in node["matrix"]]
    tx, ty, tz = node.get("translation", [0, 0, 0])
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    # column 0
    c0 = (
        (1 - 2 * (y * y + z * z)) * sx,
        (2 * (x * y + z * w)) * sx,
        (2 * (x * z - y * w)) * sx,
    )
    c1 = (
        (2 * (x * y - z * w)) * sy,
        (1 - 2 * (x * x + z * z)) * sy,
        (2 * (y * z + x * w)) * sy,
    )
    c2 = (
        (2 * (x * z + y * w)) * sz,
        (2 * (y * z - x * w)) * sz,
        (1 - 2 * (x * x + y * y)) * sz,
    )
    return [*c0, 0.0, *c1, 0.0, *c2, 0.0, tx, ty, tz, 1.0]


def mul(a: list[float], b: list[float]) -> list[float]:
    """Column-major 4x4 product a*b."""
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
    return out


def scale_matrix(s: float) -> list[float]:
    return [s, 0, 0, 0, 0, s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1]


def origin(m: list[float]) -> tuple[float, float, float]:
    return m[12], m[13], m[14]


def family_of(mesh_name: str) -> str:
    if mesh_name in TERRAIN:
        return "terrain"
    if mesh_name in EDGE_TREES:
        return "tree"
    if mesh_name in EDGE_ROCKS:
        return "rock"
    if mesh_name in EDGE_GRASS:
        return "grass"
    return "other"


def gather_instances(doc: dict) -> list[tuple[str, list[float]]]:
    nodes = doc["nodes"]
    meshes = doc["meshes"]
    roots = set(range(len(nodes)))
    for node in nodes:
        for child in node.get("children", []):
            roots.discard(child)

    found: list[tuple[str, list[float]]] = []

    def walk(index: int, parent: list[float]) -> None:
        node = nodes[index]
        world = mul(parent, node_matrix(node))
        if "mesh" in node:
            found.append((meshes[node["mesh"]]["name"], world))
        for child in node.get("children", []):
            walk(child, world)

    identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    for root in sorted(roots):
        walk(root, identity)
    return found


def base_at(matrix: list[float], x: float, z: float, yaw: float = 0.0) -> list[float]:
    """Same rotation/scale as [matrix], moved to (x, *, z) with an extra yaw."""
    out = list(matrix)
    out[12], out[13], out[14] = x, matrix[13], z
    if yaw:
        spin = [
            math.cos(yaw),
            0.0,
            -math.sin(yaw),
            0.0,
            math.sin(yaw),
            0.0,
            math.cos(yaw),
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0,
        ]
        out = mul(out, spin)
    return out


def build_rim(instances, sizes: dict[str, float]):
    """Hugs the foot of every mountain with the demo's own trees.

    Nothing from the demo's interior forest is reused as scenery: the middle of
    the island is the player's garden, and a second forest there would compete
    with the reward trees.  Every tree is instead hung on the inner base of a
    mountain, so the silhouette line follows the ridge and the open meadow stays
    empty.
    """
    import random

    rng = random.Random(7)
    mountains = [
        (n, m)
        for n, m in instances
        if family_of(n) == "terrain" and n.startswith("PP_Forest_Mountain")
    ]
    trees = [(n, m) for n, m in instances if family_of(n) == "tree"]
    rocks = [(n, m) for n, m in instances if family_of(n) == "rock"]
    grass = [(n, m) for n, m in instances if family_of(n) == "grass"]
    unique = lambda items: {n: m for n, m in items}  # noqa: E731
    tree_types = list(unique(trees).items())
    rock_types = list(unique(rocks).items())
    grass_types = list(unique(grass).items())
    if not mountains or not tree_types:
        return []

    picked = []
    order = [
        ("tree", tree_types, 2),
        ("rock", rock_types, 1),
        ("grass", grass_types, 2),
    ]
    for family, source, per_mountain in order:
        placed = 0
        for index, (name, matrix) in enumerate(mountains):
            node_scale = math.sqrt(sum(matrix[i] ** 2 for i in (0, 1, 2)))
            footprint = sizes[name] * node_scale * 0.5
            inward = math.atan2(-matrix[14], -matrix[12])
            for k in range(per_mountain):
                pick = source[(index + k) % len(source)]
                angle = inward + rng.uniform(-0.55, 0.55)
                reach = footprint * rng.uniform(0.80, 1.02) * (1 + 0.22 * k)
                x = matrix[12] + math.cos(angle) * reach
                z = matrix[14] + math.sin(angle) * reach
                picked.append(
                    (pick[0], base_at(pick[1], x, z, rng.uniform(0, math.tau)))
                )
                placed += 1
        print(f"  {family:6s} at the foot of the mountains: {placed:3d}")
    return picked


def export_mesh(doc, binary, mesh_index: int, stem: str, out_dir: Path) -> dict:
    """Writes one GLB + palette PNG and returns the accessor bookkeeping."""
    mesh = doc["meshes"][mesh_index]
    primitives = mesh["primitives"]
    if len(primitives) != 1:
        raise SystemExit(f"{stem}: expected one primitive, got {len(primitives)}")
    primitive = primitives[0]
    attributes = primitive["attributes"]

    positions = read_vec(binary, doc, attributes["POSITION"], 3)
    normals = read_vec(binary, doc, attributes["NORMAL"], 3)
    uvs = read_vec(binary, doc, attributes["TEXCOORD_0"], 2)
    indices = read_indices(binary, doc, primitive["indices"])

    pos_bytes = b"".join(struct.pack("<fff", *p) for p in positions)
    nrm_bytes = b"".join(struct.pack("<fff", *n) for n in normals)
    uv_bytes = b"".join(struct.pack("<ff", *t) for t in uvs)
    idx_bytes = b"".join(struct.pack("<I", i) for i in indices)

    blob = bytearray()
    views = []
    cursors = {}
    for key, data in (
        ("POSITION", pos_bytes),
        ("NORMAL", nrm_bytes),
        ("TEXCOORD_0", uv_bytes),
        ("INDICES", idx_bytes),
    ):
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        cursors[key] = len(views) - 1
        blob += data
        blob += b"\x00" * (-len(blob) % 4)

    lo = [min(p[i] for p in positions) for i in range(3)]
    hi = [max(p[i] for p in positions) for i in range(3)]

    out_doc = {
        "asset": {"version": "2.0", "generator": "extract_demo_meshes.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": stem}],
        "meshes": [
            {
                "name": stem,
                "primitives": [
                    {
                        "attributes": {
                            "POSITION": 0,
                            "NORMAL": 1,
                            "TEXCOORD_0": 2,
                        },
                        "indices": 3,
                        "material": 0,
                    }
                ],
            }
        ],
        "materials": [
            {
                "name": f"{stem}_palette",
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "metallicFactor": 0.0,
                    "roughnessFactor": 1.0,
                },
                "doubleSided": True,
            }
        ],
        "textures": [{"sampler": 0, "source": 0}],
        "samplers": [
            {
                "magFilter": 9728,  # NEAREST: the atlas is flat swatches and any
                "minFilter": 9728,  # filtering bleeds the neighbouring colour in.
                "wrapS": 33071,
                "wrapT": 33071,
            }
        ],
        "images": [{"uri": f"{stem}.png"}],
        "accessors": [
            {
                "bufferView": cursors["POSITION"],
                "componentType": 5126,
                "count": len(positions),
                "type": "VEC3",
                "min": lo,
                "max": hi,
            },
            {
                "bufferView": cursors["NORMAL"],
                "componentType": 5126,
                "count": len(normals),
                "type": "VEC3",
            },
            {
                "bufferView": cursors["TEXCOORD_0"],
                "componentType": 5126,
                "count": len(uvs),
                "type": "VEC2",
            },
            {
                "bufferView": cursors["INDICES"],
                "componentType": 5125,
                "count": len(indices),
                "type": "SCALAR",
            },
        ],
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }

    write_glb(out_dir / f"{stem}.glb", out_doc, bytes(blob))
    return {"verts": len(positions), "tris": len(indices) // 3}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo-glb", required=True, type=Path)
    parser.add_argument("--palette", required=True, type=Path)
    parser.add_argument("--out", default=Path("assets/3d/nature"), type=Path)
    parser.add_argument(
        "--dart", default=Path("lib/three/nature_layout.dart"), type=Path
    )
    parser.add_argument("--scale", default=1.95, type=float)
    args = parser.parse_args()

    doc, binary = read_glb(args.demo_glb)
    instances = gather_instances(doc)
    print(f"source: {len(instances)} placements of {len(doc['meshes'])} meshes")

    terrain = [(name, m) for name, m in instances if family_of(name) == "terrain"]
    # Bounding box per mesh, used to hang the rim trees on the inner base of a
    # mountain and to measure the island's real silhouette.
    extents = {}
    for mesh in doc["meshes"]:
        accessor = doc["accessors"][mesh["primitives"][0]["attributes"]["POSITION"]]
        extents[mesh["name"]] = (
            accessor["min"],
            accessor["max"],
            max(
                accessor["max"][0] - accessor["min"][0],
                accessor["max"][2] - accessor["min"][2],
            ),
        )

    rim = build_rim(instances, {k: v[2] for k, v in extents.items()})
    keep = terrain + rim
    print(f"kept {len(keep)} placements")

    args.out.mkdir(parents=True, exist_ok=True)
    palette = args.palette.read_bytes()
    mesh_id_of = {mesh["name"]: i for i, mesh in enumerate(doc["meshes"])}
    stems: list[str] = []
    stats = {}
    for source_name in sorted({name for name, _ in keep}):
        stem = NAMES[source_name]
        stems.append(stem)
        stats[stem] = export_mesh(doc, binary, mesh_id_of[source_name], stem, args.out)
        (args.out / f"{stem}.png").write_bytes(palette)
        print(f"  {stem:14s} {stats[stem]['verts']:6d} v  {stats[stem]['tris']:6d} tri")
    stem_index = {stem: i for i, stem in enumerate(stems)}

    global_scale = scale_matrix(args.scale)
    placed = []
    for name, matrix in keep:
        family = family_of(name)
        local = matrix
        extra = FAMILY_SCALE.get(family)
        if extra:
            local = mul(local, scale_matrix(extra))
        placed.append((name, mul(global_scale, local)))

    def corners(name: str, world: list[float]):
        lo, hi, _ = extents[name]
        return [
            (
                world[0] * cx + world[4] * cy + world[8] * cz + world[12],
                world[1] * cx + world[5] * cy + world[9] * cz + world[13],
                world[2] * cx + world[6] * cy + world[10] * cz + world[14],
            )
            for cx in (lo[0], hi[0])
            for cy in (lo[1], hi[1])
            for cz in (lo[2], hi[2])
        ]

    # The demo's origin sits halfway up the mountains: its meadow surface is at
    # y ≈ -13.4. Shift everything so the grass is the zero plane the rest of
    # the app measures against, and the lake surface lands just below it.
    tops = sorted(
        max(point[1] for point in corners(name, world))
        for name, world in placed
        if name.startswith("PP_Meadow")
    )
    shift = -tops[len(tops) // 2]
    rows = []
    for name, world in placed:
        world = list(world)
        world[13] += shift
        rows.append([stem_index[NAMES[name]]] + [round(v, 5) for v in world])
    print(f"ground shift +{shift:.2f} (meadow median top {-shift:.2f})")

    # Lake discs for the planting rules: centre, water radius and shore radius.
    lakes = []
    for name, matrix in instances:
        if name != "PP_Lake_Ground_04":
            continue
        local_radius = 0.5 * extents[name][2]
        node_scale = math.sqrt(sum(matrix[i] ** 2 for i in (0, 1, 2)))
        shore = local_radius * node_scale * args.scale
        lakes.append(
            [
                round(matrix[12] * args.scale, 2),
                round(matrix[14] * args.scale, 2),
                round(shore * 0.86, 2),
                round(shore, 2),
            ]
        )

    water_y = sorted(
        max(point[1] for point in corners(name, world)) + shift
        for name, world in placed
        if name == "PP_Lake_Ground_Water_04"
    )

    # Mountain footprints: the planting rules may not put a palm inside a rock.
    mountains = []
    for name, world in placed:
        if not name.startswith("PP_Forest_Mountain"):
            continue
        node_scale = math.sqrt(sum(world[i] ** 2 for i in (0, 1, 2)))
        mountains.append(
            [
                round(world[12], 2),
                round(world[14], 2),
                round(0.5 * extents[name][2] * node_scale * 0.88, 2),
            ]
        )

    xs = [point[0] for name, world in placed for point in corners(name, world)]
    zs = [point[2] for name, world in placed for point in corners(name, world)]
    half_w = max(abs(min(xs)), abs(max(xs))) + 1.5
    half_d = max(abs(min(zs)), abs(max(zs))) + 1.5

    lines = [
        "// GENERATED — do not edit by hand.",
        "// `python tool/assets/extract_demo_meshes.py --demo-glb <glb> --palette <png>`",
        "//",
        "// The FreeLowPolyForest demo scene, imported as data: one GLB per unique",
        "// mesh, one row per placement. Cloning a template is what keeps this at",
        "// ~2 MB instead of the 72 MB a flattened copy would cost.",
        "",
        "/// One GLB per unique mesh of the demo scene.",
        "const List<String> kNatureMeshPaths = <String>[",
        *[f"  'assets/3d/nature/{stem}.glb'," for stem in stems],
        "];",
        "",
        "/// Placement matrix per copy, column-major (glTF order).",
        "const List<List<double>> kNatureInstances = <List<double>>[",
    ]
    for row in rows:
        numbers = ", ".join(f"{v:g}" for v in row[1:])
        lines.append(f"  <double>[{row[0]}, {numbers}],")
    lines += [
        "];",
        "",
        "/// Lakes as `[centreX, centreZ, waterRadius, shoreRadius]` in world",
        "/// units — the planting rules refuse the shore disc, so nothing grows",
        "/// knee-deep in the water or on the raised bank around it.",
        "const List<List<double>> kNatureLakes = <List<double>>[",
        *[f"  <double>[{lake[0]}, {lake[1]}, {lake[2]}, {lake[3]}]," for lake in lakes],
        "];",
        "",
        "/// Mountains as `[centreX, centreZ, footprintRadius]`: a palm planted",
        "/// inside one of these would stand in the rock.",
        "const List<List<double>> kNatureMountains = <List<double>>[",
        *[
            f"  <double>[{mountain[0]}, {mountain[1]}, {mountain[2]}],"
            for mountain in mountains
        ],
        "];",
        "",
        f"/// Water surface of both lakes, measured from the shifted scene.",
        f"const double kNatureWaterY = {water_y[len(water_y) // 2]:.2f};",
        "",
        f"/// Half extents of the imported island: {half_w * 2:.0f} x {half_d * 2:.0f} units.",
        f"const double kNatureHalfWidth = {half_w:.1f};",
        f"const double kNatureHalfDepth = {half_d:.1f};",
        "",
    ]
    args.dart.write_text("\n".join(lines), encoding="utf-8")
    total = sum(s["tris"] for s in stats.values())
    print(f"meshes {len(stems)} unique / {total} triangles, layout -> {args.dart}")


if __name__ == "__main__":
    main()
