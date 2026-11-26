# 副屏宠物卡：「像素猫追像素鼠」设计（2026-11-27）

> 目标：卡片里**老鼠在前跑、猫在后追**，跑到一头直接掉头。
> 两只都是有身体、四条腿、有颜色的像素角色，要能看出"在跑"。
> 本文只做设计，不含实现。

## 1. 从手绘草图读到的比例

草图（`macapp-controldeck/ui-sketch`）画的是同一只动物两遍，实测包围盒：

| 元素 | 尺寸 | 说明 |
| --- | --- | --- |
| 整体 | 202 × 104 | 宽高比 **1.94 : 1**，明显的侧身长条 |
| 身体轮廓 | 100 × 93 | **一个连续整体**，头身不分块，顶部有耳窝凹陷 |
| 下身/腹部 | 121 × 46 | 横向铺开，比身体更宽 |
| 四条腿 | 45–58 长 | 占整体高度约 45%，**腿间有明显空隙** |
| 耳朵 | 2 条竖线 | 头顶两只 |

由此得到三条硬约束，直接推翻上一版的 Q 版方块：

1. **身体必须是一整块**（头、颈、背、臀连成一条），不能画成"头 + 方块身"
2. **四条腿要真的分开**，且长度接近身体高度的一半
3. 整体是**扁长侧身**，不是圆球

## 2. 像素规格

| 项 | 猫 | 鼠 |
| --- | --- | --- |
| 网格 | 20 × 12 格 | 13 × 8 格 |
| 每格 | `0.55u`（≈3.3px） | 同左 |
| 中档实际尺寸 | 66 × 40px | 43 × 26px |
| 宽高比 | 1.67 : 1 | 1.63 : 1 |

猫 20 格 × `0.55u` = `11u`，**正好等于现有 `.pet-walker` 的宽度**，布局不用改。

## 3. 调色板

```
.  透明
o  描边     猫 #8a4a1e   鼠 #495366
B  主体     猫 #f0a05c   鼠 #b9bfca
D  远侧腿/暗部  猫 #b8642a   鼠 #7c8494
L  亮部（背线）  猫 #ffcf9a   鼠 #e4e8ef
W  爪        #fff3e6
P  鼻/耳内   #f78fa0
E  眼        #1b1b1f
```

**两个关键点：**

- 描边**不能用纯黑**——副屏背景是 `#000`，纯黑贴黑底等于没轮廓。用暗 40% 的同色系
- 远侧两条腿用 `D`（更暗），近侧用 `B`。这是像素四足动物唯一能同时读出四条腿的办法

## 4. 猫（20 × 12，朝右）

**帧 A：接触帧（后腿在后、前腿在前，腿张开最大）**

```
01234567890123456789
..............o..o..   r0   耳尖 x14 / x17
.............oBooBo.   r1   两耳之间的凹陷
o...........oBBBBBBo   r2   尾尖 x0 + 头顶
oBo........oBBEBBEBo   r3   尾 + 双眼 x14 / x17
.oBBo.....oBBBBBBBPo   r4   尾 + 粉鼻 x18
.oBBBBBBBBBBBBBBBBBo   r5   背线
oBBBBBBBBBBBBBBBBBBo   r6   臀 → 身（最宽一行）
.oBBBBBBBBBBBBBBBBo.   r7
..oBBBBBBBBBBBBBBo..   r8   腹
..oDo.oBBo.oDo.oBBo.   r9   四条腿：远D·近B·远D·近B
..oDo.oBBo.oDo.oBBo.   r10
..oWo.oWWo.oWo.oWWo.   r11  白爪
```

读图方式：

- `o...........oBBBBBBo` 这一行左边孤零零的 `o` 是**尾巴**，右边是头
- 从 r5 到 r8 是一条连续的宽身，头在右端自然收窄成吻部
- r9 起四条腿：`D` 是远侧（被身体挡一半，所以画暗）、`B` 是近侧

**帧 B：通过帧（腿收向中线、身体整体抬高 1 格 = 腾空）**

```
..oDo.oBBo.oDo.oBBo.   r8   腹下直接接腿
...oDo.oBo.oDo.oBo..   r9   四腿各内收 1 格
...oDo.oBo.oDo.oBo..   r10
...oWo.oWo.oWo.oWo..   r11
```

> 帧 B 的完整图 = 帧 A 的 r0–r7 **整体上移 1 格**（耳尖到 r-1 被裁掉，头顶圆角顶上），
> 上面只列变化最大的腿部三行。

两帧差异只有两处：**腿的横向位置**（张开 ↔ 收拢）和**身体整体 1 格位移**。
3.3px/格 → 屏幕上 3.3px 弹跳，30fps 下 110ms/帧，眼睛直接读成小跑。

## 5. 鼠（13 × 8，朝右）

**帧 A：接触帧**

```
0123456789012
.............   r0
.........o.o.   r1   耳尖 x9 / x11
o.......oBBBBo   r2   尾尖 x0 + 头
oBo....oBBBPBo   r3   尾 + 粉鼻 x12
.oBBBBBBBBBBo   r4   身
..oBBBBBBBBo.   r5
..oBo.oBo.oBo   r6   三腿（鼠只看得到三条）
..oWo.oWo.oWo   r7   白爪
```

**帧 B：通过帧（身体抬高 1 格，腿收拢）**

```
..oBBBBBBBBo.   r4
...oBBBBBBo..   r5
...oBo.oBo.o.   r6   腿收向中线
...oWo.oWo.o.   r7
```

鼠和猫的三处不同：

- **尾巴更长更翘**（r2–r3 的 x0–x2），跑动时尾巴甩动只靠换帧，不写额外动画
- **三腿**：远侧只画一条，近侧两条，读起来更轻快
- 身形更瘦：身体只有 2 行厚，猫有 4 行

## 6. 同屏效果

```
帧 A（接触，身体压低、腿张开）
┌──────────────────────────────────────────────────────┐
│                                                      │
│   🐭                        🐱                        │
│  （瘦身·翘尾·三腿张开）  （长身·翘尾·四腿张开·远腿偏暗）  │
│  ────────────────────────────────────────────────    │
└──────────────────────────────────────────────────────┘

帧 B（通过，整体抬高 1 格、腿收拢）—— 110ms 后
┌──────────────────────────────────────────────────────┐
│                                                      │
│   🐭                        🐱                        │
│  （抬高 1 格·腿收拢）    （抬高 1 格·腿收拢）            │
│  ────────────────────────────────────────────────    │
└──────────────────────────────────────────────────────┘

两帧交替 = 八条腿在拍地，两只同时在弹。
```

上面两张 ASCII 就是最终像素（实现时允许 1–2 格微调，以真机截图为准）。

## 7. 追逐机制（沿用，未改）

1. 猫和鼠是**一对刚体**：鼠始终领先 `d` 像素，同速同向
2. 鼠的前缘碰到边界（留 10px）→ **两只同时掉头 + 位置镜像**
3. 其他什么都不做：不刹车、不跃过、不错身

```
右跑
┌──────────────────────────────────────┐
│   🐭→              🐱→              │   鼠领先 d
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│                 🐭→      🐱→        │   鼠接近右边界
└──────────────────────────────────────┘
触边：方向取反 + 两只镜像
┌──────────────────────────────────────┐
│   🐭←              🐱←              │   鼠仍在前面，猫仍在后面
└──────────────────────────────────────┘
```

```
dir'    = -dir
catX'   = W - catW - catX
mouseX' = catX' + dir' * (catW - 6)     // 鼠前缘紧贴猫前缘前方 6px
```

**为什么镜像**：只翻方向的话，鼠会瞬间变成"在猫后面"甚至穿过猫；
镜像一次后"前还是前、后还是后"，不需要 z-order，也不需要错身动画。

## 8. 渲染方案：ASCII → SVG path（推荐）

| 方案 | 体积 | 改图成本 | DOM 节点 | 结论 |
| --- | --- | --- | --- | --- |
| **ASCII → SVG `<path>`** | 0（代码内） | 改字符 | 每帧 4–6 个 path | **选它** |
| 预生成 sprite sheet PNG（base64） | ~3KB/角色 | 要跑构建脚本、二进制 diff | 1 个 img | 备选 |
| `<rect>` 逐格 | 0 | 改字符 | 每帧 ~50 个 | 可行但多余 |

**同色横向连续格合并成一条 path 子路径**，一个颜色一个 `<path>`：

```js
// 数据就是上面那张 ASCII 图，改图 = 改字符
var CAT_A = [
  '..............o..o..',
  '.............oBooBo.',
  'o...........oBBBBBBo',
  'oBo........oBBEBBEBo',
  '.oBBo.....oBBBBBBBPo',
  '.oBBBBBBBBBBBBBBBBBo',
  'oBBBBBBBBBBBBBBBBBBo',
  '.oBBBBBBBBBBBBBBBBo.',
  '..oBBBBBBBBBBBBBBo..',
  '..oDo.oBBo.oDo.oBBo.',
  '..oDo.oBBo.oDo.oBBo.',
  '..oWo.oWWo.oWo.oWWo.'
];

function pixelPaths(rows, palette) {          // 字符串网格 → 每色一条 path
  var byColor = {};
  rows.forEach(function (row, y) {
    var x = 0;
    while (x < row.length) {
      var ch = row[x];
      if (ch === '.') { x++; continue; }
      var run = 1;
      while (x + run < row.length && row[x + run] === ch) { run++; }
      (byColor[ch] = byColor[ch] || []).push('M' + x + ' ' + y + 'h' + run + 'v1h-' + run + 'z');
      x += run;
    }
  });
  return Object.keys(byColor).map(function (ch) {
    return '<path d="' + byColor[ch].join('') + '" fill="' + palette[ch] + '"/>';
  }).join('');
}
```

一只猫一帧 = **6 条 path**（o/B/D/W/P/E），两帧 12 条；鼠一帧 4 条。
整个追逐层常驻 DOM 约 20 个 path，比现在 4 只宠物加起来还轻。

`shape-rendering="crispEdges"` 保证格子边缘不出现半像素模糊。

## 9. DOM 与 JS 结构

追逐**独立一层**，不碰现有 `petWalker` 的测量逻辑（`petMeasure` 用 `offsetWidth` 算 `maxX`）：

```html
<div class="pet-box" id="petBox">
  <div class="pet-walker" id="petWalker">…现有 4 只宠物…</div>
  <div class="pet-chase" id="petChase" hidden>
    <div class="chase-sprite" id="chaseMouse"></div>
    <div class="chase-sprite" id="chaseCat"></div>
  </div>
  <div class="pet-caption">…</div>
</div>
```

```css
.pet-chase { position: absolute; inset: 0; overflow: hidden; }
.pet-chase[hidden] { display: none; }          /* 不在追逐时整层不绘制 */
.chase-sprite { position: absolute; left: 0; bottom: calc(var(--u) * 1.6);
                width: calc(var(--u) * 11); height: calc(var(--u) * 6.6);
                will-change: transform; }
.chase-sprite svg { width: 100%; height: 100%; display: block;
                    shape-rendering: crispEdges; }
#chaseMouse { width: calc(var(--u) * 7.15); height: calc(var(--u) * 4.4); }
.chase-sprite[data-frame="1"] .f0 { display: none; }
.chase-sprite[data-frame="0"] .f1 { display: none; }
```

每帧只做三件事，全部是写：

1. `chaseCat.style.transform = translate3d(catX,0,0)`
2. `chaseMouse.style.transform = translate3d(mouseX,0,0)`
3. 腿帧到了就改 `dataset.frame`

零 DOM 读取，沿用现有单一 rAF / 30fps。

> `.chase-sprite` 高度取 `6.6u`（12 格），走路时靠 `bottom: 1.6u` 对齐地面线；
> 身体"腾空 1 格"由像素图自身向上偏移实现，不改容器高度，避免触发重排。

## 10. 节奏与尺寸

| 参数 | 值 |
| --- | --- |
| 速度 | `0.09 px/ms`（待机 `0.035` 的 2.6 倍，小跑） |
| 腿帧 | `110ms`（30fps 下约 3.3 个 tick） |
| 一轮 | 约 6s（跑满一个来回） |
| 间距 d（中档） | 30px（鼠前缘到猫前缘） |
| 三档缩放 | 小 `0.82` / 中 `1` / 大 `1.18`，跟 `--scale` 走，不单独算 |
| 地面线 | 卡片底部 `1.6u`，两只是同一条线，鼠矮一截 |

## 11. 与现有状态机

- 新增行为 `chase`，**只在 `idle` 触发**，一轮约 6s 后回普通游走
- 睡觉 / 打伞 / 围巾 / 看表 / 庆祝时**不出现老鼠**，追逐层 `hidden`
- 追逐期间猫的状态道具不叠加（不撑伞、不 Zzz）
- 设置沿用上一版：**猫追老鼠**（开/关）+ **追逐频率**（经常 15s / 偶尔 45s / 关闭）

## 12. 性能

| 项 | 现状 | 加追逐 |
| --- | --- | --- |
| rAF 循环 | 1 个 / 30fps | 不变 |
| 每帧 DOM 读取 | 0 | 0 |
| 每帧写 | 1 个 transform | 2 个 transform + 偶发 dataset |
| 绘制节点 | ~30 | 追逐时猫鼠各 4–6 path |
| 隐藏开销 | — | `hidden` 整层不绘制 |

## 13. 不做的

- 不做急刹、跃过、穿模、错身、尘土
- 不接指针、不点击互动（跟手方案已明确否决）
- 不引入第三方素材或二进制图片

## 14. 验收

1. 黑底上猫是橙的、鼠是灰的，四条腿能分出远近（远腿偏暗）
2. 身体是一整块长条，不是"头 + 方块身"；尾巴在臀部翘起
3. 三档尺寸下，两帧交替能读出"腿在跑"，身体有 1 格上下弹跳
4. 鼠始终在猫前方、间距稳定；触边立刻掉头，不重叠不穿模
5. 睡觉等状态整层 `hidden`，卡片里没有老鼠
6. CPU / 发热与现状持平（单 rAF、零 DOM 读取）
7. 真机截图与本文 ASCII 图造型一致（允许 1–2 格微调）
