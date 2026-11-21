#!/usr/bin/env python3
"""v5 分层资产生成：去桌面 + 眼/爪/尾/耳分层。仓库根目录执行。"""
import json, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = f"{ROOT}/Docs/design/clean-desktop-pet-v4-desk-keyframe.png"
OUT = f"{ROOT}/Sources/MacAppControlDeck/Modules/Pet/Resources/v5"
os.makedirs(OUT, exist_ok=True)

W, H = 1440, 1920
SRC_W = 1373
S = W / SRC_W
im = Image.open(SRC).convert("RGB")
sh = int(round(im.height * S))
canvas = Image.new("RGB", (W, H), (255, 255, 255))
canvas.paste(im.resize((W, sh), Image.LANCZOS), (0, 0))
arr = np.asarray(canvas).astype(np.float32)
lum = arr.max(2)
mn, mx = arr.min(2), arr.max(2)
neutral = (mx - mn) < 42
sat = (mx - mn) / np.maximum(mx, 1.0)

# ---------- 猫 alpha ----------
a_ramp = np.clip((178.0 - lum) / 58.0, 0, 1)
cat = np.where(neutral, a_ramp, 0.0)
cat = np.clip(cat * 1.08, 0, 1)
# 闭运算填洞
b = Image.fromarray((cat * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))
cat = np.maximum(cat, np.asarray(b).astype(np.float32) / 255.0 * (lum < 150))
cat[:200, :] = 0                      # 顶部空白
cat[1585:, :] = 0                     # 桌面之后的地面/桌沿
cat = np.clip(cat, 0, 1)
# 彻底剔木桌色（亮且偏暖），避免尾巴/爪子边缘的木色碎屑
_wb = ((arr[..., 0] - arr[..., 2]) > 34) & (lum > 140)
cat = cat * (~_wb)

def feather(mask, r=2):
    im8 = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    im8 = im8.filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im8).astype(np.float32) / 255.0

def poly_mask(points, feather_r=2):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    if feather_r:
        m = m.filter(ImageFilter.GaussianBlur(feather_r))
    return np.asarray(m).astype(np.float32) / 255.0

# ---------- 键盘 / 鼠标（白物 + 低饱和 + 下半区） ----------
white = (lum > 105) & (mx - mn < 55)
kb_area = poly_mask([(60,1436),(1000,1418),(1040,1444),(1010,1566),(960,1580),(110,1572),(52,1550),(44,1470)], 0.0) > 0.6
kb_neutral = (mx - mn < 60) & (lum > 45) & kb_area
mouse_area = np.zeros((H, W), bool); mouse_area[1450:1660, 1055:1350] = True
mo_warm = (arr[...,0]-arr[...,2]) < 34
# 键盘：白色键帽 + 橙色键 + 深色沟槽，用白色/橙色做种子，闭运算 + 填洞，不再依赖多边形
kw = (((lum > 100) & (sat < 0.26)) | (((arr[..., 0] - arr[..., 1]) > 62) & ((arr[..., 1] - arr[..., 2]) > 20))).astype(np.float32)
kb_bb = np.zeros((H, W), np.float32); kb_bb[1404:1600, 30:1065] = 1.0
kw *= kb_bb
kw8 = Image.fromarray((kw * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.MinFilter(9))
kwb = np.asarray(kw8).astype(np.float32) / 255.0 > 0.5
lbl, n = ndimage.label(kwb)
if n > 0:
    sizes = ndimage.sum(kwb, lbl, range(1, n + 1))
    kwb = lbl == (int(np.argmax(sizes)) + 1)
kwb = ndimage.binary_closing(kwb, np.ones((15, 15)))
kwb = ndimage.binary_fill_holes(kwb)
kb_m = np.asarray(Image.fromarray((kwb.astype(np.float32) * 255).astype(np.uint8))
                  .filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
kb_m = np.clip(kb_m, 0, 1)
# 只保留贴着"白色键帽/橙色键"核心的部分，剪掉桌沿残留的褐色飞边
kb_core = ((lum > 190) & ((arr[..., 0] - arr[..., 2]) < 34)) | \
          (((arr[..., 0] - arr[..., 1]) > 62) & ((arr[..., 1] - arr[..., 2]) > 20))
kb_core = ndimage.binary_dilation(kb_core, np.ones((17, 17)))
kb_m = kb_m * kb_core
# 桌沿褐屑只清底边一带：暖褐且偏暗的像素不算键盘
yy, xx = np.mgrid[0:H, 0:W]
brown = ((arr[..., 0] - arr[..., 2]) > 30) & (lum < 196) & (yy > 1558)
kb_m = kb_m * (~brown)
# 木桌暖色（R-B 40~80 且不太暗）从键鼠/猫层统一剔除

# 鼠标：白物 + 低暖 + 区域内
mo_raw = (white & mouse_area & mo_warm).astype(np.float32)
mo_m = np.asarray(Image.fromarray((mo_raw * 255).astype(np.uint8))
                  .filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(7)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32) / 255.0
mo_m = np.clip(mo_m, 0, 1)


# ---------- 头 / 耳 ----------
HEAD_POLY = [(300,470),(340,420),(430,408),(520,430),(600,470),(700,440),(790,412),(880,440),
             (940,520),(990,660),(985,780),(930,890),(830,925),(700,930),(560,926),(420,892),
             (340,830),(305,700)]
head_poly = poly_mask(HEAD_POLY, 1.5)
# 头部向下延伸的软裙边：让 head 与 body 大幅重叠，旋转时不露缝
HEAD_POLY_EXT = [(300,470),(340,420),(430,408),(520,430),(600,470),(700,440),(790,412),(880,440),
                 (940,520),(990,660),(985,780),(960,900),(900,1010),(800,1065),(700,1075),(600,1065),
                 (500,1030),(420,980),(350,900),(305,700)]
head_ext = poly_mask(HEAD_POLY_EXT, 1.5)
SKIRT_TOP, SKIRT_BOT = 940, 1090
skirt = np.zeros((H, W), np.float32)
for yy in range(SKIRT_TOP, SKIRT_BOT):
    skirt[yy, :] = 1.0 - (yy - SKIRT_TOP) / float(SKIRT_BOT - SKIRT_TOP)
skirt = np.clip(skirt, 0, 1) * head_ext
EYE_L_BOX = (355, 660, 560, 830)
EYE_R_BOX = (585, 630, 845, 900)
eye_core = np.zeros((H, W), np.float32)
for bx in (EYE_L_BOX, EYE_R_BOX):
    x0, y0, x1, y1 = bx
    sub_green = np.zeros((H, W), bool)
    g = (arr[...,1] > arr[...,0] + 6) & (arr[...,1] > arr[...,2] + 6) & (lum > 60)
    sub = np.zeros((H, W), bool); sub[y0:y1, x0:x1] = True
    eye_core = np.maximum(eye_core, (g & sub).astype(np.float32))
head_solid = (head_poly > 0.5) & ((cat > 0.45) | (eye_core > 0))
head_m = feather(head_solid.astype(np.float32), 1.2)
head_m = np.maximum(head_m, feather(eye_core, 1.0))
head_core_m = head_m.copy()
head_m = np.maximum(head_m, skirt * (cat > 0.35))

EAR_L = [(318,540),(330,452),(360,424),(404,410),(436,420),(446,470),(440,540),(390,556)]
EAR_R = [(860,548),(866,462),(892,424),(936,412),(968,428),(978,486),(968,552),(910,560)]
earL_poly = poly_mask(EAR_L, 1.0)
earR_poly = poly_mask(EAR_R, 1.0)
ear_core = np.clip(earL_poly + earR_poly, 0, 1)
# 耳朵从 head 里挖掉，单独层画（外扩 10px 与头部毛发重叠，旋转不露缝）
def dilate(m, r):
    im8 = Image.fromarray((np.clip(m,0,1)*255).astype(np.uint8))
    return np.asarray(im8.filter(ImageFilter.MaxFilter(r)).filter(ImageFilter.GaussianBlur(1.5)).convert("L")).astype(np.float32)/255.0
earL_m = np.clip(dilate(earL_poly,11) * head_m, 0, 1)
earR_m = np.clip(dilate(earR_poly,11) * head_m, 0, 1)
head_m = np.clip(head_m - feather(ear_core, 1.0), 0, 1)
ears_m = np.clip(earL_m + earR_m, 0, 1)

# ---------- 尾 ----------
TAIL_POLY = [(880,1180),(980,1150),(1100,1180),(1180,1270),(1210,1380),(1160,1440),(1040,1430),(960,1360),(900,1300)]
tail_poly = poly_mask(TAIL_POLY, 2.0)
# 尾巴区域里夹着桌面色：按饱和度剔除（木色 sat≈0.33，猫毛 sat 低且暗）
sat = (mx - mn) / np.maximum(mx, 1.0)
tail_m = tail_poly * cat * (((sat < 0.20) | (lum < 90)) & (lum < 135))

# ---------- 爪 ----------
PAW_L = (246, 1282, 486, 1452)
PAW_R = (676, 1296, 916, 1452)
def box_mask(box, r=2):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=18, fill=255)
    return feather(np.asarray(m.filter(ImageFilter.GaussianBlur(r)).convert("L")).astype(np.float32) / 255.0, r)
pawL_box, pawR_box = box_mask(PAW_L), box_mask(PAW_R)
pawL_m = np.clip(pawL_box * cat, 0, 1)
pawR_m = np.clip(pawR_box * cat, 0, 1)

# ---------- 合成各层 ----------
def layer_alpha(mask, rgb=None, bleed=False):
    a = np.clip(mask, 0, 1)
    src = (arr if rgb is None else rgb).astype(np.float32)
    if bleed:
        # 半透明边缘像素混了白背景，直接合成会出现白边光晕；
        # 用"最近的实心像素颜色"填掉这些边缘像素的 RGB（alpha 不动）。
        solid = a >= 0.9
        if solid.any():
            _, idx = ndimage.distance_transform_edt(~solid, return_indices=True)
            src = src[idx[0], idx[1]]
    out = np.dstack([src, a * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")

# body = 猫 - 头 - 耳 - 尾 - 爪（爪与尾保留在 body 上，用 patch 遮挡，避免空洞）
body_m = np.clip(cat - head_core_m * (cat > 0.4), 0, 1)
# 去掉残余的木桌色碎屑（中高亮度的暖色）
body_m = body_m * ((sat < 0.22) | (lum < 120))
body_m = body_m * ((arr[..., 0] - arr[..., 2]) < 34)
tail_m = tail_m * ((arr[..., 0] - arr[..., 2]) < 34)
body = layer_alpha(body_m)
body.save(f"{OUT}/body.png")

head_a = (head_m > 0.45).astype(np.float32)
head_a = np.asarray(Image.fromarray((head_a * 255).astype(np.uint8))
                    .filter(ImageFilter.GaussianBlur(0.8)).convert("L")).astype(np.float32) / 255.0
head = layer_alpha(head_a)
head.save(f"{OUT}/head.png")

# 颈部补片：头部单独旋转时露出的缝隙用同一块原图像素补上（画在 body 之上、head 之下）
neck_m = np.zeros_like(cat)
y0, y1, x0, x1 = 760, 1210, 170, 1100
neck_m[y0:y1, x0:x1] = cat[y0:y1, x0:x1]
# 四边渐隐，头部转开时补片不会露出生硬的直边
fade = 90
for yy in range(y0, min(y1, y0 + fade)):
    neck_m[yy, :] *= (yy - y0) / fade
for xx in range(x0, min(x1, x0 + fade)):
    neck_m[:, xx] *= (xx - x0) / fade
for xx in range(x1 - fade, x1):
    neck_m[:, xx] *= (x1 - xx) / fade
for yy in range(y1 - fade, y1):
    neck_m[yy, :] *= (y1 - yy) / fade
neck = layer_alpha(neck_m)
neck.save(f"{OUT}/neck.png")

earL = layer_alpha(earL_m); earL.save(f"{OUT}/earL.png")
earR = layer_alpha(earR_m); earR.save(f"{OUT}/earR.png")

tail = layer_alpha(tail_m); tail.save(f"{OUT}/tail.png")

kb = layer_alpha(np.clip(kb_m - mo_m, 0, 1)); kb.save(f"{OUT}/keyboard.png")
mo = layer_alpha(mo_m); mo.save(f"{OUT}/mouse.png")

pawL = layer_alpha(pawL_m); pawL.save(f"{OUT}/pawL.png")
pawR = layer_alpha(pawR_m); pawR.save(f"{OUT}/pawR.png")

# patch：用爪上方的一带毛发镜像下移，盖住原爪
body_arr = np.asarray(body).astype(np.float32)
def fill_hole(mask, radius=26):
    src = body_arr
    sel = mask > 0.4
    if sel.sum() == 0:
        return np.zeros_like(src, dtype=np.uint8)
    """alpha 加权模糊补洞：把 mask 区域的 RGB 用周围像素的加权均值填满。"""
    med = np.median(src[..., :3][sel], axis=0)
    out_rgb = np.where(mask[..., None] > 0.05, med, src[..., :3])
    return np.dstack([np.clip(out_rgb, 0, 255), np.clip(mask * 255, 0, 255)]).astype(np.uint8)

def _unused_fill(mask, radius=26):
    al = body_arr[..., 3] / 255.0
    keep = al * (1.0 - mask)
    rgb_w = body_arr[..., :3] * keep[..., None]
    w_blur = np.asarray(Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius)).convert("L")).astype(np.float32) / 255.0
    rgb_blur = np.dstack([np.asarray(Image.fromarray(rgb_w[..., i].astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius)).convert("L")).astype(np.float32)
                          for i in range(3)]) / 255.0
    filled = rgb_blur / np.maximum(w_blur[..., None], 1e-3)
    out_rgb = np.where(mask[..., None] > 0.05, filled, body_arr[..., :3])
    return np.dstack([np.clip(out_rgb * 255, 0, 255), np.clip(mask * 255, 0, 255)]).astype(np.uint8)

for mask, nm in ((pawL_m, "patchL"), (pawR_m, "patchR")):
    Image.fromarray(fill_hole(mask), "RGBA").save(f"{OUT}/{nm}.png")
Image.fromarray(fill_hole(tail_m), "RGBA").save(f"{OUT}/patchTail.png")

# ---------- 眼睛：虹膜 + 瞳孔 + 高光 ----------
# 眼窝盒（2x 画布坐标）
EYE_L_BOX = (340, 640, 585, 905)   # 外扩裁剪框
EYE_R_BOX = (585, 630, 845, 900)
def split_eye(box, name):
    x0, y0, x1, y1 = box
    sub = np.asarray(head.crop(box)).astype(np.float32)
    rgb = sub[..., :3]
    l = rgb.max(2)
    # 眼球 = 眼框内所有亮像素（含黄绿虹膜与高光）填洞（洞=瞳孔）
    bright = (l > 90)
    bright = largest_blob(bright.astype(np.uint8) > 0)
    ball = ndimage.binary_fill_holes(bright)
    ball = ndimage.binary_dilation(ball, np.ones((3, 3)))
    ball = ndimage.binary_erosion(ball, np.ones((1, 1)))
    # 瞳孔 = 眼球内部的暗块
    pupil_m = largest_blob(((l < 74) & ball))
    # 虹膜 = 眼球 - 瞳孔，瞳孔区域用周边虹膜色径向填充
    iris_rgb = rgb.copy()
    keep = ball & (~pupil_m)
    ys, xs = np.where(pupil_m)
    for y, x in zip(ys, xs):
        for r in range(4, 30):
            ok = None
            for dy, dx in ((0, -r), (0, r), (-r, 0), (r, 0), (-r, -r), (-r, r), (r, -r), (r, r)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < iris_rgb.shape[0] and 0 <= xx < iris_rgb.shape[1] and keep[yy, xx]:
                    ok = iris_rgb[yy, xx]; break
            if ok is not None:
                iris_rgb[y, x] = ok; break
    ia = ball.astype(np.float32) * (1.0 - pupil_m.astype(np.float32))
    ia = np.asarray(Image.fromarray((np.clip(ia, 0, 1) * 255).astype(np.uint8))
                    .filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255.0
    Image.fromarray(np.dstack([iris_rgb, ia * 255]).astype(np.uint8), "RGBA").save(f"{OUT}/iris{name}.png")
    pa = np.asarray(Image.fromarray((pupil_m.astype(np.float32) * 255).astype(np.uint8))
                    .filter(ImageFilter.GaussianBlur(1.0))).astype(np.float32) / 255.0
    Image.fromarray(np.dstack([rgb, pa * 255]).astype(np.uint8), "RGBA").save(f"{OUT}/pupil{name}.png")
    ys, xs = np.where(ball)
    cx, cy = (xs.mean(), ys.mean()) if len(xs) else (0, 0)
    ys2, xs2 = np.where(pupil_m)
    px, py = (xs2.mean(), ys2.mean()) if len(xs2) else (cx, cy)
    rad = float(np.sqrt(len(xs) / math.pi)) if len(xs) else 1.0
    split_eye.last_ball = ball  # noqa
    return {"box": [x0, y0], "size": [x1 - x0, y1 - y0],
            "center": [cx + x0, cy + y0], "pupil": [px + x0, py + y0], "radius": rad}

def largest_blob(mask):
    """flood 标记取最大块（纯 numpy 迭代，小区域足够）。"""
    try:
        from PIL import ImageDraw as _D
    except Exception:
        return mask
    m = mask.astype(np.uint8)
    hgt, wdt = m.shape
    lab = np.zeros((hgt, wdt), np.int32); cur = 0; best = (0, 0)
    for y in range(hgt):
        for x in range(wdt):
            if m[y, x] and lab[y, x] == 0:
                cur += 1; stack = [(y, x)]; lab[y, x] = cur; cnt = 0
                while stack:
                    yy, xx = stack.pop(); cnt += 1
                    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                        y2, x2 = yy + dy, xx + dx
                        if 0 <= y2 < hgt and 0 <= x2 < wdt and m[y2, x2] and lab[y2, x2] == 0:
                            lab[y2, x2] = cur; stack.append((y2, x2))
                if cnt > best[0]: best = (cnt, cur)
    return (lab == best[1]) if best[1] else mask

scipy_ok = False
eL = split_eye(EYE_L_BOX, "L")
ballL = split_eye.last_ball; eR = split_eye(EYE_R_BOX, "R"); ballR = split_eye.last_ball
# head 保留完整眼球（避免白眼眶/高光漏底），眼球区域 alpha 强制 1
EB = np.zeros((H, W), np.float32)
EB[EYE_L_BOX[1]:EYE_L_BOX[3], EYE_L_BOX[0]:EYE_L_BOX[2]] = ballL.astype(np.float32)
EB[EYE_R_BOX[1]:EYE_R_BOX[3], EYE_R_BOX[0]:EYE_R_BOX[2]] = np.maximum(
    EB[EYE_R_BOX[1]:EYE_R_BOX[3], EYE_R_BOX[0]:EYE_R_BOX[2]], ballR.astype(np.float32))
head_m = np.maximum(head_m, EB)
layer_alpha(head_m).save(f"{OUT}/head.png")

# ---------- 阴影 ----------
sh_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(sh_img)
x0, y0, x1, y1 = 80, 1560, 1000, 1615
d.ellipse((x0, y0, x1, y1), fill=(18, 12, 8, 110))
sh_img = sh_img.filter(ImageFilter.GaussianBlur(30))
sh_img.save(f"{OUT}/shadow.png")

manifest = {
    "version": "v5",
    "designSize": [720, 960],
    "scale": 2,
    "layers": {
        "shadow":   {"box": [0, 0, 1440, 1920], "z": 0},
        "keyboard": {"box": [0, 0, 1440, 1920], "z": 2, "pressY": 2},
        "mouse":    {"box": [0, 0, 1440, 1920], "z": 2, "pressY": 6},
        "body":     {"box": [0, 0, 1440, 1920], "z": 1},
        "neck":     {"box": [0, 0, 1440, 1920], "z": 1},
        "tail":     {"box": [800, 1120, 1240, 1470], "z": 1, "pivot": [905, 1215], "swingDeg": 2},
        "head":     {"box": [0, 0, 1440, 1920], "z": 3, "neck": [450, 962], "pivot": [450, 962]},
        "earL":     {"box": [300, 400, 470, 580], "z": 3, "pivot": [400, 545]},
        "earR":     {"box": [840, 400, 1010, 580], "z": 3, "pivot": [915, 545]},
        "pawL":     {"box": [PAW_L[0], PAW_L[1], PAW_L[2], PAW_L[3]], "z": 4},
        "pawR":     {"box": [PAW_R[0], PAW_R[1], PAW_R[2], PAW_R[3]], "z": 4},
    },
    "eyes": {"left": eL, "right": eR, "pupilRange": [26, 16]},
    "keyboardBox": [70, 1400, 1010, 1600],
    "keycaps": {"riseY": 44, "life": 0.6, "slots": 4},
    "headRotate": {"yaw": 6.0, "pitch": 3.2},
}
json.dump(manifest, open(f"{OUT}/manifest.json", "w"), indent=2)

# 预览：静态合成（body → tail → keyboard → mouse → head → ears → iris → pupil）
def paste_alpha(base, img, box):
    base.alpha_composite(img, (0, 0))

prev = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for nm, path in [("shadow","shadow.png"),("body","body.png"),("patchTail","patchTail.png"),
                 ("tail","tail.png"),("patchL","patchL.png"),("patchR","patchR.png"),
                 ("pawL","pawL.png"),("pawR","pawR.png"),
                 ("keyboard","keyboard.png"),("mouse","mouse.png"),("head","head.png"),
                 ("earL","earL.png"),("earR","earR.png")]:
    lay = Image.open(f"{OUT}/{path}")
    if path.startswith("patch"):
        lay = Image.new("RGBA", (W, H), (0,0,0,0)).__class__ and lay
        base = prev; base.alpha_composite(lay, (0,0)) if lay.size == (W,H) else base.alpha_composite(lay, (800,1120) if path=="patchTail.png" else (PAW_L[0] if path=="patchL.png" else PAW_R[0], PAW_L[1] if path=="patchL.png" else PAW_R[1]))
        continue
    prev.alpha_composite(lay, (0, 0))
for nm, eye in (("L", eL), ("R", eR)):
    prev.alpha_composite(Image.open(f"{OUT}/iris{nm}.png"), (eye["box"][0], eye["box"][1]))
    prev.alpha_composite(Image.open(f"{OUT}/pupil{nm}.png"), (eye["box"][0], eye["box"][1]))
prev.save("/tmp/v5_prev.png")
bg = Image.new("RGBA", (W, H), (28, 28, 30, 255)); bg.alpha_composite(prev)
bg.convert("RGB").resize((720, 960), Image.LANCZOS).save("/tmp/v5_prev_small.png")
print("done", eL, eR)
