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

    func testNemotronDirectoryConfigMapsToNemotronEngine() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "speech-engine-kind-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"model_type":"nemotron_asr"}"#.utf8)
            .write(to: directory.appending(path: "config.json"))

        XCTAssertEqual(SpeechASREngineKind.infer(fromModelDirectory: directory), .nemotron)
    }

    func testUnknownDirectoryConfigKeepsVoxtralFallback() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "speech-engine-kind-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"model_type":"custom_asr"}"#.utf8)
            .write(to: directory.appending(path: "config.json"))

        XCTAssertEqual(SpeechASREngineKind.infer(fromModelDirectory: directory), .voxtral)
    }

    func testDeltaIsEquatableForTestingTheAppendOnlyContract() {
        XCTAssertEqual(
            SpeechStreamDelta(text: "hello", tokenIds: [1, 2]),
            SpeechStreamDelta(text: "hello", tokenIds: [1, 2])
        )
    }
}
