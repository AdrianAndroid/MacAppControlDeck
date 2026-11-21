# 任务清单：add-sketch-lazy-runtime

- [x] 1.1 新增 `SketchRuntime`，由 `SketchModule` 按需创建
- [x] 1.2 移除 `SketchWindowController.shared` 与 `SketchStore.shared`
- [x] 1.3 `SketchStore` 改为可实例化，测试改用实例
- [x] 1.4 关闭窗口后按 `resident` 释放 runtime
- [x] 1.5 设置页增加常驻内存开关，模块卡片同步
- [x] 1.6 内置操作、全局快捷键、设置按钮全部改走代理
- [x] 2.1 `swift test` 全量通过
- [x] 2.2 `./Build/build.sh` 构建签名成功
- [x] 2.3 实机验证打开/关闭/常驻/释放
- [x] 3.1 README 与归档文档更新
- [x] 3.2 归档 OpenSpec 并同步 `openspec/specs/sketch-lazy-runtime/spec.md`
