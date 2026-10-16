import XCTest
@testable import VPNClientLogic

final class TrialResponseTests: XCTestCase {
    private func body(_ text: String) -> Data { Data(text.utf8) }

    func testReturnsVpnKeyOnSuccess() throws {
        let key = try TrialResponse.parse(statusCode: 200, body: body(#"{"config":"vpn://AAAA","expires":"x"}"#))
        XCTAssertEqual(key, "vpn://AAAA")
    }

    func testMissingOrForeignConfigIsRejected() {
        for text in [#"{}"#, #"{"config":"https://x"}"#, #"{"config":5}"#, "not json", ""] {
            XCTAssertThrowsError(try TrialResponse.parse(statusCode: 200, body: body(text)), text) { error in
                XCTAssertEqual(error as? TrialResponseError, .message(TrialResponse.noKey))
            }
        }
    }

    func testServerDetailIsShownToUser() {
        XCTAssertThrowsError(try TrialResponse.parse(statusCode: 429, body: body(#"{"detail":"Слишком часто"}"#))) { error in
            XCTAssertEqual(error as? TrialResponseError, .message("Слишком часто"))
        }
    }

    func testConflictWithoutDetailMeansAlreadyClaimed() {
        XCTAssertEqual(TrialResponse.failureMessage(statusCode: 409, body: body("")), TrialResponse.alreadyClaimed)
        XCTAssertEqual(TrialResponse.failureMessage(statusCode: 409, body: body(#"{"detail":"  "}"#)), TrialResponse.alreadyClaimed)
    }

    func testOtherFailuresUseGenericMessage() {
        XCTAssertEqual(TrialResponse.failureMessage(statusCode: 500, body: body("<html>")), TrialResponse.genericFailure)
    }
}