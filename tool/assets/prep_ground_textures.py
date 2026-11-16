#!/usr/bin/env python3
"""Rebuild the two ground maps that the stylized scene ships with.

Why this exists
---------------
The noon palette lights the ground with a warm sun (`0xFFE082` at 1.35) plus a
green ambient (`0x4A6B56`). Every albedo therefore renders ~1.2x brighter in
red/green and ~0.8x in blue, so a saturated cyan tile turns emerald and a lime
tile turns lemon. The fix has to happen in the pixels: the maps are recoloured
to *cool* targets so the warm light lands them on the intended hue.

`river_water.png`
    `River Material.PNG` (the hand-painted master, kept next to it but not
    bundled) is a 2048 tile of saturated cyan with pale foam curls — mean
    (26, 205, 217). Grading it through a luminance ramp replaces the cyan with a
    river blue while keeping the foam and the depth variation. Tiling is 4x24 on
    the 30x184 river, so one tile is ~7.5 world units wide.

`grass_rocks.png`
    FreeStylized `grass_with_rocks_01` (1K, CC0-style free tile):
        https://pub-a67cbe8efa4c4ce3b56e525e91e4c311.r2.dev/Textures/1k/grass_with_rocks_01_1k.zip
    Its painted colour map is lime-green with bright stones — mean (72, 144,
    79). Desaturating it towards stone grey and cooling the balance gives the
    riverbank a damp verge instead of a glowing yellow strip.

Usage
-----
    python tool/assets/prep_ground_textures.py \\
        --rocks-source /path/to/grass_with_rocks_01_color_1k.png

`--rocks-source` may be omitted when `grass_rocks.png` is already correct; the
water map alone is then rebuilt.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
TEXTURES = ROOT / "assets" / "3d" / "textures"

# Hues picked so that the warm sun lands them on the intended colour. Anything
# neutral in the file becomes amber on screen, so "grey stone" has to be blue.
# The top of the ramp stops well short of white: the tile has hundreds of small
# foam bubbles, and at 15 world units per tile a pure-white one is a 1 px spark
# that aliases into noise (three_dart cannot build mip levels for a DataTexture).
WATER_RAMP = [
    (0, (24, 50, 82)),
    (115, (30, 60, 94)),
    (150, (44, 82, 116)),
    (200, (96, 132, 160)),
    (255, (156, 182, 198)),
]
WATER_TARGET_MEAN = (54, 92, 124)
WATER_BLUR = 1.6

ROCKS_TARGET_MEAN = (96, 104, 132)
ROCKS_SATURATION = 0.38


def gradient_map(
    values: np.ndarray, stops: list[tuple[int, tuple[int, int, int]]]
) -> np.ndarray:
    """Map a 0..255 luminance array through a colour ramp."""
    xs = np.array([s[0] for s in stops], dtype=np.float32)
    out = np.empty(values.shape + (3,), dtype=np.float32)
    for channel in range(3):
        ys = np.array([s[1][channel] for s in stops], dtype=np.float32)
        out[..., channel] = np.interp(values, xs, ys)
    return out


def gain_to_mean(
    rgb: np.ndarray, target: tuple[int, int, int]
) -> tuple[np.ndarray, tuple[float, float, float]]:
    mean = rgb.reshape(-1, 3).mean(axis=0)
    gains = tuple(min(1.6, target[i] / max(mean[i], 1.0)) for i in range(3))
    return rgb * np.asarray(gains, dtype=np.float32), gains  # type: ignore[return-value]


def build_water(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGB")
    image = image.resize((512, 512), Image.LANCZOS)
    image = image.filter(ImageFilter.GaussianBlur(WATER_BLUR))
    pixels = np.asarray(image, dtype=np.float32)
    luminance = 0.299 * pixels[..., 0] + 0.587 * pixels[..., 1] + 0.114 * pixels[..., 2]
    mapped = gradient_map(luminance, WATER_RAMP)
    mapped, gains = gain_to_mean(mapped, WATER_TARGET_MEAN)
    out = Image.fromarray(np.clip(mapped, 0, 255).astype(np.uint8), "RGB")
    out.save(destination, optimize=True)
    mean = np.asarray(out, dtype=np.float32).reshape(-1, 3).mean(axis=0)
    print(
        f"{destination.name}: 512x512 {destination.stat().st_size // 1024} KB "
        f"gain={tuple(round(g, 3) for g in gains)} "
        f"mean=({', '.join(str(round(v)) for v in mean)})"
    )


def build_rocks(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGB").resize((512, 512), Image.LANCZOS)
    image = ImageEnhance.Color(image).enhance(ROCKS_SATURATION)
    pixels = np.asarray(image, dtype=np.float32)
    pixels, gains = gain_to_mean(pixels, ROCKS_TARGET_MEAN)
    out = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    out.save(destination, optimize=True)
    mean = np.asarray(out, dtype=np.float32).reshape(-1, 3).mean(axis=0)
    print(
        f"{destination.name}: 512x512 {destination.stat().st_size // 1024} KB "
        f"gain={tuple(round(g, 3) for g in gains)} "
        f"mean=({', '.join(str(round(v)) for v in mean)})"
    )


def build_grass(destination: Path) -> None:
    """Flatten the big brush swirls in `grass_base.png` in place.

    The FreeStylized tile has large C-shaped strokes that, once tiled, read as
    concentric arcs sweeping across the whole meadow. Removing the low
    frequencies (and keeping 30 % of them so the field is not dead flat) turns
    those arcs into fine blade texture. Run once per fresh map: it is not
    idempotent.
    """
    image = Image.open(destination).convert("RGB")
    pixels = np.asarray(image, dtype=np.float32)
    blurred = np.asarray(image.filter(ImageFilter.GaussianBlur(20)), dtype=np.float32)
    mean = pixels.reshape(-1, 3).mean(axis=0)
    flat = mean + (pixels - blurred) * 1.2 + (blurred - mean) * 0.3
    out = Image.fromarray(np.clip(flat, 0, 255).astype(np.uint8), "RGB")
    out.save(destination, optimize=True)
    after = np.asarray(out, dtype=np.float32).reshape(-1, 3).mean(axis=0)
    print(
        f"{destination.name}: {out.size} {destination.stat().st_size // 1024} KB "
        f"flattened mean=({', '.join(str(round(v)) for v in after)})"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--water-source",
        type=Path,
        default=TEXTURES / "River Material.PNG",
        help="hand-painted water master (default: assets/3d/textures/River Material.PNG)",
    )
    parser.add_argument(
        "--rocks-source",
        type=Path,
        default=None,
        help="grass_with_rocks_01 colour map; omitted leaves grass_rocks.png alone",
    )
    parser.add_argument(
        "--flatten-grass",
        action="store_true",
        help="flatten grass_base.png in place (once per fresh map)",
    )
    args = parser.parse_args()

    build_water(args.water_source, TEXTURES / "river_water.png")
    if args.rocks_source is not None:
        build_rocks(args.rocks_source, TEXTURES / "grass_rocks.png")
    if args.flatten_grass:
        build_grass(TEXTURES / "grass_base.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
