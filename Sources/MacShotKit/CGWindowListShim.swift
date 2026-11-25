import CoreGraphics
import Darwin

/// macOS 27 SDK 起 `CGWindowListCreateImage` 被标记为 unavailable（建议改用 ScreenCaptureKit）。
/// 本项目仍保留旧系统兜底路径，因此改为运行期解析符号，既能在新 SDK 下编译，
/// 又能在运行时存在该符号的系统中继续工作。
private typealias CGWindowListCreateImageFn =
    @convention(c) (CGRect, UInt32, CGWindowID, UInt32) -> UnsafeMutableRawPointer?

private let cgWindowListCreateImageFn: CGWindowListCreateImageFn? = {
    let framework = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
    guard let handle = dlopen(framework, RTLD_LAZY) else { return nil }
    guard let symbol = dlsym(handle, "CGWindowListCreateImage") else { return nil }
    return unsafeBitCast(symbol, to: CGWindowListCreateImageFn.self)
}()

func CGWindowListCreateImageCompat(_ bounds: CGRect,
                                   _ listOption: CGWindowListOption,
                                   _ windowID: CGWindowID,
                                   _ imageOption: CGWindowImageOption) -> CGImage? {
    guard let result = cgWindowListCreateImageFn?(bounds, listOption.rawValue, windowID, imageOption.rawValue) else {
        return nil
    }
    return Unmanaged<CGImage>.fromOpaque(result).takeRetainedValue()
}
