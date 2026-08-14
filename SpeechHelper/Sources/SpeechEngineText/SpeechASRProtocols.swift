import Foundation

/// Append-only transcript delta consumed by the realtime server. The upstream
/// MLX engines' `Delta` types differ per model, so the adapter layer normalizes
/// them to this one (lives here so the Metal-free tier can own the contract).
public struct SpeechStreamDelta: Sendable, Equatable {
    public let text: String
    public let tokenIds: [Int]

    public init(text: String, tokenIds: [Int]) {
        self.text = text
        self.tokenIds = tokenIds
    }
}

/// The slice of a streaming-ASR engine the server needs: feed audio, read the
/// growing transcript, flush the trailing partial. A session is confined to the
/// server's serial inference queue (MLX inference is not concurrency-safe).
public protocol SpeechASRStreamingSession: Sendable {
    @discardableResult
    func step(_ samples: [Float]) -> SpeechStreamDelta
    @discardableResult
    func finish() -> SpeechStreamDelta
    /// Full transcript decoded so far (the server emits append-only deltas
    /// against this snapshot, never the raw engine delta).
    var text: String { get }
}

/// A loaded ASR model that opens per-utterance streaming sessions.
public protocol SpeechASREngine: Sendable {
    /// `transcriptionDelayMs` is the app's latency/accuracy knob; each engine
    /// maps it to its own equivalent (Voxtral's transcription delay, Nemotron's
    /// chunk size).
    func makeSession(transcriptionDelayMs: Int?) -> SpeechASRStreamingSession
}

/// Which streaming engine `speechd` drives for a model. The helper infers this
/// from the catalog repo id the app passes on the command line; keep in sync
/// with `SpeechModelCatalog.SpeechEngineKind` (app side).
public enum SpeechASREngineKind: String, Sendable {
    case voxtral
    case nemotron

    public static func infer(fromModelID id: String?) -> SpeechASREngineKind {
        guard let id else { return .voxtral }
        let lower = id.lowercased()
        if lower.contains("nemotron") { return .nemotron }
        return .voxtral
    }
}
