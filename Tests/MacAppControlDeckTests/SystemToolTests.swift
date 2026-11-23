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

    // MARK: - DiskInfo 格式化

    func testDiskInfoFormatting() {
        var info = DiskInfo()
        info.totalSpace = 500 * 1024 * 1024 * 1024
        info.freeSpace = 200 * 1024 * 1024 * 1024
        info.usedSpace = info.totalSpace - info.freeSpace
        XCTAssertEqual(info.usedPercentage, 0.6, accuracy: 0.001)
        XCTAssertFalse(info.formattedTotal.isEmpty)
    }
}
