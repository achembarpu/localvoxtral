import Foundation
import MLXAudioSTT
import SpeechEngineText
import Synchronization

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
        // Qwen3-ASR emits provisional tokens that promote to confirmed text only
        // after N agreeing decode passes AND the delay preset elapses. Its latency
        // knob is therefore StreamingConfig.delayPreset; map the app's
        // transcriptionDelayMs onto a custom preset, else keep the engine's
        // balanced .agent default.
        var config = StreamingConfig()
        if let transcriptionDelayMs {
            config.delayPreset = .custom(ms: transcriptionDelayMs)
        }
        _ = transcriptDelivery
        return Qwen3ASRSession(
            session: StreamingInferenceSession(model: model, config: config)
        )
    }
}

/// Maps the upstream `StreamingInferenceSession` (feedAudio + AsyncStream of
/// `TranscriptionEvent`) onto the server's synchronous step/finish/text contract.
///
/// Semantic differences from the Voxtral/Nemotron delta contract:
/// - `text` exposes only STABILIZED (confirmed) text. Qwen3-ASR yields provisional
///   tokens that are withheld until they agree across `minAgreementPasses` decode
///   passes and the delay preset elapses, then promote in bursts. Voxtral/Nemotron
///   surface provisional text immediately; here provisional rewrites never reach
///   the wire at all (cleaner for the no-backspace insertion path).
/// - Event delivery is asynchronous: the upstream session runs decode passes on its
///   own detached tasks and reports through an AsyncStream. `step` only feeds audio
///   and returns immediately; newly confirmed text surfaces on later reads of `text`,
///   so live text lags the audio by roughly the decode interval + promotion delay.
///   `finish` blocks this queue thread until the final `.ended` text is recorded.
/// - `SpeechStreamDelta.tokenIds` is empty: `TranscriptionEvent` carries text only
///   (token ids are internal to the upstream decode passes).
final class Qwen3ASRSession: SpeechASRStreamingSession, @unchecked Sendable {
    private struct Snapshot {
        var confirmedText = ""
        var provisionalText = ""
        var finalText: String?
        var emittedText = ""
    }

    /// Reference-typed holder for the shared snapshot state. `Mutex` is move-only,
    /// so the consumer task and the server's synchronous reads share the lock (and
    /// the end signal) through this box instead of capturing the values directly.
    private final class SharedState: @unchecked Sendable {
        let lock = Mutex(Snapshot())
        let endedSignal = DispatchSemaphore(value: 0)
    }

    private let session: StreamingInferenceSession
    private let shared = SharedState()
    private let consumer: Task<Void, Never>

    init(session: StreamingInferenceSession) {
        self.session = session
        // The server drives step/finish/text synchronously from its serial
        // inference queue; this task is the only reader of the event stream and
        // folds every event into the lock-protected snapshot. It captures
        // `session`/`shared` directly (never `self`) so it does not keep the
        // adapter alive after the server drops it.
        self.consumer = Task { [session, shared] in
            for await event in session.events {
                switch event {
                case .provisional(let text):
                    shared.lock.withLock { $0.provisionalText = text }
                case .confirmed(let text):
                    shared.lock.withLock { $0.confirmedText = text }
                case .displayUpdate(let confirmedText, let provisionalText):
                    shared.lock.withLock {
                        $0.confirmedText = confirmedText
                        $0.provisionalText = provisionalText
                    }
                case .stats:
                    break
                case .ended(let fullText):
                    shared.lock.withLock {
                        $0.finalText = fullText
                        $0.provisionalText = ""
                    }
                    shared.endedSignal.signal()
                }
            }
        }
    }

    deinit {
        // Cancelling the consumer releases its capture of `session`, so the
        // upstream session (and its continuation) deallocates with the adapter.
        consumer.cancel()
    }

    func step(_ samples: [Float]) -> SpeechStreamDelta {
        session.feedAudio(samples: samples)
        return consumeNewlyConfirmed()
    }

    func finish() -> SpeechStreamDelta {
        session.stop()
        // stop() always terminates with `.ended`; wait for the consumer to record
        // the final text (blocks only this queue thread, not the concurrency pool
        // that runs the decode + consumer tasks).
        if !hasEnded { shared.endedSignal.wait() }
        return consumeNewlyConfirmed()
    }

    /// Full stabilized transcript decoded so far (the final full text once
    /// finished). The server emits append-only deltas against this snapshot.
    var text: String {
        shared.lock.withLock { snapshot in
            snapshot.finalText ?? snapshot.confirmedText
        }
    }

    private var hasEnded: Bool {
        shared.lock.withLock { $0.finalText != nil }
    }

    /// Returns the confirmed text that stabilized since the last step/finish, as
    /// an append-only delta (confirmed text is monotonic prefix-growing).
    private func consumeNewlyConfirmed() -> SpeechStreamDelta {
        shared.lock.withLock { snapshot in
            let full = snapshot.finalText ?? snapshot.confirmedText
            var deltaText = ""
            if full.hasPrefix(snapshot.emittedText) {
                deltaText = String(full.dropFirst(snapshot.emittedText.count))
            }
            snapshot.emittedText = full
            return SpeechStreamDelta(text: deltaText, tokenIds: [])
        }
    }
}
