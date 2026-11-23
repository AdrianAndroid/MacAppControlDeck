# 修复 KeyCat 光标方向

## Why
KeyCat 使用的 WKWebView 以左上角为坐标原点，重复翻转纵轴导致视线和命中检测与鼠标方向相反。

## What Changes
统一屏幕坐标到网页坐标的转换，修正视线与命中方向，验证上下左右和不同窗口位置。

## Capabilities
- desktop-pet：KeyCat 光标跟随及轮廓命中。

## Impact
KeyCat 输入桥接、桌宠集成测试和规格；沿用 `pet.open`，无新增用户可见入口。

## 非目标
不修改 BongoCat 模型、签名身份、系统权限或第三方动画素材。
