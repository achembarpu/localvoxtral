import XCTest
@testable import SpeechEngineText

final class SpeechASREngineKindTests: XCTestCase {
    func testVoxtralModelMapsToVoxtralEngine() {
        XCTAssertEqual(
            SpeechASREngineKind.infer(
                fromModelID: "T0mSIlver/Voxtral-Mini-4B-Realtime-2602-4bit-qhead"
            ),
            .voxtral
        )
        XCTAssertEqual(SpeechASREngineKind.infer(fromModelID: nil), .voxtral)
    }

    func testNemotronModelMapsToNemotronEngine() {
        XCTAssertEqual(
            SpeechASREngineKind.infer(
                fromModelID: "mlx-community/nemotron-3.5-asr-streaming-0.6b-8bit"
            ),
            .nemotron
        )
        // Case-insensitive, and a bare id with no match stays on the safe default.
        XCTAssertEqual(
            SpeechASREngineKind.infer(fromModelID: "mlx-community/Nemotron-3.5-ASR-streaming-0.6b"),
            .nemotron
        )
        XCTAssertEqual(SpeechASREngineKind.infer(fromModelID: "some/other-asr"), .voxtral)
    }

    func testGraniteModelMapsToGraniteEngine() {
        XCTAssertEqual(
            SpeechASREngineKind.infer(
                fromModelID: "mlx-community/granite-4.0-1b-speech-4bit"
            ),
            .granite
        )
        // Case-insensitive, like the Nemotron mapping.
        XCTAssertEqual(
            SpeechASREngineKind.infer(fromModelID: "mlx-community/Granite-4.0-1B-Speech"),
            .granite
        )
        XCTAssertEqual(SpeechASREngineKind.infer(fromModelID: "some/other-asr"), .voxtral)
    }

    func testQwen3ASRModelMapsToQwen3ASREngine() {
        XCTAssertEqual(
            SpeechASREngineKind.infer(
                fromModelID: "mlx-community/Qwen3-ASR-0.6B-8bit"
            ),
            .qwen3ASR
        )
        // Case-insensitive, and "qwen3-asr" anywhere in the id wins.
        XCTAssertEqual(
            SpeechASREngineKind.infer(fromModelID: "mlx-community/qwen3-asr-0.6b-8bit"),
            .qwen3ASR
        )
        XCTAssertEqual(
            SpeechASREngineKind.infer(fromModelID: "org/Qwen3-ASR-something"),
            .qwen3ASR
        )
    }

    func testDeltaIsEquatableForTestingTheAppendOnlyContract() {
        XCTAssertEqual(
            SpeechStreamDelta(text: "hello", tokenIds: [1, 2]),
            SpeechStreamDelta(text: "hello", tokenIds: [1, 2])
        )
    }
}
