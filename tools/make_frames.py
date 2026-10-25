#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""_make_frames.py — 逐帧烘焙角色（取代部件式 rig）
与部件式的区别：
  部件式 = 6 张图在运行时按关节旋转 → 本质是「纸片人转关节」
  逐帧式 = 每一帧按「关节角度」重新画四肢像素 → 每帧形状都不同，才是「画」出来的

画布 24x36；调色板 #皮肤 H头发 L亮衣 M中衣 D暗衣 P裤 r强调 O墨线
原创绘制，仅借鉴传说之下的构图语言，未复制其像素。
"""
import json
import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A_CHAR = os.path.join(ROOT, "assets", "chars")
MANIFEST = os.path.join(ROOT, "data", "frames.json")
SHEET = os.path.join(ROOT, "docs", "frame-sheet.png")
os.makedirs(A_CHAR, exist_ok=True)
os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)

CW, CH = 24, 36
HW, HH = 11, 11
HAIR_ROWS = 3
INK = "1A1E24"

# 表情 = 眼型 + 嘴型 + 小配件 三者组合（学传说之下：眼睛形状本身要变，不是挪位置）
FACES = {
    "normal":     dict(eye="blk2",  mouth="line",  acc=None),
    "happy":      dict(eye="arc_up", mouth="wide",  acc=None),
    "sad":        dict(eye="arc_dn", mouth="droop", acc="tear"),
    "angry":      dict(eye="narrow", mouth="grit",  acc="vein"),
    "surprise":   dict(eye="round",  mouth="o",     acc=None),
    "scared":     dict(eye="round",  mouth="wave",  acc="sweat"),
    "determined": dict(eye="flat",   mouth="flat4", acc=None),
    "shy":        dict(eye="arc_up", mouth="wave",  acc="blush"),
    "hurt":       dict(eye="x",      mouth="open",  acc=None),
    "blink":      dict(eye="shut",   mouth="line",  acc=None),
    # ---- 夸张漫画面相 ----
    "smug":       dict(eye="smug",   mouth="smirk", acc=None),      # 得意
    "panic":      dict(eye="round",  mouth="wave",  acc="sweat2"),  # 慌乱
    "cry":        dict(eye="shut",   mouth="wail",  acc="tears"),   # 爆哭
    "dead":       dict(eye="void",   mouth="tiny",  acc="shadow"),  # 失神
    "love":       dict(eye="heart",  mouth="wide",  acc="blush"),   # 心动
    "rage":       dict(eye="rage",   mouth="roar",  acc="vein2"),   # 暴怒
    "shock":      dict(eye="white",  mouth="o_big", acc="lines"),   # 惊呆
}

HEAD_SHAPE = ["..#######..", ".#########."] + ["###########"] * 7 + [".#########.", "..#######.."]


def hexc(h):
    h = h.lstrip("#")
    if len(h) == 8:
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16))
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def pal(skin, hair, light, mid, dark, pants, accent):
    return {"#": hexc(skin), "H": hexc(hair), "L": hexc(light), "M": hexc(mid),
            "D": hexc(dark), "P": hexc(pants), "r": hexc(accent), "O": hexc(INK)}


class Cv:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["."] * w for _ in range(h)]

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = c

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.px(x + i, y + j, c)

    def hline(self, x0, x1, y, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.px(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.px(x, y, c)

    def to_image(self, palette, scale=1):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                ch = self.g[y][x]
                if ch == ".":
                    continue
                c = palette.get(ch)
                if c is None:
                    continue
                if ch not in ("O", "r"):
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and self.g[ny][nx] == "O":
                            c = (int(c[0] * 0.86), int(c[1] * 0.86), int(c[2] * 0.86), c[3])
                            break
                im.putpixel((x, y), c)
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        return im


def outline(c):
    src = [row[:] for row in c.g]
    for y in range(c.h):
        for x in range(c.w):
            if src[y][x] != ".":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < c.w and 0 <= ny < c.h and src[ny][nx] not in (".", "O"):
                    c.px(x, y, "O")
                    break


def _limb_raw(c, x, y, ang, length, col, thick):
    a = math.radians(ang)
    sx, sy = math.sin(a), math.cos(a)
    px, py = float(x), float(y)
    h = thick // 2
    for _ in range(length):
        px += sx
        py += sy
        for k in range(-h, thick - h):
            c.px(int(round(px)) + k, int(round(py)), col)
    return px, py


def limb(c, x, y, ang, length, col, thick=3):
    """从 (x,y) 按角度画肢体，返回末端。
    关键：肢体自己带 1px 墨线（先画 thick+2 的墨线底，再盖 thick 的色芯）。
    如果只画 3px 再交给全局 outline()，两侧各吃 1px，就只剩 1px 色芯 —— 会变成天线。"""
    _limb_raw(c, x, y, ang, length, "O", thick + 2)
    return _limb_raw(c, x, y, ang, length, col, thick)


def _mask_cols(y):
    return [x for x, ch in enumerate(HEAD_SHAPE[y]) if ch == "#"]


def draw_head(c, hx, hy, o):
    for y, row in enumerate(HEAD_SHAPE):
        for x, ch in enumerate(row):
            if ch == "#":
                c.px(hx + x, hy + y, "H" if y < HAIR_ROWS else "#")

    def side(y, col, inset=0):
        cols = _mask_cols(y)
        if len(cols) >= 2 + inset * 2:
            c.px(hx + cols[inset], hy + y, col)
            c.px(hx + cols[-1 - inset], hy + y, col)

    for y in range(HAIR_ROWS, 7):
        side(y, "H")
    st = o.get("hair_style", "short")
    if st == "fringe":
        side(HAIR_ROWS, "H", 1)
        side(HAIR_ROWS + 1, "H", 1)
    elif st == "long":
        for y in range(7, 11):
            side(y, "H")

    f = FACES.get(o.get("face", "normal"), FACES["normal"])
    ey = hy + 6
    if o.get("glasses"):
        for gx in (1, 4, 5, 8):
            c.px(hx + gx, ey, "M")
        c.px(hx, ey, "H")
        c.px(hx + 10, ey, "H")
    draw_eyes(c, hx, ey, f["eye"])
    draw_mouth(c, hx, hy, f["mouth"])
    draw_acc(c, hx, hy, ey, f["acc"])


def draw_eyes(c, hx, ey, kind):
    """眼型是表情的主载体：形状本身就变。"""
    L0, L1 = hx + 2, hx + 3      # 左眼两列
    R0, R1 = hx + 7, hx + 8      # 右眼两列
    if kind == "blk2":           # 平常：2x2 方块
        c.rect(L0, ey, 2, 2, "O"); c.rect(R0, ey, 2, 2, "O")
    elif kind == "shut":         # 眨眼：1px 横线
        c.hline(L0, L1, ey, "O"); c.hline(R0, R1, ey, "O")
    elif kind == "flat":         # 坚定：1px 平线 + 外侧高一点的眉
        c.hline(L0, L1, ey, "O"); c.hline(R0, R1, ey, "O")
        c.px(hx + 1, ey - 1, "O"); c.px(hx + 9, ey - 1, "O")
    elif kind == "narrow":       # 怒：压成 1px + 内侧压低的眉
        c.hline(L0, L1, ey, "O"); c.hline(R0, R1, ey, "O")
        c.px(L1, ey - 1, "O"); c.px(R0, ey - 1, "O")
    elif kind == "arc_up":       # 笑：外侧上挑的弧（^ ^）
        c.hline(L0, L1, ey, "O"); c.px(L1, ey - 1, "O")
        c.hline(R0, R1, ey, "O"); c.px(R0, ey - 1, "O")
    elif kind == "arc_dn":       # 难过：外侧下垂
        c.hline(L0, L1, ey, "O"); c.px(L0, ey + 1, "O")
        c.hline(R0, R1, ey, "O"); c.px(R1, ey + 1, "O")
    elif kind == "round":        # 惊/怕：2x2 上移一格（睁大）
        c.rect(L0, ey - 1, 2, 2, "O"); c.rect(R0, ey - 1, 2, 2, "O")
    elif kind == "smug":         # 得意：单侧压低的斜眼
        c.hline(L0, L1, ey, "O"); c.px(L0, ey - 1, "O")
        c.hline(R0, R1, ey, "O"); c.px(R1, ey - 1, "O")
    elif kind == "heart":        # 心动：红色小心形眼
        for x0 in (L0, R0):
            c.px(x0, ey, "r"); c.px(x0 + 2, ey, "r")
            c.hline(x0, x0 + 2, ey + 1, "r")
            c.px(x0 + 1, ey + 2, "r")
    elif kind == "void":         # 失神：眼窝空掉
        c.rect(L0, ey, 2, 2, "M"); c.rect(R0, ey, 2, 2, "M")
    elif kind == "rage":         # 暴怒：白眼 + 压下来的竖眉
        c.rect(L0, ey, 2, 2, "L"); c.rect(R0, ey, 2, 2, "L")
        c.hline(L0, L1, ey - 1, "O"); c.px(L1, ey - 2, "O")
        c.hline(R0, R1, ey - 1, "O"); c.px(R0, ey - 2, "O")
    elif kind == "white":        # 夸张惊吓：全白眼 + 一个小瞳孔
        c.rect(L0, ey - 1, 2, 3, "L"); c.px(L0 + 1, ey, "O")
        c.rect(R0, ey - 1, 2, 3, "L"); c.px(R0, ey, "O")
    elif kind == "x":            # 受伤：X 眼
        c.px(L0, ey, "O"); c.px(L1, ey + 1, "O")
        c.px(L1, ey, "O"); c.px(L0, ey + 1, "O")
        c.px(R0, ey, "O"); c.px(R1, ey + 1, "O")
        c.px(R1, ey, "O"); c.px(R0, ey + 1, "O")


def draw_mouth(c, hx, hy, kind):
    """嘴型谱：线 / 宽笑 / 下垂 / 龇牙 / 圆 O / 波浪 / 平 / 张口。"""
    x0 = hx + 3
    x1 = hx + 6
    my = hy + 7
    if kind == "line":
        c.hline(hx + 4, hx + 5, my, "O")
    elif kind == "wide":                     # 笑：更宽 + 嘴角上挑
        c.hline(x0, x1, my, "O")
        c.px(x0 - 1, my - 1, "O"); c.px(x1 + 1, my - 1, "O")
    elif kind == "droop":                    # 难过：下移 + 嘴角下垂
        c.hline(hx + 4, hx + 5, my + 1, "O")
        c.px(hx + 3, my + 2, "O"); c.px(hx + 6, my + 2, "O")
    elif kind == "grit":                     # 龇牙：锯齿
        c.hline(x0, x1, my, "O")
        c.px(x0, my + 1, "O"); c.px(x0 + 2, my + 1, "O"); c.px(x1, my + 1, "O")
    elif kind == "o":                        # 圆嘴
        c.rect(hx + 4, my, 2, 2, "O")
    elif kind == "wave":                     # 波浪（紧张/害羞）
        c.px(hx + 4, my, "O"); c.px(hx + 5, my + 1, "O"); c.px(hx + 6, my, "O")
    elif kind == "flat4":                    # 平嘴
        c.hline(x0, x1, my, "O")
    elif kind == "open":                     # 张口（受伤）
        c.rect(hx + 4, my, 3, 2, "O")
    elif kind == "smirk":                    # 得意：单边嘴角上挑
        c.hline(hx + 4, hx + 5, my, "O"); c.px(hx + 6, my - 1, "O")
    elif kind == "wail":                     # 爆哭：大张的洞
        c.rect(hx + 4, my - 1, 3, 3, "O")
    elif kind == "roar":                     # 暴怒：横着裂开的嘴 + 牙
        c.rect(hx + 3, my - 1, 5, 2, "O")
        c.px(hx + 3, my - 1, "L"); c.px(hx + 7, my - 1, "L")
    elif kind == "o_big":                    # 惊呆：竖着的圆口
        c.rect(hx + 4, my - 1, 2, 3, "O")
    elif kind == "tiny":                     # 失神：一个小点
        c.px(hx + 4, my, "O")


def draw_acc(c, hx, hy, ey, kind):
    """小配件：脸红 / 泪 / 汗 / 青筋 —— 传说之下的表情常用这种一名词表达。"""
    if kind == "blush":
        c.px(hx + 1, hy + 7, "r"); c.px(hx + 2, hy + 7, "r")
        c.px(hx + 8, hy + 7, "r"); c.px(hx + 9, hy + 7, "r")
    elif kind == "tear":
        c.px(hx + 2, hy + 8, "M"); c.px(hx + 2, hy + 9, "M")
    elif kind == "sweat":
        c.px(hx + 9, hy + 3, "M"); c.px(hx + 9, hy + 4, "M")
    elif kind == "vein":
        c.px(hx + 8, hy + 3, "r"); c.px(hx + 9, hy + 3, "r")
        c.px(hx + 8, hy + 4, "r")
    elif kind == "tears":        # 爆哭：两行泪
        for x0 in (hx + 2, hx + 8):
            for k in range(3):
                c.px(x0, hy + 8 + k, "M")
        c.px(hx + 2, hy + 11, "M"); c.px(hx + 8, hy + 11, "M")
    elif kind == "sweat2":       # 慌乱：两滴汗
        c.px(hx + 9, hy + 3, "M"); c.px(hx + 9, hy + 4, "M"); c.px(hx + 10, hy + 5, "M")
        c.px(hx + 1, hy + 3, "M")
    elif kind == "vein2":        # 暴怒：双青筋
        for vx in (hx + 8, hx + 2):
            c.px(vx, hy + 2, "r"); c.px(vx + 1, hy + 2, "r"); c.px(vx, hy + 3, "r")
    elif kind == "shadow":       # 失神：眼下阴影
        c.hline(hx + 2, hx + 8, hy + 9, "M")
    elif kind == "lines":        # 无语/惊吓：脸颊竖线
        for x0 in (hx + 1, hx + 3):
            c.vline(x0, hy + 7, hy + 9, "M")


def draw_torso(c, bx, bw, ty, bh, o):
    style = o.get("style", "tee")
    y0 = ty + 1
    h = bh - 1
    if h <= 0:
        return
    if style == "jacket":
        c.rect(bx, y0, bw, h, "D")
        c.vline(bx + 1, y0 + 1, y0 + h - 1, "M")
        c.vline(bx + bw - 2, y0 + 1, y0 + h - 1, "M")
        iw = bw - 4
        c.rect(bx + 2, y0 + 1, iw, h - 1, "L")
        cy = y0 + h // 2
        c.px(bx + 2 + iw // 2 - 1, cy, "r")
        c.px(bx + 2 + iw // 2 + 1, cy + 1, "r")
        c.px(bx + 2 + iw // 2, cy + 2, "r")
    elif style == "suit":
        c.rect(bx, y0, bw, h, "D")
        c.rect(bx + bw // 2 - 1, y0 + 1, 2, h - 1, "L")
        c.rect(bx + bw // 2 - 1, y0 + 1, 2, 2, "r")
    elif style == "sweater":
        c.rect(bx, y0, bw, h, "D")
        c.hline(bx + 1, bx + bw - 2, y0, "r")
    elif style == "uniform":
        c.rect(bx, y0, bw, h, "L")
        c.rect(bx + bw // 2 - 1, y0 + 1, 2, 2, "r")
    elif style == "apron":
        c.rect(bx, y0, bw, h, "L")
        c.rect(bx + 1, y0 + 3, bw - 2, h - 3, "M")
    elif style == "dress":
        c.rect(bx, y0, bw, h, "L")
        c.rect(bx + bw // 2 - 2, y0, 4, h, "M")
    else:
        c.rect(bx, y0, bw, h, "L")
    if style != "sweater":
        c.hline(bx + 2, bx + bw - 3, y0, "D")
    if style in ("jacket", "tee", "uniform"):
        c.hline(bx, bx + bw - 1, y0 + h - 1, "D")
    c.px(bx + bw // 2 - 1, ty, "#")
    c.px(bx + bw // 2, ty, "#")


# ==========================================================
# 姿势表（每帧一组关节角度）
# ==========================================================
POSES = {
    "idle": [
        dict(bob=0, legL=(-5, 1.00), legR=(5, 1.00), armL=(-7, 1.00), armR=(7, 1.00)),
        dict(bob=1, legL=(-5, 0.98), legR=(5, 0.98), armL=(-6, 1.00), armR=(6, 1.00)),
        dict(bob=0, legL=(-5, 1.00), legR=(5, 1.00), armL=(-7, 1.00), armR=(7, 1.00)),  # 第三帧：眨眼
    ],
    "walk": [
        dict(bob=0, legL=(-8, 1.00), legR=(6, 0.70), armL=(-16, 1.00), armR=(12, 1.00)),
        dict(bob=1, legL=(-5, 0.86), legR=(4, 0.86), armL=(-7, 1.00), armR=(5, 1.00)),
        dict(bob=0, legL=(8, 0.70), legR=(-6, 1.00), armL=(16, 1.00), armR=(-12, 1.00)),
        dict(bob=1, legL=(5, 0.86), legR=(-4, 0.86), armL=(7, 1.00), armR=(-5, 1.00)),
    ],
    "wave": [
        dict(bob=0, legL=(-5, 1.00), legR=(5, 1.00), armL=(-7, 1.00), armR=(80, 1.00)),
        dict(bob=0, legL=(-5, 1.00), legR=(5, 1.00), armL=(-7, 1.00), armR=(135, 1.00)),
        dict(bob=1, legL=(-5, 1.00), legR=(5, 1.00), armL=(-7, 1.00), armR=(158, 1.00)),
        dict(bob=0, legL=(-5, 1.00), legR=(5, 1.00), armL=(-7, 1.00), armR=(126, 1.00)),
    ],
    "raise": [
        dict(bob=0, legL=(-5, 1.00), legR=(5, 1.00), armL=(-12, 1.00), armR=(40, 1.00)),
        dict(bob=0, legL=(-5, 1.00), legR=(5, 1.00), armL=(-18, 1.00), armR=(95, 1.00)),
        dict(bob=1, legL=(-5, 1.00), legR=(5, 1.00), armL=(-20, 1.00), armR=(120, 1.00)),
    ],
    "sit": [
        dict(bob=2, legL=(-13, 0.82), legR=(13, 0.82), armL=(-12, 1.00), armR=(12, 1.00)),
        dict(bob=4, legL=(-19, 0.62), legR=(19, 0.62), armL=(-16, 1.00), armR=(16, 1.00)),
        dict(bob=4, legL=(-19, 0.60), legR=(19, 0.60), armL=(-14, 1.00), armR=(14, 1.00)),
    ],
}


def geom(spec):
    _, _, top, torso, leg, bw, o = spec
    bx = (CW - bw) // 2
    ty = top + HH
    ly = ty + torso
    span = 3 * 2 + 2
    lx = bx + (bw - span) // 2
    return dict(bx=bx, ty=ty, ly=ly, lx=lx, lx2=lx + 5, bw=bw, leg=leg, torso=torso)


def build_frame(spec, action, idx, face="normal"):
    _, _, top, torso, leg, bw, base_o = spec
    o = dict(base_o)
    o["face"] = face
    p = POSES[action][idx]
    g = geom(spec)
    bob = p["bob"]
    c = Cv(CW, CH)
    ty = g["ty"] + bob
    ly = g["ly"] + bob

    # 腿（先画，在身体后面）
    for side, key in ((g["lx"], "legL"), (g["lx2"], "legR")):
        ang, sc = p[key]
        n = max(2, int(g["leg"] * sc))
        ex, ey = limb(c, side + 1, ly, ang, n, "P", 3)
        # 鞋
        for k in range(-1, 2):
            c.px(int(round(ex)) + k, int(round(ey)) + 1, "D")

    draw_torso(c, g["bx"], bw, ty, torso, o)

    # 手臂（在身体前面）
    arm_len = max(4, torso - 3)
    for x, key in ((g["bx"] - 1, "armL"), (g["bx"] + bw + 1, "armR")):
        ang, sc = p[key]
        ex, ey = limb(c, x, ty + 2, ang, int(arm_len * sc), o.get("sleeve", "D"), 3)
        c.px(int(round(ex)), int(round(ey)) + 1, "#")
        c.px(int(round(ex)) + 1, int(round(ey)) + 1, "#")

    draw_head(c, g["bx"] + (bw - HW) // 2, top + bob, o)
    outline(c)
    return c, base_o["pal"]


def build_head(spec, face="normal"):
    """只画头（同一 24x36 画布），给对话框立绘用。"""
    _, _, top, torso, leg, bw, base_o = spec
    o = dict(base_o)
    o["face"] = face
    bx = (CW - bw) // 2
    c = Cv(CW, CH)
    draw_head(c, bx + (bw - HW) // 2, top, o)
    outline(c)
    return c


# ==========================================================
# 角色表
# ==========================================================
LEAD = [
    ("lead_child", "童年 6", 11, 8, 5, 9,
     dict(hair_style="short", style="tee", sleeve="#", pal=pal("EAB58F", "3A2E2A", "F7F5EF", "E2DFD6", "6B7A8F", "3B4A6B", "D8412F"))),
    ("lead_teen", "少年 12", 5, 9, 10, 10,
     dict(hair_style="short", style="uniform", sleeve="L", pal=pal("EAB58F", "33272B", "F2F0E6", "9AA4B4", "2F3542", "33405A", "9C3B3B"))),
    ("lead_youth", "青年 20", 1, 10, 13, 11,
     dict(hair_style="fringe", glasses=True, style="jacket", sleeve="D", pal=pal("E8B48C", "2B2530", "F0E6CC", "9AA0A8", "2E333C", "3A4048", "D8412F"))),
    ("lead_adult", "成年 30", 1, 10, 13, 12,
     dict(hair_style="fringe", glasses=True, style="jacket", sleeve="D", pal=pal("E8B48C", "2B2530", "F0E6CC", "9AA0A8", "2E333C", "3A4048", "D8412F"))),
    ("lead_middle", "中年 45", 1, 10, 13, 12,
     dict(hair_style="neat", glasses=True, style="suit", sleeve="D", pal=pal("DFAB84", "9A9AA2", "F2F2F2", "6E7684", "33373F", "33373F", "55607A"))),
    ("lead_elder", "晚年 70", 2, 10, 12, 11,
     dict(hair_style="neat", glasses=True, style="sweater", sleeve="D", pal=pal("D8A47F", "C8C8CE", "D8D2C4", "8A8A92", "525761", "40444E", "C43A32"))),
]
NPCS = [
    ("npc_parent", "父母", 2, 10, 12, 12,
     dict(hair_style="neat", style="apron", sleeve="L", pal=pal("DDAE8A", "B8B4AE", "C6C1B2", "9A8F7E", "7A8FA6", "4A4A52", "8E3A3A"))),
    ("npc_mate", "同学", 5, 9, 10, 10,
     dict(hair_style="short", style="tee", sleeve="L", pal=pal("E8B48C", "3A2A2E", "4E8FBF", "2F5E86", "3A4048", "3A4048", "E0A040"))),
    ("npc_teacher", "老师", 2, 10, 12, 11,
     dict(hair_style="neat", glasses=True, style="suit", sleeve="D", pal=pal("DDAE8A", "4A3A3A", "F2F2EC", "8A94A4", "3A4250", "3A4250", "6E7A94"))),
    ("npc_boss", "上司", 1, 10, 13, 12,
     dict(hair_style="neat", glasses=True, style="suit", sleeve="D", pal=pal("D9A87F", "8A8A90", "F2F2F2", "5A6478", "33373F", "33373F", "8E3A3A"))),
    ("npc_partner", "伴侣", 2, 10, 12, 10,
     dict(hair_style="long", style="dress", sleeve="L", pal=pal("EDBB95", "4A3038", "C86F8E", "A85A76", "6A4655", "EDBB95", "E0A040"))),
    ("npc_friend", "老友", 5, 9, 10, 11,
     dict(hair_style="short", style="tee", sleeve="L", pal=pal("D9A87F", "4A4038", "6FAF6A", "4E8A4A", "3A4038", "4A4038", "E0A040"))),
]

# ==========================================================
# 导出
# ==========================================================
manifest = {}
count = 0
for spec in LEAD + NPCS:
    key = spec[0]
    is_lead = key.startswith("lead_")
    acts = {}
    for action in POSES:
        n = len(POSES[action])
        # 只有 idle 需要四张脸（揭晓那一刻角色在 idle）；其余动作用 normal 省体积
        faces = list(FACES.keys()) if action == "idle" else ["normal"]
        acts[action] = {"n": n, "faces": faces}
        for i in range(n):
            for f in faces:
                if action == "idle" and i == 2:
                    if f != "blink":
                        continue      # idle 第三帧固定为眨眼
                elif i > 0 and f != "normal":
                    continue          # 其余表情只在第 0 帧烘焙，省体积
                c, p = build_frame(spec, action, i, f)
                c.to_image(p, 1).save(os.path.join(A_CHAR, "%s_%s_%d_%s.png" % (key, action, i, f)))
                count += 1
    manifest[key] = acts

# 头像：每个表情一张，供对话框立绘
for spec in LEAD + NPCS:
    key = spec[0]
    for f in FACES:
        build_head(spec, f).to_image(spec[6]["pal"], 1).save(
            os.path.join(A_CHAR, "%s_head_%s.png" % (key, f)))
        count += 1

with open(MANIFEST, "w", encoding="utf-8") as f:
    json.dump({"char_canvas": [CW, CH], "actions": manifest,
               "fps": {"walk": 9, "wave": 8, "raise": 9, "sit": 8, "idle": 2}},
              f, ensure_ascii=False, separators=(",", ":"))

# ---------- 图鉴：表情网格 ----------
from PIL import ImageFont
F_T = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
F_XS = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 11)
TXT = (226, 234, 243)
S = 3
CW3, CH3 = CW * S, CH * S
per_row = 9
rows = (len(FACES) + per_row - 1) // per_row
img = Image.new("RGB", (per_row * (CW3 + 12) + 20, rows * (CH3 + 28) + 44), (13, 15, 18))
d = ImageDraw.Draw(img)
d.text((16, 10), "17 种表情：眼型 / 嘴型 / 配件 组合", font=F_T, fill=(255, 209, 84))
for i, f in enumerate(FACES):
    cx = 16 + (i % per_row) * (CW3 + 12)
    cy = 40 + (i // per_row) * (CH3 + 28)
    c, p = build_frame(LEAD[2], "idle", 0, f)
    im = c.to_image(p, S)
    img.paste(im, (cx, cy), im)
    d.text((cx + 2, cy + CH3 + 4), f, font=F_XS, fill=TXT)
img.save(SHEET)

print("帧图 %d 张 / 角色 %d" % (count, len(manifest)))
print("manifest ->", MANIFEST)
print("图鉴 ->", SHEET, img.size)
