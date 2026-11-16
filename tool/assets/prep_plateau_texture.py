#!/usr/bin/env python3
"""Grade the plateau's colour map to the meadow palette.

Why this exists
---------------
`assets/هضبة.glb` ships a `gltfpack` atlas whose grass patches are lime
(139, 154, 27) — almost no blue channel. The meadow's own map averages
(136, 147, 123), and the noon sun (0xFFE082) cuts blue by half on top of that,
so the raw map renders as neon chartreuse while the meadow stays emerald. That
is a colour-grade problem, not a lighting one: `day_palette.dart` is frozen by
test, and the ground maps were already pre-corrected in the file
(`prep_ground_textures.py`), so the plateau gets the same treatment.

What it does
------------
Only the grass patches are touched. Each pixel is scored against a lime hue
window in HSV; the score is soft so the edges of a patch do not leave a rim.
Grass pixels are cross-faded into the meadow map (already tiled to the atlas
size), which brings the blue channel and the low-frequency variation with it,
and the result is multiplied by the meadow's own material colour. The scene
multiplies its grass map by `0x2F8A4E`; baking that factor into the plateau
lets the model run at a white material, so the tan rock keeps its hue instead
of being tinted green by a global colour. Rock pixels — tan, hue ~0.08 — keep
their original colour, so the rim still reads as stone.

Run it after `prepare_model.py`, in place:
    python tool/assets/prep_plateau_texture.py assets/3d/plateau.png
"""

from __future__ import annotations

import argparse
import os

import numpy as np
from PIL import Image

DEFAULT_MEADOW = os.path.join(
    os.path.dirname(__file__), "..", "..", "assets", "3d", "textures", "grass_base.png"
)

# The meadow's material colour, with the blue channel lifted. The meadow is a
# flat plane; the plateau's top is blade geometry whose normals fan sideways,
# so at the same tint it rendered yellower than the meadow (B/G 0.31 against
# 0.43, measured on the device). The extra blue closes that gap and takes the
# lemon edge off the grass; the stone is outside the mask and keeps its tan.
MEADOW_TINT = (0x3E, 0xA3, 0xAD)

# The meadow map is 256 px and the scene tiles it every ~20 m. The plateau's
# grass area spans ~43 m of world, so one copy stretched over the atlas would
# come out twice as coarse as the meadow. Repeating it here — in image space,
# not in UV space — keeps the UV mapping (and therefore the stone rim) intact
# while restoring the blade density.
TILE = 2

# Hue window of the lime grass in the atlas. The rock band sits at 0.075–0.15
# with saturation ~0.55, the grass at 0.175–0.25 with saturation ~0.95, so the
# window below keeps the stone untouched.
HUE_LO = 0.16
HUE_HI = 0.27
HUE_FEATHER = 0.025
SAT_LO = 0.55
SAT_FEATHER = 0.12
MIX = 0.92


def grade(source: str, meadow: str, destination: str | None) -> None:
    atlas = Image.open(source).convert("RGB")
    meadow_src = Image.open(meadow).convert("RGB")
    tiled = Image.new("RGB", (meadow_src.width * TILE, meadow_src.height * TILE))
    for ty in range(TILE):
        for tx in range(TILE):
            tiled.paste(meadow_src, (tx * meadow_src.width, ty * meadow_src.height))
    meadow_img = tiled.resize(atlas.size, Image.LANCZOS)

    rgb = np.asarray(atlas).astype(np.float32) / 255.0
    tint = np.array(MEADOW_TINT, dtype=np.float32) / 255.0
    grass = np.asarray(meadow_img).astype(np.float32) / 255.0 * tint
    hsv = np.asarray(atlas.convert("HSV")).astype(np.float32) / 255.0
    hue, sat, _value = hsv[..., 0], hsv[..., 1], hsv[..., 2]

    hue_window = np.clip((HUE_HI - hue) / HUE_FEATHER, 0.0, 1.0) * np.clip(
        (hue - HUE_LO) / HUE_FEATHER, 0.0, 1.0
    )
    sat_window = np.clip((sat - SAT_LO) / SAT_FEATHER, 0.0, 1.0)
    mask = (hue_window * sat_window)[..., None] * MIX

    out = np.clip(rgb * (1.0 - mask) + grass * mask, 0.0, 1.0)
    pixels = (out * 255.0 + 0.5).astype(np.uint8)
    result = Image.fromarray(pixels, "RGB")

    target = destination or source
    # A JPEG sidecar keeps its own encoder settings; `save` would otherwise
    # fall back to quality 75 and undo the 88 the model pipeline wrote.
    if target.lower().endswith((".jpg", ".jpeg")):
        result.save(target, "JPEG", quality=90, subsampling=1, optimize=True)
    else:
        result.save(target)
    mean = pixels.reshape(-1, 3).mean(axis=0).round().astype(int)
    covered = float((mask[..., 0] > 0.02).mean()) * 100.0
    print(
        f"{target}: graded {covered:.0f}% of the atlas · mean "
        f"({mean[0]}, {mean[1]}, {mean[2]}) · {result.size[0]}px"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="plateau colour map written by prepare_model.py")
    parser.add_argument(
        "destination", nargs="?", default=None, help="defaults to in-place"
    )
    parser.add_argument(
        "--meadow", default=DEFAULT_MEADOW, help="ground grass map to borrow"
    )
    args = parser.parse_args()
    grade(args.source, args.meadow, args.destination)


if __name__ == "__main__":
    main()
