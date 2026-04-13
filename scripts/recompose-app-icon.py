#!/usr/bin/env python3
"""
Пересобирает AppIcon: квадратный кроп по содержимому (тёмная область),
масштаб на 1024×1024, затем все размеры для .iconset и iconutil → .icns.

Запуск из корня пакета BrainAI:
  python3 scripts/recompose-app-icon.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "Resources" / "AppIcon.iconset"
ICNS_OUT = ROOT / "Resources" / "AppIcon.icns"
MASTER = ICONSET / "icon_512x512@2x.png"

# Размеры для macOS .iconset (имена файлов → сторона в пикселях)
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


def dark_bbox(im_rgb: Image.Image, threshold: int = 200) -> tuple[int, int, int, int]:
    """Bounding box пикселей заметно темнее типичного фона (~245)."""
    mask = im_rgb.convert("L").point(lambda p: 255 if p < threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        w, h = im_rgb.size
        return 0, 0, w - 1, h - 1
    x0, y0, x1, y1 = bbox
    return x0, y0, x1, y1


def square_crop_rect(
    w: int, h: int, x0: int, y0: int, x1: int, y1: int, pad_frac: float = 0.035
) -> tuple[int, int, int, int]:
    """Квадрат вокруг тёмного содержимого: небольшой отступ (~3.5%), чтобы на иконке
    графика занимала почти весь квадрат (без широких «полей» визуальной таблетки)."""
    cx = (x0 + x1) / 2.0
    cy = (y0 + y1) / 2.0
    bw, bh = x1 - x0 + 1, y1 - y0 + 1
    side = int(max(bw, bh) * (1.0 + 2 * pad_frac))
    side = max(side, max(bw, bh) + 8)
    side = min(side, min(w, h))
    half = side / 2.0
    l = int(round(cx - half))
    t = int(round(cy - half))
    r = l + side
    b = t + side
    if l < 0:
        r -= l
        l = 0
    if t < 0:
        b -= t
        t = 0
    if r > w:
        shift = r - w
        l -= shift
        r = w
    if b > h:
        shift = b - h
        t -= shift
        b = h
    l = max(0, l)
    t = max(0, t)
    r = min(w, r)
    b = min(h, b)
    # гарантируем квадрат
    cw, ch = r - l, b - t
    side = min(cw, ch)
    return l, t, l + side, t + side


def main() -> int:
    if not MASTER.is_file():
        print(f"Нет файла {MASTER}", file=sys.stderr)
        return 1

    im = Image.open(MASTER).convert("RGBA")
    w, h = im.size
    if w != h:
        print(f"Ожидался квадратный мастер, сейчас {w}×{h}", file=sys.stderr)
        return 1

    x0, y0, x1, y1 = dark_bbox(im.convert("RGB"))
    l, t, r, b = square_crop_rect(w, h, x0, y0, x1, y1)
    cropped = im.crop((l, t, r, b)).resize((1024, 1024), Image.Resampling.LANCZOS)

    ICONSET.mkdir(parents=True, exist_ok=True)
    for name, size in ICONSET_SIZES:
        out = cropped.resize((size, size), Image.Resampling.LANCZOS)
        out.save(ICONSET / name, format="PNG")

    subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS_OUT)],
        check=True,
    )
    print(f"OK → {ICNS_OUT} ({ICNS_OUT.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
