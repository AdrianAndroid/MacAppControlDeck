#!/usr/bin/env python3
"""重建副屏「猫追老鼠」素材帧条。

用法（需要 Pillow）：

    python3 Docs/design/pet-chase-candidates/build_assets.py

输出（本目录）：
    cat_strip.png  20×16 一格 × 6 帧 = 120×16，右侧为正前方
    rat_strip.png  25×14 一格 × 3 帧 = 75×14，朝右

上游素材（下载后放到 same 目录，或按 URL 重新抓）：
    猫  https://opengameart.org/sites/default/files/cat%20sprite.zip        CC0
        cat sprite/catrunx4.gif   80×68，6 帧，紫底 #a475a0 为透明色
    鼠  https://opengameart.org/sites/default/files/mouse_1.png             CC-BY 3.0
        96×128 精灵表，3 列 × 4 行，每格 32×32；取第 2 行（y 32..64）= 朝右侧面

处理：
    猫  去紫底 → 6 帧取并集 bbox → 缩回 20×16 → 深灰 #383838 改暖橙 / #1c1c1c 改暗橙
    鼠  取第 2 行 3 格 → 并集 bbox → 裁 25×14

改完帧条后，把新的 base64 覆盖进
`Sources/MacAppControlDeck/Panel/Screen/index.html` 里
`--chase-cat` / `--chase-rat` 两个自定义属性（脚本最后会打印）。
"""

from pathlib import Path

from PIL import Image, ImageSequence

HERE = Path(__file__).resolve().parent

CAT_GIF = HERE / "catrunx4.gif"
RAT_SHEET = HERE / "mouse1.png"

CAT_BG = (164, 117, 160)
CAT_MAP = {
    (56, 56, 56): (240, 160, 92),
    (28, 28, 28): (184, 100, 42),
    (95, 160, 48): (110, 210, 90),
}


def union_bbox(frames):
    box = None
    for frame in frames:
        b = frame.getbbox()
        if not b:
            continue
        box = b if box is None else (
            min(box[0], b[0]), min(box[1], b[1]),
            max(box[2], b[2]), max(box[3], b[3]),
        )
    return box


def strip(frames, path):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        out.alpha_composite(frame, (i * w, 0))
    out.save(path)
    print(f"wrote {path.name} {out.size[0]}x{out.size[1]}  ({path.stat().st_size} B)")


def build_cat():
    image = Image.open(CAT_GIF)
    frames = []
    for raw in ImageSequence.Iterator(image):
        frame = raw.convert("RGBA")
        pixels = frame.load()
        for y in range(frame.height):
            for x in range(frame.width):
                r, g, b, a = pixels[x, y]
                if (r, g, b) == CAT_BG:
                    pixels[x, y] = (0, 0, 0, 0)
        frames.append(frame)

    box = union_bbox(frames)
    frames = [f.crop(box).resize((20, 16), Image.NEAREST) for f in frames]

    recolored = []
    for frame in frames:
        frame = frame.copy()
        pixels = frame.load()
        for y in range(frame.height):
            for x in range(frame.width):
                r, g, b, a = pixels[x, y]
                if a and (r, g, b) in CAT_MAP:
                    pixels[x, y] = CAT_MAP[(r, g, b)] + (a,)
        recolored.append(frame)
    strip(recolored, HERE / "cat_strip.png")


def build_rat():
    sheet = Image.open(RAT_SHEET).convert("RGBA")
    frames = [sheet.crop((i * 32, 32, i * 32 + 32, 64)) for i in range(3)]
    box = union_bbox(frames)
    frames = [frame.crop(box) for frame in frames]
    strip(frames, HERE / "rat_strip.png")


if __name__ == "__main__":
    build_cat()
    build_rat()
