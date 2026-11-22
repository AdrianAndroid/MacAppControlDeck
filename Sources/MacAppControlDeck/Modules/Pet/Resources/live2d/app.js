// Live2D 驱动层。BongoCat 分支按官方 standard/keyboard 模型的参数与事件语义运行。
const Q = new URLSearchParams(location.search);
const MODEL = Q.get('model') || 'bongocat';
const TINT = (Q.get('tint') || 'ffffff').replace('#', '');
const IS_BONGO = MODEL === 'bongocat' || MODEL.startsWith('bongocat-');
const BONGO_MODE = MODEL === 'bongocat-keyboard' ? 'keyboard' : 'standard';
const BONGO_ROOT = 'bongocat-' + BONGO_MODE + '/';
const MODEL_PATH = IS_BONGO ? BONGO_ROOT + 'cat.model3.json' : MODEL + '/' + MODEL + '.model3.json';

const IDS = IS_BONGO ? {
  angleX: 'ParamAngleX', angleY: 'ParamAngleY', angleZ: 'ParamAngleZ',
  eyeX: 'ParamEyeBallX', eyeY: 'ParamEyeBallY',
  eyeL: 'ParamEyeLOpen', eyeR: 'ParamEyeROpen',
  handL: 'CatParamLeftHandDown', handR: 'CatParamRightHandDown',
  mouseX: 'ParamMouseX', mouseY: 'ParamMouseY',
  mouseL: 'ParamMouseLeftDown', mouseR: 'ParamMouseRightDown'
} : {
  angleX: 'PARAM_ANGLE_X', angleY: 'PARAM_ANGLE_Y', angleZ: 'PARAM_ANGLE_Z',
  bodyX: 'PARAM_BODY_ANGLE_X', bodyY: 'PARAM_BODY_ANGLE_Y',
  eyeX: 'PARAM_EYE_BALL_X', eyeY: 'PARAM_EYE_BALL_Y', breath: 'PARAM_BREATH',
  eyeL: 'PARAM_EYE_L_OPEN', eyeR: 'PARAM_EYE_R_OPEN',
  mouth: 'PARAM_MOUTH_OPEN_Y', mouthForm: 'PARAM_MOUTH_FORM'
};

const P = {
  angleX: 0, angleY: 0, bodyX: 0, bodyY: 0,
  eyeBallX: 0, eyeBallY: 0, breath: 0.35,
  blink: 0, mouth: 0, ear: 0,
  pointerX: 0, pointerY: 0, pointerView: '',
  handL: 0, handR: 0, mouseLeft: 0, mouseRight: 0,
  keys: []
};
window.petSet = function (o) { Object.assign(P, o || {}); };
window.petReady = false;
window.petError = null;

const app = new PIXI.Application({
  backgroundAlpha: 0,
  antialias: true,
  resolution: Math.min(window.devicePixelRatio || 2, 2),
  autoDensity: true,
  resizeTo: window
});
document.body.appendChild(app.view);
app.view.style.background = 'transparent';

let model = null;
let scene = null, backgroundSprite = null, keyLayer = null, keySignature = '';
let bongoModelWidth = 0, bongoModelHeight = 0;
const keyTexCache = {};
const keySpriteCache = {};
const ARROW_KEYS = ['LeftArrow', 'RightArrow', 'UpArrow', 'DownArrow'];
const BONGO_OFF_PARTS = ['Part8', 'Part10', 'Part4', 'Part6'];
const BREATH_TARGETS = [
  ['ParamAngleX', 0, 15, 6.5345],
  ['ParamAngleY', 0, 8, 3.5345],
  ['ParamAngleZ', 0, 10, 5.5345],
  ['ParamBodyAngleX', 0, 4, 15.5345],
  ['ParamBreath', 0.5, 0.5, 3.2345]
];
const pointer = { x: 0, y: 0, view: null };

function layout() {
  if (!model) return;
  const w = app.screen.width, h = app.screen.height;
  if (IS_BONGO && scene) {
    // Pixi 的 centeringTransform 已将模型映射到 612×354 画布。
    // 再整体收 6%，在四周留出安全边距，避免键盘底边、鼠标垫左端和猫身贴边裁切。
    const s = Math.min(w / 612, h / 354) * 0.94;
    scene.scale.set(s);
    scene.position.set((w - 612 * s) / 2, (h - 354 * s) / 2);
    if (backgroundSprite) {
      backgroundSprite.scale.set(1);
      backgroundSprite.position.set(0, 0);
    }
    Object.values(keySpriteCache).forEach((sprite) => {
      sprite.scale.set(1);
      sprite.position.set(0, 0);
    });
    model.scale.set(1);
    model.anchor.set(0);
    model.position.set(0, 0);
    let canvas = {};
    try {
      const c = core().getModel().canvasinfo;
      canvas = { width: c.CanvasWidth, height: c.CanvasHeight,
        originX: c.CanvasOriginX, originY: c.CanvasOriginY, ppu: c.PixelsPerUnit };
    } catch (e) {}
    window.petDebug = { s, w, h, mode: 'bongo-' + BONGO_MODE,
      modelWidth: bongoModelWidth, modelHeight: bongoModelHeight, canvas,
      hiddenDrawables: BONGO_MODE === 'standard' ? ['table', 'table2'] : [] };
    return;
  }
  model.scale.set(1);
  model.position.set(0, 0);
  const b = model.getLocalBounds();
  if (!b.width || !b.height) return;
  const s = Math.min((w * 0.96) / b.width, (h * 0.94) / b.height);
  model.scale.set(s);
  const nb = model.getBounds();
  model.position.x += w / 2 - (nb.x + nb.width / 2);
  model.position.y += h * 0.97 - (nb.y + nb.height);
  window.petDebug = { bw: b.width, bh: b.height, s, w, h };
}

window.addEventListener('resize', () => layout());

function core() { return model.internalModel.coreModel; }
function clamp(v, lo, hi) { return Math.min(Math.max(v, lo), hi); }
function set(id, v) {
  try { core().setParameterValueById(id, v); } catch (e) {}
}
function setNormalized(id, value) {
  try {
    const c = core();
    const index = c.getParameterIndex(id);
    if (index < 0 || index >= c.getParameterCount()) return;
    const n = clamp(value, -1, 1);
    const min = c.getParameterMinimumValue(index);
    const max = c.getParameterMaximumValue(index);
    const def = c.getParameterDefaultValue(index);
    const mapped = n >= 0 ? def + (max - def) * n : def + (def - min) * n;
    c.setParameterValueByIndex(index, mapped);
  } catch (e) {}
}
function add(id, value, weight) {
  try { core().addParameterValueById(id, value, weight); } catch (e) {}
}

function hideBongoAccessories() {
  BONGO_OFF_PARTS.forEach((id) => {
    try { core().setPartOpacityById(id, 0); } catch (e) {}
  });
}

function hideBongoModelTable() {
  if (BONGO_MODE !== 'standard') return;
  // 原版 Bongo-Cat-Mver 在模型之后绘制背景；当前背景在模型之下，
  // 因此只关闭模型自带的 table/table2，防止它覆盖背景键盘并产生第二条桌线。
  // 不能关闭整个 Part：rightgand 与这两个桌面网格属于同一部件组。
  try {
    const raw = core().getModel();
    const ids = core().getDrawableIds();
    ['table', 'table2'].forEach((id) => {
      const index = ids.indexOf(id);
      if (index >= 0 && raw.drawables && raw.drawables.opacities) {
        raw.drawables.opacities[index] = 0;
      }
    });
  } catch (e) {}
}

function updatePointer(dt) {
  if (pointer.view !== P.pointerView) {
    pointer.view = P.pointerView;
    pointer.x = P.pointerX;
    pointer.y = P.pointerY;
    return;
  }
  const frames = Math.max(dt, 0) / 1000 * 60;
  const alpha = 1 - Math.pow(0.75, frames);
  pointer.x += (P.pointerX - pointer.x) * alpha;
  pointer.y += (P.pointerY - pointer.y) * alpha;
  if (Math.hypot(P.pointerX - pointer.x, P.pointerY - pointer.y) < 0.0005) {
    pointer.x = P.pointerX;
    pointer.y = P.pointerY;
  }
}

// 官方顺序中的 input + automatic effects：由 afterMotionUpdate 接入，
// 随后仍由运行库执行 physics → pose → core.update。
function applyBongoParameters() {
  const x = pointer.x, y = pointer.y, z = clamp(-x * y, -1, 1);
  setNormalized(IDS.mouseX, x);
  setNormalized(IDS.mouseY, y);
  setNormalized(IDS.angleX, x);
  setNormalized(IDS.angleY, y);
  setNormalized(IDS.angleZ, z);
  setNormalized(IDS.eyeX, x);
  setNormalized(IDS.eyeY, y);
  setNormalized(IDS.handL, P.handL ? 1 : 0);
  setNormalized(IDS.handR, P.handR ? 1 : 0);
  setNormalized(IDS.mouseL, P.mouseLeft ? 1 : 0);
  setNormalized(IDS.mouseR, P.mouseRight ? 1 : 0);

  const seconds = performance.now() / 1000;
  BREATH_TARGETS.forEach(([id, offset, peak, cycle]) => {
    add(id, offset + peak * Math.sin(Math.PI * 2 * seconds / cycle), 0.5);
  });
  const blink = seconds % 5 < 0.18 ? -1 : 0;
  setNormalized(IDS.eyeL, blink);
  setNormalized(IDS.eyeR, blink);
  window.petBongoInput = { x, y, z, handL: P.handL, handR: P.handR,
    mouseLeft: P.mouseLeft, mouseRight: P.mouseRight, keys: P.keys };
}

function updateKeyOverlays() {
  if (!keyLayer) return;
  const keys = Array.isArray(P.keys) ? P.keys : [];
  const signature = keys.join('|');
  if (signature === keySignature) return;
  keySignature = signature;
  keyLayer.removeChildren();
  const seen = new Set();
  keys.forEach((code) => {
    const dir = BONGO_MODE === 'keyboard' && ARROW_KEYS.includes(code) ? 'right-keys' : 'left-keys';
    const url = BONGO_ROOT + 'resources/' + dir + '/' + code + '.png';
    if (seen.has(url)) return;
    seen.add(url);
    if (!keyTexCache[url]) keyTexCache[url] = PIXI.Texture.from(url);
    if (!keySpriteCache[url]) {
      const sprite = new PIXI.Sprite(keyTexCache[url]);
      sprite.width = 612;
      sprite.height = 354;
      keySpriteCache[url] = sprite;
    }
    keyLayer.addChild(keySpriteCache[url]);
  });
}

PIXI.live2d.Live2DModel
  .from(MODEL_PATH, { autoInteract: false, autoUpdate: false })
  .then((m) => {
    model = m;
    if (IS_BONGO) {
      bongoModelWidth = m.width;
      bongoModelHeight = m.height;
      scene = new PIXI.Container();
      backgroundSprite = PIXI.Sprite.from(BONGO_ROOT + 'resources/background.clean.png');
      backgroundSprite.width = 612;
      backgroundSprite.height = 354;
      keyLayer = new PIXI.Container();
      scene.addChild(backgroundSprite);
      scene.addChild(m);
      scene.addChild(keyLayer);
      app.stage.addChild(scene);
      hideBongoAccessories();
      // 关闭运行库自带的另一套视线/呼吸/眨眼，避免与官方参数公式叠加两次。
      m.internalModel.eyeBlink = null;
      m.internalModel.breath = null;
      m.internalModel.updateFocus = function () {};
      m.internalModel.on('afterMotionUpdate', applyBongoParameters);
    } else {
      app.stage.addChild(m);
      try { m.internalModel.motionManager.startRandomMotion('Idle', 3); } catch (e) {}
    }
    if (TINT.toLowerCase() !== 'ffffff') {
      const r = parseInt(TINT.slice(0, 2), 16) / 255;
      const g = parseInt(TINT.slice(2, 4), 16) / 255;
      const b = parseInt(TINT.slice(4, 6), 16) / 255;
      const f = new PIXI.filters.ColorMatrixFilter();
      f.matrix = [r, 0, 0, 0, 0, 0, g, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
      m.filters = [f];
    }
    layout();
    try {
      const p = core();
      window.petIds = (p._model && p._model.parameters && p._model.parameters.ids) || p._parameterIds || [];
      window.petIdCount = window.petIds.length || 0;
    } catch (e) { window.petIds = ['probe:' + e]; }
    window.petReady = true;
  })
  .catch((e) => { window.petError = String(e && e.message || e); });

app.ticker.add(() => {
  if (!model) return;
  const dt = app.ticker.deltaMS || 16.7;
  if (IS_BONGO) {
    updatePointer(dt);
    model.update(dt);
    hideBongoModelTable();
    updateKeyOverlays();
    return;
  }
  model.update(dt);
  set(IDS.angleX, P.angleX);
  set(IDS.angleY, P.angleY);
  set(IDS.angleZ, P.angleX * 0.12);
  set(IDS.bodyX, P.bodyX);
  set(IDS.bodyY, P.bodyY);
  set(IDS.eyeX, P.eyeBallX);
  set(IDS.eyeY, P.eyeBallY);
  set(IDS.breath, P.breath);
  const open = 1 - P.blink;
  set(IDS.eyeL, open);
  set(IDS.eyeR, open);
  set(IDS.mouth, P.mouth);
  set(IDS.mouthForm, -0.2 + P.mouth * 0.3);
  set('PARAM_EYE_FORM', 0);
  set('PARAM_EAR_L', P.ear);
  set('PARAM_EAR_R', P.ear);
});
