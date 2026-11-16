#!/usr/bin/env python3
"""Generates the tileable cliff map for the floating island's underside.

Why procedural
--------------
The shell under the meadow is built in code (`_buildIslandShell`): a stack of
rings that narrows to a point. No artist ever unwrapped it, so there is no
atlas to sample — the only thing that can make it read as rock is a seamless
map. Everything here is produced on a torus (distances wrapped in both axes),
so the U seam where the ring closes is invisible.

What it paints
--------------
* Slabs: a warped Voronoi grid. Each cell is bevel-shaded from its own distance
  field, which is what makes the wall read as chunky rock instead of a flat
  mosaic; the cell borders get a thin dark crack.
* Strata: wavy horizontal bands, so a vertical wall does not read as one slab.
* Grain: two octaves of value noise to break the fill at close range.

The map is deliberately cool grey. Noon light is `0xFFE082` — red kept, blue
cut in half — so a neutral map already renders warm tan. Painting it warm here
would double the effect and turn the cliff into a yellow wall, which is exactly
the mistake the ground maps had to be re-graded for.

Run once after editing:
    python tool/assets/prep_cliff_texture.py
"""

from __future__ import annotations

import argparse
import os

import numpy as np
from PIL import Image

SIZE = 512
CELLS_X = 13
CELLS_Y = 9
WARP = 0.022  # how far the slab grid wanders, in tile widths
SLAB_SEAM = 0.05  # fraction of a cell where the dark crack is drawn
STRATA = 5.0  # horizontal bands across the tile
GRAIN = 0.10

# Cool grey ramp. The blue channel is the highest on purpose; the noon sun
# removes half of it and leaves stone instead of sand.
DARK = np.array([84, 92, 112], dtype=np.float32)
LIGHT = np.array([198, 203, 216], dtype=np.float32)


def _value_noise(size: int, cells: int, rng: np.random.Generator) -> np.ndarray:
    """Smooth tileable noise: a coarse lattice, cosine-interpolated.

    The lattice index wraps with a modulo, so the right edge interpolates back
    into the left one and the map has no seam.
    """
    grid = rng.random((cells, cells)).astype(np.float32)

    def _axis() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        steps = np.linspace(0, cells, size, endpoint=False)
        base = np.floor(steps).astype(int)
        frac = steps - base
        frac = 0.5 - 0.5 * np.cos(frac * np.pi)  # ease between lattice points
        base %= cells
        return base, (base + 1) % cells, frac.astype(np.float32)

    x0, x1, fx = _axis()
    y0, y1, fy = _axis()

    # Bilinear blend over the four lattice corners, shape (size, size).
    top = grid[np.ix_(y0, x0)] * (1 - fx)[None, :] + grid[np.ix_(y0, x1)] * fx[None, :]
    bottom = (
        grid[np.ix_(y1, x0)] * (1 - fx)[None, :] + grid[np.ix_(y1, x1)] * fx[None, :]
    )
    return (top * (1 - fy)[:, None] + bottom * fy[:, None]).astype(np.float32)


def _warped_axis(
    size: int, rng: np.random.Generator, amount: float, vertical: bool = False
) -> np.ndarray:
    """A coordinate ramp bent by low-frequency noise, wrapped into 0..1."""
    bend = _value_noise(size, 5, rng)
    bend = bend[:, 0][:, None] if vertical else bend[0][None, :]
    if vertical:
        ramp = np.arange(size, dtype=np.float32)[:, None] / size
    else:
        ramp = np.arange(size, dtype=np.float32)[None, :] / size
    return (ramp + (bend - 0.5) * 2.0 * amount) % 1.0


def _voronoi(size: int, nx: int, ny: int, rng: np.random.Generator):
    """Nearest and second-nearest seed distance on a warped torus.

    Returns `(d1, d2, id)` so the caller can draw a crack where `d2 - d1` is
    small, tint each slab through `id`, and derive a bevel from `d1`.
    """
    seeds = []
    for gy in range(ny):
        for gx in range(nx):
            jitter_x = (gx + 0.15 + 0.7 * rng.random()) / nx
            jitter_y = (gy + 0.15 + 0.7 * rng.random()) / ny
            seeds.append((jitter_x, jitter_y))
    seeds = np.array(seeds, dtype=np.float32)

    xs = _warped_axis(size, rng, WARP)
    ys = _warped_axis(size, rng, WARP, vertical=True)

    d1 = np.full((size, size), 4.0, dtype=np.float32)
    d2 = np.full((size, size), 4.0, dtype=np.float32)
    cell = np.zeros((size, size), dtype=np.int32)

    for index, (sx, sy) in enumerate(seeds):
        dx = np.abs(xs - sx)
        dx = np.minimum(dx, 1.0 - dx)  # torus
        dy = np.abs(ys - sy)
        dy = np.minimum(dy, 1.0 - dy)
        dist = np.sqrt(dx * dx + dy * dy)

        closer = dist < d1
        d2 = np.where(closer, d1, np.minimum(d2, dist))
        d1 = np.where(closer, dist, d1)
        cell = np.where(closer, np.int32(index), cell)

    return d1, d2, cell


def build(size: int) -> Image.Image:
    rng = np.random.default_rng(20261113)

    d1, d2, cell = _voronoi(size, CELLS_X, CELLS_Y, rng)

    # Crack: 0 on a cell border, 1 inside the slab. Only the thin border is
    # used — a full bevel per cell turned the wall into reptile scales.
    span = SLAB_SEAM * (1.0 / min(CELLS_X, CELLS_Y))
    crack = np.clip((d2 - d1) / span, 0.0, 1.0)
    crack = crack * crack * (3 - 2 * crack)  # smoothstep

    # Broad bands: a sum of low integer frequencies, so the profile wraps and
    # the wall still reads as sediment instead of one tone.
    v = np.arange(size, dtype=np.float32) / size
    profile = np.zeros(size, dtype=np.float32)
    for wave, amp in ((2, 0.55), (3, 0.28), (5, 0.14), (8, 0.07)):
        profile += amp * np.sin(2.0 * np.pi * wave * v + rng.uniform(0, 2 * np.pi))
    profile = (profile - profile.min()) / max(1e-6, profile.max() - profile.min())
    bands = (0.80 + 0.40 * profile)[:, None]

    # Thin sediment lines: |sin| raised to a small power turns the band edges
    # into needles, which is what draws the layered look at a distance.
    phase = rng.uniform(0, 2 * np.pi)
    lines = np.abs(np.sin(2.0 * np.pi * STRATA * v + phase)) ** 0.18
    bands = bands * (1.0 - 0.42 * lines[:, None])

    # Each slab gets its own tone so the wall is not one flat grey.
    per_cell = rng.random(CELLS_X * CELLS_Y).astype(np.float32)
    slab_tone = 0.90 + 0.10 * per_cell[cell]

    grain = _value_noise(size, 28, rng) * 0.55 + _value_noise(size, 88, rng) * 0.45
    grain = 1.0 + (grain - 0.5) * 2.0 * GRAIN

    # Weathering: faint vertical streaks, constant down each column.
    streak = _value_noise(size, 48, rng)[0][None, :]
    streak = 1.0 + (streak - 0.5) * 0.14

    shade = bands * slab_tone * grain * streak * (0.32 + 0.68 * crack)
    t = np.clip((shade - 0.46) / 0.86, 0.0, 1.0)[..., None]

    rgb = DARK + (LIGHT - DARK) * t
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "destination",
        nargs="?",
        default=os.path.join(
            os.path.dirname(__file__),
            "..",
            "..",
            "assets",
            "3d",
            "textures",
            "cliff_rock.png",
        ),
    )
    parser.add_argument("--size", type=int, default=SIZE)
    args = parser.parse_args()

    image = build(args.size)
    image.save(args.destination, optimize=True)
    pixels = np.asarray(image).reshape(-1, 3).mean(axis=0).round().astype(int)
    print(
        f"{args.destination}: {image.size[0]}px · mean "
        f"({pixels[0]}, {pixels[1]}, {pixels[2]}) · "
        f"{os.path.getsize(args.destination) / 1024:.0f} KB"
    )


if __name__ == "__main__":
    main()
