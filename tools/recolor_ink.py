"""把漫画线稿（assets/ink）重映射到「都市传说解体中心」风的 5 阶色板。

输入是灰度线稿：黑线 / 灰阶阴影 / 近白填充。
输出保持 alpha，按亮度分段上色：墨黑 / 深青 / 中青 / 浅青 / 米白。
"""
import sys
from pathlib import Path

from PIL import Image

# 亮度分界与目标色（从暗到亮）
RAMP = [
    (0.10, (10, 20, 22)),      # 墨黑
    (0.45, (23, 73, 76)),      # 深青
    (0.72, (47, 127, 130)),    # 中青
    (0.88, (111, 179, 174)),   # 浅青
    (1.01, (242, 233, 216)),   # 米白
]


def remap(src: Image.Image) -> Image.Image:
    src = src.convert("RGBA")
    out = Image.new("RGBA", src.size)
    sp, op = src.load(), out.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a == 0:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            for cut, col in RAMP:
                if lum < cut:
                    op[x, y] = (col[0], col[1], col[2], a)
                    break
    return out


def main() -> None:
    src_dir = Path(sys.argv[1])
    dst_dir = Path(sys.argv[2])
    dst_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(src_dir.glob("*.png"))
    for p in files:
        if p.name in ("tone.png", "paper.png"):
            continue
        dst = dst_dir / p.name
        if dst.exists() and dst.stat().st_mtime > p.stat().st_mtime:
            continue
        remap(Image.open(p)).save(dst, optimize=True)
    print(f"recolored {len(files)} files -> {dst_dir}")


if __name__ == "__main__":
    main()
