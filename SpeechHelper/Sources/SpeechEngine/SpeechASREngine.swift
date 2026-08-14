import Foundation
import MLX
import MLXAudioSTT
import SpeechEngineText

/// MLX-bound adapters between the upstream engines and the server's
/// `SpeechASRStreamingSession` contract. The pure contract types live in
/// SpeechEngineText so the tier-0 lane can test them Metal-free.

// MARK: - Voxtral (default engine)

final class VoxtralASREngine: SpeechASREngine, @unchecked Sendable {
    private let model: VoxtralRealtimeModel

    init(model: VoxtralRealtimeModel) {
        self.model = model
    }

    func makeSession(
        transcriptionDelayMs: Int?, transcriptDelivery _: TranscriptDelivery
    ) -> SpeechASRStreamingSession {
        VoxtralASRSession(
            session: model.makeStreamSession(
                temperature: 0.0,
                transcriptionDelayMs: transcriptionDelayMs
            )
        )
    }
}

final class VoxtralASRSession: SpeechASRStreamingSession, @unchecked Sendable {
    private let session: VoxtralRealtimeStreamSession

    init(session: VoxtralRealtimeStreamSession) {
        self.session = session
    }

    func step(_ samples: [Float]) -> SpeechStreamDelta {
        let d = session.step(samples)
        return SpeechStreamDelta(text: d.text, tokenIds: d.tokenIds)
    }

    func finish() -> SpeechStreamDelta {
        let d = session.finish()
        return SpeechStreamDelta(text: d.text, tokenIds: d.tokenIds)
    }

    var text: String { session.text }
}

// MARK: - Nemotron (fast / low-RAM streaming engine)

final class NemotronASREngine: SpeechASREngine, @unchecked Sendable {
    private let model: NemotronASRModel

    init(model: NemotronASRModel) {
        self.model = model
    }

    func makeSession(
        transcriptionDelayMs: Int?, transcriptDelivery _: TranscriptDelivery
    ) -> SpeechASRStreamingSession {
        // Nemotron's chunk size is its latency ladder (80/160/320/560/1120 ms).
        // transcriptionDelayMs is the app's configured latency point; pass it
        // through so the "fast" engine honors the same knob.
        NemotronASRSession(
            session: model.makeStreamSession(
                language: nil,
                chunkMs: transcriptionDelayMs
            )
        )
    }
}

final class NemotronASRSession: SpeechASRStreamingSession, @unchecked Sendable {
    private let session: NemotronASRStreamSession

    init(session: NemotronASRStreamSession) {
        self.session = session
    }

    func step(_ samples: [Float]) -> SpeechStreamDelta {
        let d = session.step(samples)
        return SpeechStreamDelta(text: d.text, tokenIds: d.tokenIds)
    }

    func finish() -> SpeechStreamDelta {
        let d = session.finish()
        return SpeechStreamDelta(text: d.text, tokenIds: d.tokenIds)
    }

    var text: String { session.text }
}

// MARK: - Granite (streaming via growing-window re-decode)

final class GraniteSpeechASREngine: SpeechASREngine, @unchecked Sendable {
    private let model: GraniteSpeechModel

    init(model: GraniteSpeechModel) {
        self.model = model
    }

    func makeSession(
        transcriptionDelayMs: Int?, transcriptDelivery: TranscriptDelivery
    ) -> SpeechASRStreamingSession {
        // Granite's growing-window session re-decodes at the model's fixed
        // window_size=15 (~300 ms) cadence; there is no chunk ladder to map
        // transcriptionDelayMs onto, so the knob is ignored.
        GraniteSpeechASRSession(
            session: model.makeStreamSession(
                mode: transcriptDelivery == .revisableSnapshot ? .revisableOverlay : .finalOnly
            )
        )
    }
}

final class GraniteSpeechASRSession: SpeechASRStreamingSession, @unchecked Sendable {
    private let session: GraniteSpeechStreamSession

    init(session: GraniteSpeechStreamSession) {
        self.session = session
    }

    func step(_ samples: [Float]) -> SpeechStreamDelta {
        let d = session.step(samples)
        return SpeechStreamDelta(text: d.text, tokenIds: d.tokenIds)
    }

    func finish() -> SpeechStreamDelta {
        let d = session.finish()
        return SpeechStreamDelta(text: d.text, tokenIds: d.tokenIds)
    }

    var text: String { session.text }
// MARK: - Qwen3-ASR (native streaming engine)

final class Qwen3ASREngine: SpeechASREngine, @unchecked Sendable {
    private let model: Qwen3ASRModel

    init(model: Qwen3ASRModel) {
        self.model = model
    }

    func makeSession(
        transcriptionDelayMs: Int?, transcriptDelivery: TranscriptDelivery
    ) -> SpeechASRStreamingSession {
        // Qwen's native decoder emits provisional rewrites. The app's append-only
        // insertion contract cannot represent those rewrites, so buffer the
        // utterance and perform one exact decode at commit.
        _ = transcriptionDelayMs
        _ = transcriptDelivery
        return Qwen3ASRSession(model: model)
    }
}

/// Qwen's native stream exposes provisional rewrites, while this server's
/// append-only contract cannot retract text already inserted into a focused app.
/// Buffering and using the model's exact offline generation path at commit keeps
/// the wire transcript correct and avoids repeated-window O(n²) work. This engine
/// intentionally emits no partials; its transcript is produced on final commit.
final class Qwen3ASRSession: SpeechASRStreamingSession, @unchecked Sendable {
    private let model: Qwen3ASRModel
    private var audioSamples: [Float] = []
    private var finalText = ""
    private var didFinish = false

    init(model: Qwen3ASRModel) {
        self.model = model
    }

    func step(_ samples: [Float]) -> SpeechStreamDelta {
        guard !didFinish else { return SpeechStreamDelta(text: "", tokenIds: []) }
        audioSamples.append(contentsOf: samples)
        return SpeechStreamDelta(text: "", tokenIds: [])
    }

    func finish() -> SpeechStreamDelta {
        guard !didFinish else { return SpeechStreamDelta(text: "", tokenIds: []) }
        didFinish = true
        guard !audioSamples.isEmpty else { return SpeechStreamDelta(text: "", tokenIds: []) }
        let output = model.generate(
            audio: MLXArray(audioSamples),
            generationParameters: STTGenerateParameters(
                maxTokens: 8192,
                temperature: 0.0,
                language: "English"
            )
        )
        finalText = output.text
        audioSamples.removeAll(keepingCapacity: false)
        return SpeechStreamDelta(text: finalText, tokenIds: [])
    }

    /// Full stabilized transcript decoded so far (the final full text once
    /// finished). The server emits append-only deltas against this snapshot.
    var text: String {
        finalText
    }
}
