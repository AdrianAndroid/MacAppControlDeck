import XCTest
@testable import MacAppControlDeck

final class PairingManagerTests: XCTestCase {
    private func manager() -> PairingManager { PairingManager() }

    func test_correctCodeRedeemsOnce() {
        let pairing = manager()
        let code = pairing.newCode()
        XCTAssertEqual(pairing.redeem(code), .ok)
        XCTAssertEqual(pairing.redeem(code), .noActiveCode, "配对码用后即焚")
    }

    func test_wrongCodeFailsAndLocksAfterThreeAttempts() {
        let pairing = manager()
        _ = pairing.newCode()
        XCTAssertEqual(pairing.redeem("000000"), .wrongCode)
        XCTAssertEqual(pairing.redeem("000001"), .wrongCode)
        XCTAssertEqual(pairing.redeem("000002"), .wrongCode)
        XCTAssertEqual(pairing.redeem("111111"), .locked)
    }

    func test_invalidateMakesCodeUnusable() {
        let pairing = manager()
        let code = pairing.newCode()
        pairing.invalidate()
        XCTAssertEqual(pairing.redeem(code), .noActiveCode)
    }

    func test_generateTokenLengthAndRandomness() {
        let a = PairingManager.generateToken()
        let b = PairingManager.generateToken()
        XCTAssertEqual(a.count, 64)
        XCTAssertNotEqual(a, b)
    }
}
