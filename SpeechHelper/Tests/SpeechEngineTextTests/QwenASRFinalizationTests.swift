import XCTest
@testable import SpeechEngineText

final class QwenASRFinalizationTests: XCTestCase {
    func testEmptySessionFinishesWithoutAudio() {
        var state = QwenASRFinalizationState()

        XCTAssertEqual(state.finish(), [])
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.finish(), [])
    }

    func testFinishTakesOneSnapshotAndRejectsLaterAudio() {
        var state = QwenASRFinalizationState()
        state.append([0.1, 0.2])

        XCTAssertEqual(state.finish(), [0.1, 0.2])
        XCTAssertFalse(state.append([0.3]))
        XCTAssertEqual(state.finish(), [])
    }

    func testFinalDecodeLanguageIsStableAndExplicit() {
        XCTAssertEqual(QwenASRFinalizationState.decodeLanguage, "English")
    }
}
