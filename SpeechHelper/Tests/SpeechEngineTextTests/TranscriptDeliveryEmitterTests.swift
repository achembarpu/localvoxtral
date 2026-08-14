import XCTest
@testable import SpeechEngineText

final class TranscriptDeliveryEmitterTests: XCTestCase {
    func testRevisableSnapshotsSuppressDuplicatesAndKeepSequenceMonotonic() {
        var emitter = TranscriptDeliveryEmitter(delivery: .revisableSnapshot)

        XCTAssertEqual(emitter.emit(fullText: "hello", final: false),
                       .transcriptSnapshot(text: "hello", sequence: 0, final: false))
        XCTAssertNil(emitter.emit(fullText: "hello", final: false))
        XCTAssertEqual(emitter.emit(fullText: "hello world", final: false),
                       .transcriptSnapshot(text: "hello world", sequence: 1, final: false))
        XCTAssertNil(emitter.emit(fullText: "hello world", final: true))
    }

    func testAppendOnlyPreservesExistingForwardOnlyDeltaBehavior() {
        var emitter = TranscriptDeliveryEmitter(delivery: .appendOnly)

        XCTAssertEqual(emitter.emit(fullText: "hello", final: false), .transcriptDelta("hello"))
        XCTAssertNil(emitter.emit(fullText: "hello", final: false))
        XCTAssertNil(emitter.emit(fullText: "hullo", final: false))
        XCTAssertEqual(emitter.finalText, "hello")
    }

    func testResetDoesNotReuseSnapshotSequenceWithinAConnection() {
        var emitter = TranscriptDeliveryEmitter(delivery: .revisableSnapshot)
        XCTAssertEqual(emitter.emit(fullText: "first", final: true),
                       .transcriptSnapshot(text: "first", sequence: 0, final: true))
        emitter.resetForNextUtterance()
        XCTAssertEqual(emitter.emit(fullText: "second", final: false),
                       .transcriptSnapshot(text: "second", sequence: 1, final: false))
    }
}
