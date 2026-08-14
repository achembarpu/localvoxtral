import Foundation

/// Converts full engine transcripts into the negotiated wire delivery shape.
/// One emitter belongs to a WebSocket connection. Snapshot sequence numbers
/// deliberately remain monotonic across utterances on that connection so the
/// app can reject stale frames without an additional utterance identifier.
public struct TranscriptDeliveryEmitter: Sendable {
    private let delivery: TranscriptDelivery
    private var deltas = TranscriptDeltaEmitter()
    private var latestSnapshot = ""
    private var nextSnapshotSequence: UInt64 = 0

    public init(delivery: TranscriptDelivery) {
        self.delivery = delivery
    }

    /// Emits a frame only when there is newly useful transcript information.
    /// `final` marks a changed final snapshot; `transcript.done` remains the
    /// authoritative terminal frame when the final text has not changed.
    public mutating func emit(fullText: String, final: Bool) -> RealtimeServerMessage? {
        switch delivery {
        case .appendOnly:
            let delta = deltas.emit(fullText: fullText)
            return delta.isEmpty ? nil : .transcriptDelta(delta)
        case .revisableSnapshot:
            guard fullText != latestSnapshot else { return nil }
            latestSnapshot = fullText
            let sequence = nextSnapshotSequence
            nextSnapshotSequence &+= 1
            return .transcriptSnapshot(text: fullText, sequence: sequence, final: final)
        }
    }

    /// Drops utterance-local text while retaining the connection-wide sequence.
    public mutating func resetForNextUtterance() {
        deltas = TranscriptDeltaEmitter()
        latestSnapshot = ""
    }

    public var finalText: String {
        delivery == .appendOnly ? deltas.emittedText : latestSnapshot
    }
}
