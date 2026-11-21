#!/usr/bin/env python3
"""v6 full-body rig asset builder  —— 三母版 -> 12 层 + manifest.

母版：
  Docs/design/v6-cat-master.png      1373x1717 纯白底黑猫
  Docs/design/v6-keyboard-master.png 透明底 白键盘（两端橙键）
  Docs/design/v6-mouse-master.png    透明底 白鼠标

产物：Sources/MacAppControlDeck/Modules/Pet/Resources/v6/*.png + manifest.json
画布：1440x1920 asset px（design 720x960，scale 2）
"""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
from scipy import ndimage as ndi
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'Sources/MacAppControlDeck/Modules/Pet/Resources/v6')
W, H = 1440, 1920

def ep(*p):
    return os.path.join(HERE, *p)

# ---------------------------------------------------------------- helpers
def soft_mask(size, polygons, feather=8, holes=()):
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    for poly in polygons:
        d.polygon(poly, fill=255)
    for poly in holes:
        d.polygon(poly, fill=0)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather / 2.0))
    return np.array(m).astype(np.float32) / 255.0

def disc_mask(size, center, r, feather=3):
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather / 2.0))
    return np.array(m).astype(np.float32) / 255.0

def apply_mask(img, mask):
    a = np.array(img).astype(np.float32)
    a[..., 3] = a[..., 3] * mask
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')

def diffuse_fill(img, hole_mask, radius=18, iters=3):
    """把需要补的区域用最近的有效毛色向外扩散，得到柔和的黑毛填充。"""
    a = np.array(img).astype(np.float32)
    hole = hole_mask > 0.5
    if not hole.any():
        return img
    rgb = a[..., :3]
    valid = (~hole) & (a[..., 3] > 60)
    if not valid.any():
        return img
    idx = ndi.distance_transform_edt(~valid, return_distances=False, return_indices=True)
    seeded = rgb[tuple(idx)].copy()
    sealed = np.where(hole[..., None], 0.0, rgb)
    for _ in range(iters):
        blurred = ndi.gaussian_filter(seeded, radius)
        seeded = np.where(hole[..., None], blurred, seeded)
    filled = np.where(hole[..., None], ndi.gaussian_filter(seeded, radius * 0.5), rgb)
    out = np.dstack([np.clip(filled, 0, 255), a[..., 3]])
    return Image.fromarray(out.astype(np.uint8), 'RGBA')

# ---------------------------------------------------------------- cat master
def cat_alpha(src_path):
    src = Image.open(src_path).convert('RGB')
    a = np.array(src).astype(np.float32)
    lum = a.mean(2); sat = a.max(2) - a.min(2)
    bg = (lum > 206) & (sat < 34)
    lab, _ = ndi.label(bg)
    bgmask = np.isin(lab, [1])
    P = 4
    bgm = np.pad(bgmask, P, constant_values=True)
    bgm = ndi.binary_closing(bgm, np.ones((7, 7)))
    bgm = ndi.binary_dilation(bgm, np.ones((3, 3)))
    fg = ndi.binary_fill_holes(~bgm[P:-P, P:-P])
    lab2, n2 = ndi.label(fg)
    sizes = ndi.sum(fg, lab2, range(1, n2 + 1))
    fg = lab2 == (np.argmax(sizes) + 1)
    alpha = np.array(Image.fromarray((fg * 255).astype(np.uint8))
                     .filter(ImageFilter.GaussianBlur(0.9))).astype(np.float32) / 255.0
    alpha[alpha < 0.06] = 0
    al = np.clip(alpha, 1e-3, 1)[..., None]
    rgb = np.clip((a - 255 * (1 - al)) / al, 0, 255)
    return Image.fromarray(np.dstack([rgb, (alpha ** 1.12) * 255]).astype(np.uint8), 'RGBA')

# ---------------------------------------------------------------- layout
CAT_W, CAT_H = 1373, 1717
CAT_SCALE = 1.05
CAT_DY = 92
CAT_DX = W / 2 - CAT_W * CAT_SCALE / 2

def tx(x):
    return CAT_DX + x * CAT_SCALE

def ty(y):
    return CAT_DY + y * CAT_SCALE

def ts(v):
    return v * CAT_SCALE

# landmarks in master px
EYE_L = (462, 784, 70, 30)   # cx cy irisR pupilR
EYE_R = (702, 766, 76, 33)
NECK = (600, 1012)
SHOULDER_L = (505, 1000)
SHOULDER_R = (742, 1024)
PAW_L = (462, 1300)
PAW_R = (700, 1198)
HIP = (600, 1240)
TAIL_ROOT = (968, 1234)
TAIL_MID = (1112, 1244)
EAR_L_BASE = (470, 658)
EAR_R_BASE = (738, 658)

POLY = {
    'head': [[(300, 700), (300, 640), (330, 520), (396, 468), (446, 524), (505, 612),
              (565, 600), (632, 560), (702, 520), (762, 500), (818, 446), (872, 548),
              (896, 644), (906, 724), (900, 806), (888, 884), (858, 952), (818, 1012),
              (760, 1054), (660, 1078), (560, 1078), (468, 1052), (398, 1002), (338, 932),
              (306, 842), (300, 762)]],
    'earL': [[(320, 664), (304, 590), (344, 492), (394, 528), (442, 602), (472, 664),
              (480, 706), (326, 706)]],
    'earR': [[(696, 700), (706, 638), (750, 536), (812, 448), (868, 560), (890, 652),
              (894, 706), (696, 706)]],
    'armL': [[(370, 1332), (366, 1248), (392, 1156), (430, 1058), (472, 996),
              (542, 982), (588, 1020), (562, 1102), (536, 1192), (534, 1274),
              (542, 1342), (472, 1364), (392, 1352)]],
    'armR': [[(626, 1264), (610, 1200), (620, 1138), (650, 1086), (692, 1040),
              (738, 1012), (792, 1008), (802, 1056), (762, 1092), (744, 1144),
              (754, 1202), (772, 1252), (744, 1274), (680, 1274)]],
    'tail1': [[(928, 1212), (1006, 1194), (1078, 1204), (1120, 1236), (1124, 1292),
               (1078, 1314), (1010, 1298), (950, 1272), (926, 1240)]],
    'tail2': [[(1114, 1228), (1164, 1224), (1218, 1244), (1250, 1288), (1248, 1350),
               (1200, 1384), (1128, 1384), (1082, 1346), (1072, 1312), (1098, 1300)]],
}

def main():
    os.makedirs(OUT, exist_ok=True)
    cat = cat_alpha(ep('v6-cat-master.png'))
    cat.save('/tmp/v6_cat_rgba.png')
    A = np.array(cat).astype(np.float32)
    lum = A[..., :3].mean(2)
    size = (CAT_W, CAT_H)

    hard = {k: (soft_mask(size, v, feather=0) > 0.5) for k, v in POLY.items()}
    def grown(k, px=12, feather=3):
        """外扩后的软边遮罩：与相邻层重叠，消除拼接透明缝。"""
        m = ndi.binary_dilation(hard[k], iterations=px) | hard[k]
        m = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(feather / 2.0))
        return np.array(m).astype(np.float32) / 255.0

    masks = {k: soft_mask(size, v, feather=6) for k, v in POLY.items()}

    # ---------- eyes: iris / pupil, and head socket fill
    eyes = {}
    socket = np.zeros((CAT_H, CAT_W), np.float32)
    for tag, (ex, ey, ir, pr) in (('l', EYE_L), ('r', EYE_R)):
        disc = disc_mask(size, (ex, ey), ir + 2, feather=3)
        inner = disc_mask(size, (ex, ey), ir, feather=4)
        dark = (lum < 72) & (inner > 0.5)
        lab, n = ndi.label(dark)
        if n:
            sizes = ndi.sum(dark, lab, range(1, n + 1))
            k = np.argmax(sizes) + 1
            ys, xs = np.where(lab == k)
            pcenter = (float(xs.mean()), float(ys.mean()))
            prad = float(np.sqrt(len(xs) / np.pi))
            pupil = disc_mask(size, pcenter, prad + 1.5, feather=3) * inner
        else:
            pcenter, prad, pupil = (ex, ey), pr, disc_mask(size, (ex, ey), pr)
        iris_clean = diffuse_fill(apply_mask(cat, inner), pupil > 0.4, radius=12, iters=4)
        eyes[f'iris_{tag}'] = apply_mask(iris_clean, inner)
        eyes[f'pupil_{tag}'] = apply_mask(cat, pupil)
        socket = np.clip(socket + disc_mask(size, (ex, ey), ir + 9, feather=10), 0, 1)
        print(f'[eye] {tag} pupil@({pcenter[0]:.0f},{pcenter[1]:.0f}) r={prad:.1f}')

    head_mask = grown('head', 12, 3)
    head = apply_mask(cat, head_mask)
    head = diffuse_fill(head, socket > 0.5, radius=18, iters=4)
    head = apply_mask(head, head_mask)
    head.save(os.path.join(OUT, 'head.png'))

    # ---------- torso：保留整只猫的真实像素（黑毛底下再压一层黑毛，转动时不会露白），
    #            只把眼窝补成毛色，防止头部转动时露出“旧眼睛”。
    torso = diffuse_fill(cat, socket > 0.5, radius=18, iters=4)
    torso.save(os.path.join(OUT, 'torso.png'))

    for k in ['earL', 'earR', 'armL', 'armR', 'tail1', 'tail2']:
        apply_mask(cat, grown(k, 12, 3)).save(os.path.join(OUT, f'{k}.png'))
    for k, im in eyes.items():
        im.save(os.path.join(OUT, f'{k}.png'))

    neck = apply_mask(cat, soft_mask(size, [[(386, 902), (816, 902), (842, 1140), (368, 1140)]], feather=18))
    neck.save(os.path.join(OUT, 'neck.png'))
    print('[ok] cat layers')

    # ---------------------------------------------------------------- canvas placement
    manifest_layers = {}

    def put_cat(name, img, pivot=None, extra=None):
        """把 master 空间的层缩放贴到 1440x1920 画布，裁到 alpha bbox，记录 box。"""
        nw, nh = int(CAT_W * CAT_SCALE), int(CAT_H * CAT_SCALE)
        canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        canvas.alpha_composite(img.resize((nw, nh), Image.LANCZOS), (int(CAT_DX), CAT_DY))
        bbox = canvas.getbbox() or (0, 0, 1, 1)
        crop = canvas.crop(bbox)
        crop.save(os.path.join(OUT, f'{name}.png'))
        entry = {'box': [bbox[0], bbox[1], bbox[2] - bbox[0], bbox[3] - bbox[1]]}
        if pivot is not None:
            entry['pivot'] = [round(tx(pivot[0]) - bbox[0], 1), round(ty(pivot[1]) - bbox[1], 1)]
        if extra:
            entry.update(extra)
        manifest_layers[name] = entry
        return entry

    put_cat('torso', torso,
            pivot=HIP,
            extra={'hipScreen': [round(tx(HIP[0]), 1), round(ty(HIP[1]), 1)]})
    put_cat('tail1', Image.open(os.path.join(OUT,'tail1.png')), pivot=TAIL_ROOT,
            extra={'rootScreen': [round(tx(TAIL_ROOT[0]), 1), round(ty(TAIL_ROOT[1]), 1)]})
    put_cat('tail2', Image.open(os.path.join(OUT,'tail2.png')), pivot=TAIL_MID,
            extra={'rootScreen': [round(tx(TAIL_MID[0]), 1), round(ty(TAIL_MID[1]), 1)]})
    put_cat('armL', Image.open(os.path.join(OUT,'armL.png')), pivot=SHOULDER_L,
            extra={'shoulderScreen': [round(tx(SHOULDER_L[0]), 1), round(ty(SHOULDER_L[1]), 1)],
                   'pawScreen': [round(tx(PAW_L[0]), 1), round(ty(PAW_L[1]), 1)]})
    put_cat('armR', Image.open(os.path.join(OUT,'armR.png')), pivot=SHOULDER_R,
            extra={'shoulderScreen': [round(tx(SHOULDER_R[0]), 1), round(ty(SHOULDER_R[1]), 1)],
                   'pawScreen': [round(tx(PAW_R[0]), 1), round(ty(PAW_R[1]), 1)]})
    put_cat('neck', Image.open(os.path.join(OUT,'neck.png')), pivot=NECK)
    put_cat('head', Image.open(os.path.join(OUT,'head.png')), pivot=NECK,
            extra={'headScreen': [round(tx(NECK[0]), 1), round(ty(NECK[1]), 1)]})
    put_cat('earL', Image.open(os.path.join(OUT,'earL.png')), pivot=EAR_L_BASE)
    put_cat('earR', Image.open(os.path.join(OUT,'earR.png')), pivot=EAR_R_BASE)
    for tag, (ex, ey, ir, pr) in (('l', EYE_L), ('r', EYE_R)):
        put_cat(f'iris_{tag}', Image.open(os.path.join(OUT,f'iris_{tag}.png')), pivot=(ex, ey),
                extra={'eyeScreen': [round(tx(ex), 1), round(ty(ey), 1)],
                       'eyeRadius': round(ts(ir), 1)})
        put_cat(f'pupil_{tag}', Image.open(os.path.join(OUT,f'pupil_{tag}.png')), pivot=(ex, ey),
                extra={'eyeScreen': [round(tx(ex), 1), round(ty(ey), 1)]})

    # ---------------------------------------------------------------- keyboard / mouse
    KB_W = 1000
    KB_CX = 700
    KB_TOP = 1466
    kb_src = Image.open(ep('v6-keyboard-master.png')).convert('RGBA')
    kbb = kb_src.getbbox()
    kb_img = kb_src.crop(kbb)
    scale = KB_W / kb_img.width
    kb_h = int(round(kb_img.height * scale))
    kb_img = kb_img.resize((KB_W, kb_h), Image.LANCZOS)
    kb_entry = {'box': [int(KB_CX - KB_W / 2), KB_TOP, KB_W, kb_h], 'imageScale': round(scale, 4),
                'rows': 4, 'cols': 13}
    kb_img.save(os.path.join(OUT, 'keyboard.png'))
    manifest_layers['keyboard'] = kb_entry

    MO_W = 236
    mo_src = Image.open(ep('v6-mouse-master.png')).convert('RGBA')
    mo_img = mo_src.crop(mo_src.getbbox())
    scale = MO_W / mo_img.width
    mo_img = mo_img.resize((MO_W, int(round(mo_img.height * scale))), Image.LANCZOS)
    mo_bottom = KB_TOP + kb_h - 22
    mo_x = min(1222, W - mo_img.width - 10)
    mo_box = [int(mo_x), int(mo_bottom - mo_img.height), mo_img.width, mo_img.height]
    mo_img.save(os.path.join(OUT, 'mouse.png'))
    manifest_layers['mouse'] = {'box': mo_box}

    # ---------------------------------------------------------------- shadow
    sh = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(sh)
    d.ellipse([KB_CX - 560, KB_TOP + 300, KB_CX + 560, KB_TOP + kb_h + 120], fill=180)
    sh = sh.filter(ImageFilter.GaussianBlur(70))
    shadow = Image.new('RGBA', (W, H), (12, 10, 14, 0))
    shadow.putalpha(sh)
    sh_box = shadow.getbbox()
    shadow.crop(sh_box).save(os.path.join(OUT, 'shadow.png'))
    manifest_layers['shadow'] = {'box': [sh_box[0], sh_box[1], sh_box[2] - sh_box[0], sh_box[3] - sh_box[1]]}

    # ---------------------------------------------------------------- keycap (procedural template)
    kb_w, kb_h2 = KB_W, kb_h
    cap_w, cap_h = 62, 56
    cap = Image.new('RGBA', (cap_w, cap_h + 18), (0, 0, 0, 0))
    dc = ImageDraw.Draw(cap)
    dc.rounded_rectangle([1, 14, cap_w - 1, cap_h + 16], radius=9, fill=(246, 241, 229, 255),
                        outline=(214, 205, 186, 255), width=2)
    dc.rounded_rectangle([4, 2, cap_w - 4, 20], radius=8, fill=(252, 249, 242, 255))
    cap.save(os.path.join(OUT, 'keycap.png'))
    manifest_layers['keycap'] = {'box': [0, 0, cap_w, cap_h + 18]}

    # ---------------------------------------------------------------- manifest
    def sp(v):
        return round(v / 2.0, 1)   # asset px -> design px

    manifest = {
        'version': 6,
        'designSize': [720, 960],
        'scale': 2,
        'canvas': [W, H],
        'order': ['shadow', 'keyboard', 'keycap', 'tail1', 'tail2', 'mouse',
                  'torso', 'armL', 'armR', 'neck', 'head', 'earL', 'earR',
                  'iris_l', 'pupil_l', 'iris_r', 'pupil_r'],
        'layers': manifest_layers,
        'rig': {
            'neck': [round(tx(NECK[0]) / 2, 1), round(ty(NECK[1]) / 2, 1)],
            'hip': [round(tx(HIP[0]) / 2, 1), round(ty(HIP[1]) / 2, 1)],
            'shoulderL': [round(tx(SHOULDER_L[0]) / 2, 1), round(ty(SHOULDER_L[1]) / 2, 1)],
            'shoulderR': [round(tx(SHOULDER_R[0]) / 2, 1), round(ty(SHOULDER_R[1]) / 2, 1)],
            'pawL': [round(tx(PAW_L[0]) / 2, 1), round(ty(PAW_L[1]) / 2, 1)],
            'pawR': [round(tx(PAW_R[0]) / 2, 1), round(ty(PAW_R[1]) / 2, 1)],
            'tailRoot': [round(tx(TAIL_ROOT[0]) / 2, 1), round(ty(TAIL_ROOT[1]) / 2, 1)],
            'tailMid': [round(tx(TAIL_MID[0]) / 2, 1), round(ty(TAIL_MID[1]) / 2, 1)],
            'earLBase': [round(tx(EAR_L_BASE[0]) / 2, 1), round(ty(EAR_L_BASE[1]) / 2, 1)],
            'earRBase': [round(tx(EAR_R_BASE[0]) / 2, 1), round(ty(EAR_R_BASE[1]) / 2, 1)],
            'eyeL': [round(tx(EYE_L[0]) / 2, 1), round(ty(EYE_L[1]) / 2, 1)],
            'eyeR': [round(tx(EYE_R[0]) / 2, 1), round(ty(EYE_R[1]) / 2, 1)],
            'eyeRadius': [round(ts(EYE_L[2]) / 2, 1), round(ts(EYE_R[2]) / 2, 1)],
            'gazeRange': [round(ts(22) / 2, 1), round(ts(14) / 2, 1)],
            'pupilRange': [round(ts(26) / 2, 1), round(ts(16) / 2, 1)],
            'headYaw': 8.0, 'headPitch': 4.0,
            'torsoLean': 3.5, 'torsoBreathe': 0.008,
            'tailSwing': 7.0, 'earTwitch': 6.0,
            'armSwing': 9.0,
            'keycapRise': round(170 / 2, 1),
            'keycapLife': 0.8,
        },
        'keyboardBox': [round(sp(70) * 2, 1), 0, 0, 0],
    }
    # keyboard grid geometry (design px)
    manifest['keyboardGrid'] = {
        'box': [round(kb_entry['box'][0] / 2, 1), round(kb_entry['box'][1] / 2, 1),
                round(kb_entry['box'][2] / 2, 1), round(kb_entry['box'][3] / 2, 1)],
        'backRowY': round((KB_TOP + 118) / 2, 1),
        'rowGap': round(ts(0) / 2 + 38, 1),
        'colStartX': round((KB_CX - KB_W / 2 + 66) / 2, 1),
        'colGap': round((KB_W - 132) / 2 / 13, 1),
    }
    del manifest['keyboardBox']
    with open(os.path.join(OUT, 'manifest.json'), 'w') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    # ---------------------------------------------------------------- preview
    prev = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for name in manifest['order']:
        e = manifest_layers[name]
        im = Image.open(os.path.join(OUT, f'{name}.png')).convert('RGBA')
        prev.alpha_composite(im, (e['box'][0], e['box'][1]))
    desk = Image.new('RGBA', (W, H), (244, 242, 238, 255))
    desk.alpha_composite(prev)
    desk.convert('RGB').save('/tmp/v6_preview.png')
    desk.convert('RGB').resize((W // 3, H // 3), Image.LANCZOS).save('/tmp/v6_preview_small.png')
    print('[ok] done ->', OUT)

if __name__ == '__main__':
    main()
