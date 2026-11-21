import XCTest
@testable import MacAppControlDeck

@MainActor
final class SketchRuntimeTests: XCTestCase {
    func testRuntimeReleasesStoreAndController() {
        var runtime: SketchRuntime? = SketchRuntime()
        weak var weakStore = runtime?.store
        weak var weakController = runtime?.controller

        XCTAssertNotNil(weakStore)
        XCTAssertNotNil(weakController)

        runtime = nil

        XCTAssertNil(weakStore, "关闭后 SketchStore 不应继续被 runtime 之外的对象强引用")
        XCTAssertNil(weakController, "关闭后 SketchWindowController 应随 runtime 释放")
    }
}
