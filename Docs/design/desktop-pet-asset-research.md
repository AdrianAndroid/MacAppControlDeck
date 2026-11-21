# 桌宠黑猫素材调研（2026-11-21）

## 结论

网上确实有素材，但目前没有一套能同时满足：黑猫、天然 2.5D 质感、键鼠逐键动作、允许嵌入第三方 macOS App、保留五套皮肤。必须做取舍。

## 候选

| 素材 | 类型 | 优点 | 关键问题 | 授权 |
| --- | --- | --- | --- | --- |
| DesktopCat 黑猫 | 2.5D 帧动画 | 28 状态 / 136 帧，毛发体积感强，打字会反应，最接近“打动人的桌宠” | 成年猫比例，没有参考里的蹲坐键盘视角；只写明可导入 DesktopCat，未写可嵌入第三方 App | 付费角色包 US$4.90，需确认授权 |
| Live2D 官方 Hijiki | Live2D | 柔和光影、自然呼吸，是真正的猫 | 成年坐姿，无键盘、无逐键；只有前爪挠耳/舔爪 | 官方免费样例，商用需同意 Free Material License |
| BongoCat 经典 Live2D | Live2D | 键盘/鼠标逐键动作最完整，开源代码可直接参考 | 白猫 + 粗黑描边，非常扁平，正是用户拒绝的简笔感 | 代码 Apache-2.0；模型许可需逐个核对 |
| Black Cat PNGTuber 5 表情 | PNGTuber 帧包 | 3D 毛绒质感，5 套表情循环，耳朵/眼睛会动 | 只有头部和表情，没有打字、鼠标、尾巴联动 | 付费素材，直播头像授权，不等于 App 内置授权 |
| 3D 骨骼黑猫 | FBX/C4D | 真实毛发与骨骼，可物理驱动 | 四足写实比例，不是桌宠；无键盘动作；接入 SceneKit/Metal 成本高 | 免费下载，许可需核对 |
| Ezri Little Cat | Live2D | 免费/随喜，含黑猫贴图 | 极简 chibi，和当前矢量一样平；无键鼠 | CC BY-ND 4.0，与页面“可编辑”说明冲突 |

## 建议

1. **要真正解决问题，走“定制 2.5D 帧包”**：以 DesktopCat 黑猫为质量基准，做 8–10 个状态（idle/眨眼、左爪落、右爪落、双爪落、视线左/右、尾巴轻摆、睡眠），要求可嵌入 macOS App、可换五套配色、透明背景。现有素材没有完全匹配的。
2. **如果必须用现成且可商用**：Live2D Hijiki 质感最好，但它没有键盘动作，需要另做键盘层和爪子参数，且要接 Cubism SDK。
3. **不建议**：BongoCat 经典模型、Ezri、PNGTuber 素材——要么平，要么没有键鼠，要么授权只覆盖直播。
4. **DesktopCat 只作为视觉目标，不能直接打包**：除非拿到明确的第三方 App 嵌入授权。

## 来源

- https://desktopcat.com/cats
- https://www.live2d.com/en/learn/sample/tororo-hijiki/
- https://github.com/ayangweb/BongoCat
- https://www.etsy.com/listing/1530455007/black-cat-pngtuber-avatar-5-emotions
- https://open3dmodel.com/id/3d-models/3d-model-black-cat-rig_45161.html
- https://ezrii.itch.io/live2d-little-cat-model
