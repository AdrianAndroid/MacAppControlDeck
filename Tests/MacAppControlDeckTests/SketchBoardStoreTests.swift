import XCTest
@testable import MacAppControlDeck

@MainActor
final class SketchBoardStoreTests: XCTestCase {
    private var directory: URL!
    private var store: SketchBoardStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-board-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = SketchBoardStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testBootstrapCreatesFirstBoard() throws {
        let board = try store.bootstrap(legacyScene: nil, preferredActiveID: nil)
        XCTAssertEqual(board.title, "画布 1")
        XCTAssertEqual(store.boards.count, 1)
        XCTAssertEqual(store.activeID, board.id)
        XCTAssertNotNil(store.scene(for: board.id))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("index.json").path
        ))
    }

    func testLegacyDraftBecomesFirstBoard() throws {
        let legacy = #"{"type":"excalidraw","version":2,"elements":[{"id":"legacy"}],"appState":{},"files":{}}"#
        let board = try store.bootstrap(legacyScene: legacy, preferredActiveID: nil)
        XCTAssertEqual(store.boards.count, 1)
        XCTAssertEqual(store.scene(for: board.id), legacy)
        XCTAssertEqual(board.elementCount, 1)
    }

    func testCreateBoardsIsolatesScenesAndTitles() throws {
        _ = try store.bootstrap(legacyScene: nil, preferredActiveID: nil)
        let second = try store.create()
        XCTAssertEqual(second.title, "画布 2")
        XCTAssertEqual(store.activeID, second.id)

        let scene = #"{"type":"excalidraw","version":2,"elements":[{"id":"a"},{"id":"b"}],"appState":{},"files":{}}"#
        try store.saveScene(scene, for: second.id)
        XCTAssertEqual(store.scene(for: second.id), scene)
        XCTAssertEqual(store.activeBoard()?.elementCount, 2)

        let first = try XCTUnwrap(store.boards.first)
        XCTAssertEqual(store.scene(for: first.id), SketchBoardStore.emptyScene)
    }

    func testRenameTrimsAndAvoidsDuplicates() throws {
        _ = try store.bootstrap(legacyScene: nil, preferredActiveID: nil)
        let second = try store.create()
        let renamed = try store.rename(id: second.id, title: "  登录页  ")
        XCTAssertEqual(renamed.title, "登录页")

        let third = try store.create(title: "登录页")
        XCTAssertEqual(third.title, "登录页 2")
        XCTAssertThrowsError(try store.rename(id: third.id, title: "   ")) { error in
            XCTAssertEqual(error as? SketchBoardError, .invalidTitle)
        }
    }

    func testDeleteActiveSelectsNeighborAndNeverLeavesZeroBoards() throws {
        _ = try store.bootstrap(legacyScene: nil, preferredActiveID: nil)
        let second = try store.create()
        let third = try store.create()
        XCTAssertEqual(store.activeID, third.id)

        let next = try store.delete(id: third.id)
        XCTAssertEqual(next.id, second.id)
        XCTAssertEqual(store.boards.count, 2)

        _ = try store.delete(id: second.id)
        _ = try store.delete(id: store.boards[0].id)
        XCTAssertEqual(store.boards.count, 1)
        XCTAssertEqual(store.boards[0].title, "画布 1")
        XCTAssertEqual(store.activeID, store.boards[0].id)
    }

    func testBootstrapHonorsPreferredActiveBoard() throws {
        _ = try store.bootstrap(legacyScene: nil, preferredActiveID: nil)
        let second = try store.create()
        let reopened = SketchBoardStore(directory: directory)
        let active = try reopened.bootstrap(legacyScene: nil, preferredActiveID: second.id)
        XCTAssertEqual(active.id, second.id)
        XCTAssertEqual(reopened.boards.count, 2)
    }
}
