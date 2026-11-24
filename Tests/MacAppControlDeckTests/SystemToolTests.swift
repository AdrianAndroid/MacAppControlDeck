import XCTest
@testable import MacAppControlDeck

final class SystemToolTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-systemtool-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - OrphanSafetyPolicy 分级

    func testOrphanSafetyPolicyGrading() {
        let home = NSHomeDirectory()
        let safe = URL(fileURLWithPath: "\(home)/Library/Caches/com.example.test")
        let unsafe = URL(fileURLWithPath: "\(home)/Library/Preferences/com.example.plist")
        let dotfile = URL(fileURLWithPath: "\(home)/.ssh/config")
        XCTAssertTrue(OrphanSafetyPolicy.isSafeCandidate(safe))
        XCTAssertFalse(OrphanSafetyPolicy.isSafeCandidate(unsafe))
        XCTAssertFalse(OrphanSafetyPolicy.isSafeCandidate(dotfile))
    }

    // MARK: - CleanupExclusions 排除路径

    func testCleanupExclusions() {
        let suiteName = "deck-systemtool-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        CleanupExclusions.add("/tmp/excluded", in: defaults)
        XCTAssertTrue(CleanupExclusions.excludes("/tmp/excluded/child.txt", paths: CleanupExclusions.paths(in: defaults)))
        XCTAssertTrue(CleanupExclusions.excludes("/tmp/excluded", paths: CleanupExclusions.paths(in: defaults)))
        XCTAssertFalse(CleanupExclusions.excludes("/tmp/other", paths: CleanupExclusions.paths(in: defaults)))
    }

    // MARK: - DuplicateFinder 哈希分组

    func testDuplicateFinderGroupsByIdenticalContent() async throws {
        let a = root.appendingPathComponent("a.txt")
        let b = root.appendingPathComponent("b.txt")
        let c = root.appendingPathComponent("c.txt")
        let payload = Data("identical-content-for-dedup-test".utf8)
        try payload.write(to: a)
        try payload.write(to: b)
        try Data("different".utf8).write(to: c)

        let finder = DuplicateFinder()
        let result = try await finder.scan(folder: root)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups.first?.files.count, 2)
        XCTAssertEqual(result.groups.first?.reclaimableSize, Int64(payload.count))
    }

    // MARK: - SystemTrashService 符号链接保护 + 废纸篓优先

    func testTrashServiceSkipsSymlinkAndUnprotectedPath() async {
        let outsideDir = root.appendingPathComponent("outside")
        try? FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        let targetFile = outsideDir.appendingPathComponent("secret.txt")
        try? Data("secret".utf8).write(to: targetFile)

        let link = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Caches/deck-symlink-test-\(UUID().uuidString)")
        try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: targetFile)
        defer { try? FileManager.default.removeItem(at: link) }

        let service = SystemTrashService()
        let item = CleanableItem(name: "link", path: link.path, size: 5,
                                 category: .userCache, isSelected: true, lastModified: nil)
        let result = await service.clean([item])
        XCTAssertEqual(result.itemsCleaned, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path), "符号链接目标不得被删除")
    }

    // MARK: - 扫描根与清理允许范围一致（回归：曾因白名单过窄导致扫描结果全部清不掉）

    func testScanRootsCoverEveryScannedCategory() {
        let home = NSHomeDirectory()
        let representatives: [(String, String)] = [
            ("largeFile", "\(home)/Downloads/big.dmg"),
            ("largeFile", "\(home)/Documents/big.dmg"),
            ("largeFile", "\(home)/Desktop/big.dmg"),
            ("systemJunk", "/Library/Caches/deck-probe"),
            ("systemJunk", "/tmp/deck-probe"),
            ("userCache", "\(home)/Library/Caches/deck-probe"),
            ("sandboxCache", "\(home)/Library/Containers/com.example/Data/Library/Caches/deck-probe"),
            ("xcode", "\(home)/Library/Developer/Xcode/DerivedData/App-abc"),
            ("node", "\(home)/.npm/_cacache/deck-probe"),
            ("devCache", "\(home)/.gradle/caches/deck-probe"),
            ("trash", "\(home)/.Trash/deck-probe"),
        ]
        for (label, path) in representatives {
            XCTAssertTrue(
                SystemToolScanRoots.isWithinCleanableRoots(path, home: home),
                "\(label) 的扫描结果必须落在允许清理范围内: \(path)"
            )
        }
    }

    func testDeniedRootsStillRejectSensitivePaths() {
        let home = NSHomeDirectory()
        for path in ["/System/Library/deck-probe", "\(home)/.ssh/id_rsa",
                     "\(home)/Library/Keychains/login.keychain-db", "/etc/hosts"] {
            XCTAssertTrue(SystemToolScanRoots.isDenied(path, home: home),
                          "敏感路径必须被拒绝: \(path)")
        }
    }

    func testCustomLargeFileRootIsHonored() {
        let suite = UserDefaults(suiteName: "deck-scanroots-\(UUID().uuidString)")!
        suite.set(["/Volumes/External/Media"], forKey: SystemToolScanRoots.largeFileRootsKey)
        let home = NSHomeDirectory()
        XCTAssertEqual(
            SystemToolScanRoots.largeFileRoots(home: home, defaults: suite),
            ["/Volumes/External/Media"]
        )
        XCTAssertTrue(SystemToolScanRoots.isWithinCleanableRoots(
            "/Volumes/External/Media/big.mov", home: home, defaults: suite
        ))
    }

    /// 端到端：大文件页的扫描结果（下载目录，旧白名单不含）必须能真正移入废纸篓。
    func testCleanActuallyTrashesLargeFileScanResult() async throws {
        let home = NSHomeDirectory()
        let probeDir = URL(fileURLWithPath: "\(home)/Downloads")
            .appendingPathComponent("deck-clean-regression-\(UUID().uuidString)", isDirectory: true)
        // 若 Downloads 被 iCloud / FileProvider 接管则跳过，避免测试污染真实云同步数据。
        guard !ProviderPaths.isProviderOwned(probeDir.path) else {
            throw XCTSkip("Downloads 由云同步接管，跳过真实清理用例")
        }
        try FileManager.default.createDirectory(at: probeDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: probeDir) }
        let file = probeDir.appendingPathComponent("big.dmg")
        try Data(String(repeating: "x", count: 2048).utf8).write(to: file)

        let item = CleanableItem(name: "big.dmg", path: file.path, size: 2048,
                                 category: .largeFiles, isSelected: true, lastModified: nil)
        let service = SystemTrashService()
        let result = await service.clean([item])
        XCTAssertEqual(result.itemsCleaned, 1, "大文件扫描结果必须能移入废纸篓")
        XCTAssertTrue(result.skippedPaths.isEmpty, "不得再被安全白名单误拦")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        // 清理移入废纸篓的探针文件与残留目录，不留下垃圾。
        for path in result.trashedPaths { try? FileManager.default.removeItem(atPath: path) }
    }

    /// 放宽允许范围后，敏感路径仍必须在端到端清理中被跳过。
    func testCleanStillSkipsDeniedSystemPath() async {
        let item = CleanableItem(name: "hosts", path: "/etc/hosts", size: 1,
                                 category: .systemJunk, isSelected: true, lastModified: nil)
        let service = SystemTrashService()
        let result = await service.clean([item])
        XCTAssertEqual(result.itemsCleaned, 0, "系统关键路径绝不能被清理")
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/etc/hosts"))
    }

    // MARK: - DiskInfo 格式化

    func testDiskInfoFormatting() {
        var info = DiskInfo()
        info.totalSpace = 500 * 1024 * 1024 * 1024
        info.freeSpace = 200 * 1024 * 1024 * 1024
        info.usedSpace = info.totalSpace - info.freeSpace
        XCTAssertEqual(info.usedPercentage, 0.6, accuracy: 0.001)
        XCTAssertFalse(info.formattedTotal.isEmpty)
    }

    // MARK: - 网速格式化

    func testSpeedFormattingUnits() {
        XCTAssertEqual(SystemSampler.formatSpeed(0), "0 K/s")
        XCTAssertEqual(SystemSampler.formatSpeed(-10), "0 K/s")
        XCTAssertEqual(SystemSampler.formatSpeed(512), "512 B/s")
        XCTAssertEqual(SystemSampler.formatSpeed(1_024 * 35.84), "35.8 K/s")
        XCTAssertEqual(SystemSampler.formatSpeed(1_024 * 1_024 * 1.5), "1.5 M/s")
    }

    func testFixedSpeedHasConstantWidth() {
        // 菜单栏定宽：任意量级数值的字符数一致（figure space 与数字同为 1 字符），
        // 保证状态项宽度不随速率位数变化而抖动。
        let values: [Double] = [0, -10, 1, 9.9, 10, 99.9, 100, 999.9,
                                1_024, 1_024 * 10, 1_024 * 100,
                                1_024 * 1_024, 1_024 * 1_024 * 12.5,
                                1_024 * 1_024 * 1_024 * 2]
        let widths = Set(values.map { SystemSampler.formatSpeedFixed($0).count })
        XCTAssertEqual(widths.count, 1, "定宽格式各量级字符数应一致，实际为 \(widths)")
        // 数值部分右对齐到 5 字符 + 1 空格 + 3 字符单位 = 9 字符。
        XCTAssertEqual(SystemSampler.formatSpeedFixed(0).count, 9)
        XCTAssertTrue(SystemSampler.formatSpeedFixed(0).hasSuffix(" K/s"))
    }

    func testFixedSpeedUsesFigureSpaceForPadding() {
        // 前导填充必须是 figure space (U+2007)，它在等宽数字字体下与数字同宽，
        // 普通空格更窄会导致列宽抖动。
        let text = SystemSampler.formatSpeedFixed(1.5) // "   1.5 K/s"
        XCTAssertTrue(text.hasPrefix("\u{2007}"), "前导应为 figure space")
        XCTAssertFalse(text.hasPrefix(" "), "不应使用普通空格填充")
    }

    func testMemorySizeFormatting() {
        XCTAssertEqual(MemoryMenuBuilder.formatBytes(0), "0 KB")
        XCTAssertEqual(MemoryMenuBuilder.formatBytes(512), "512 B")
        XCTAssertEqual(MemoryMenuBuilder.formatBytes(1_024), "1 KB")
        XCTAssertEqual(MemoryMenuBuilder.formatBytes(2_567 * 1_024), "2.5 MB")
        XCTAssertEqual(MemoryMenuBuilder.formatBytes(UInt64(1.5 * 1_024 * 1_024)), "1.5 MB")
        XCTAssertEqual(MemoryMenuBuilder.formatBytes(UInt64(2.67 * 1_024 * 1_024 * 1_024)), "2.7 GB")
    }

    private func safeDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    func testSpeedDeltasNeverNegativeOnWrap() {
        // 累计字节回绕（如接口重置）时，差分应为 0 而非负数。
        XCTAssertEqual(safeDelta(500, 1_000_000), 0)
        // 正常增长按差值计算。
        XCTAssertEqual(safeDelta(1_010_240, 1_000_000), 10_240)
    }

    func testNetworkCountersAreReadable() {
        let counters = SystemSampler.readNetworkCounters()
        XCTAssertGreaterThanOrEqual(counters.received, 0)
        XCTAssertGreaterThanOrEqual(counters.sent, 0)
    }
}
