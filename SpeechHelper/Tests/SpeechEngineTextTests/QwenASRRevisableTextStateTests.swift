import XCTest
@testable import SpeechEngineText

final class QwenASRRevisableTextStateTests: XCTestCase {
    func testProvisionalTextIsReplacedNotAppended() {
        var state = QwenASRRevisableTextState()

        state.applyProvisional("hello wor")
        state.applyProvisional("hello world")

        XCTAssertEqual(state.snapshot, "hello world")
    }

    func testConfirmedTextDropsPreviousProvisionalText() {
        var state = QwenASRRevisableTextState()

        state.applyDisplayUpdate(confirmed: "hello ", provisional: "wor")
        state.applyConfirmed("hello world")

        XCTAssertEqual(state.snapshot, "hello world")
        XCTAssertEqual(state.provisional, "")
    }

    func testFinalTextIsAuthoritativeAndIgnoresLateEvents() {
        var state = QwenASRRevisableTextState()

        state.applyDisplayUpdate(confirmed: "draft ", provisional: "text")
        state.applyFinal("final text")
        state.applyProvisional("late draft")
        state.applyConfirmed("late confirmed")

        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.snapshot, "final text")
    }

    func testEmptyFinalTextClearsDraft() {
        var state = QwenASRRevisableTextState()
        state.applyDisplayUpdate(confirmed: "old ", provisional: "draft")

        state.applyFinal("")

        XCTAssertEqual(state.snapshot, "")
    }
}
