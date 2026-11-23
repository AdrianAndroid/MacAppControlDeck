# Design

屏幕坐标通过 NSWindow 与 WKWebView 转换至视图局部坐标，根据视图的 `isFlipped` 决定是否翻转纵轴，得到网页左上角坐标；光标跟随和点击命中使用同一转换。使用真实 WKWebView 的坐标转换和场景渲染，检查上下左右输入与眼睛屏幕位移方向。
