#!/usr/bin/env python3
"""
Generate the BrainAI macOS app icon.

The Dock icon must read as a square brand mark. The previous source artwork had
a tall rounded device shape inside a 1024 px canvas, so it looked narrow in the
Dock. This script draws a full-square master image, produces the macOS iconset,
and compiles Resources/AppIcon.icns with iconutil.
"""
from __future__ import annotations

import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "Resources" / "AppIcon.iconset"
ICNS_OUT = ROOT / "Resources" / "AppIcon.icns"

ICONSET_SIZES: list[tuple[str, int]] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

ICNS_TYPES: dict[str, str] = {
    "icon_16x16.png": "ic04",
    "icon_16x16@2x.png": "ic11",
    "icon_32x32.png": "ic05",
    "icon_32x32@2x.png": "ic12",
    "icon_128x128.png": "ic07",
    "icon_128x128@2x.png": "ic13",
    "icon_256x256.png": "ic08",
    "icon_256x256@2x.png": "ic14",
    "icon_512x512.png": "ic09",
    "icon_512x512@2x.png": "ic10",
}


def blend(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_glow(
    base: Image.Image,
    center: tuple[int, int],
    radius: int,
    color: tuple[int, int, int],
    alpha: int,
) -> None:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    x, y = center
    g.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*color, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(radius // 2))
    base.alpha_composite(glow)


def draw_soft_line(
    base: Image.Image,
    points: list[tuple[int, int]],
    color: tuple[int, int, int],
    width: int,
) -> None:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.line(points, fill=(*color, 96), width=width * 3, joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(width))
    base.alpha_composite(glow)

    d = ImageDraw.Draw(base)
    d.line(points, fill=(*color, 230), width=width, joint="curve")


def draw_node(
    base: Image.Image,
    center: tuple[int, int],
    radius: int,
    fill: tuple[int, int, int],
) -> None:
    draw_glow(base, center, radius * 2, fill, 130)
    d = ImageDraw.Draw(base)
    x, y = center
    d.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*fill, 242))
    d.ellipse((x - radius, y - radius, x + radius, y + radius), outline=(210, 235, 255, 120), width=4)
    d.ellipse((x - radius // 2, y - radius // 2, x + radius // 5, y + radius // 5), fill=(255, 255, 255, 42))


def draw_document(base: Image.Image) -> None:
    d = ImageDraw.Draw(base)
    stroke = (80, 224, 198, 210)
    x0, y0, x1, y1 = 622, 572, 796, 824
    fold = 58
    pts = [(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1), (x0, y0)]

    draw_glow(base, (710, 706), 100, (36, 212, 188), 56)
    d.line(pts, fill=stroke, width=12, joint="curve")
    d.line([(x1 - fold, y0), (x1 - fold, y0 + fold), (x1, y0 + fold)], fill=(122, 176, 220, 150), width=10)
    d.polygon([(x1 - fold, y0), (x1 - fold, y0 + fold), (x1, y0 + fold)], fill=(116, 170, 210, 44))


def make_master() -> Image.Image:
    size = 1024
    im = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    px = im.load()

    top = (13, 16, 28)
    mid = (20, 24, 46)
    bottom = (11, 15, 31)
    for y in range(size):
        ty = y / (size - 1)
        row = blend(top, mid, min(ty * 1.4, 1.0)) if ty < 0.72 else blend(mid, bottom, (ty - 0.72) / 0.28)
        for x in range(size):
            dx = (x - size / 2) / (size / 2)
            dy = (y - size / 2) / (size / 2)
            vignette = max(0.0, min(1.0, 1.0 - 0.34 * math.sqrt(dx * dx + dy * dy)))
            px[x, y] = (*tuple(int(c * vignette) for c in row), 255)

    draw_glow(im, (512, 500), 270, (55, 101, 242), 55)
    draw_glow(im, (594, 548), 230, (31, 210, 181), 48)

    violet = (119, 102, 255)
    blue = (101, 158, 255)
    teal = (49, 219, 190)

    draw_soft_line(im, [(276, 636), (304, 430), (500, 292), (716, 370), (776, 600)], violet, 11)
    draw_soft_line(im, [(345, 314), (472, 333), (558, 485), (570, 625), (670, 688)], blue, 12)
    draw_soft_line(im, [(282, 638), (424, 760), (592, 654), (646, 562), (740, 520)], teal, 12)

    draw_node(im, (352, 310), 62, (124, 104, 255))
    draw_node(im, (558, 494), 58, (45, 222, 188))
    draw_node(im, (704, 356), 44, (134, 123, 255))
    draw_node(im, (336, 648), 40, (128, 117, 255))

    draw_document(im)

    d = ImageDraw.Draw(im)
    d.rectangle((18, 18, size - 18, size - 18), outline=(165, 190, 232, 38), width=4)
    d.rectangle((44, 44, size - 44, size - 44), outline=(255, 255, 255, 16), width=2)
    return im


def main() -> int:
    master = make_master()
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True, exist_ok=True)
    for name, size in ICONSET_SIZES:
        resized = master.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
        resized.save(ICONSET / name, format="PNG")

    chunks = []
    for name, _ in ICONSET_SIZES:
        data = (ICONSET / name).read_bytes()
        chunk_type = ICNS_TYPES[name].encode("ascii")
        chunk_size = 8 + len(data)
        chunks.append(chunk_type + chunk_size.to_bytes(4, "big") + data)

    body = b"".join(chunks)
    ICNS_OUT.write_bytes(b"icns" + (8 + len(body)).to_bytes(4, "big") + body)
    print(f"OK -> {ICNS_OUT} ({ICNS_OUT.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
