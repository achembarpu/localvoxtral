import Foundation
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
}
