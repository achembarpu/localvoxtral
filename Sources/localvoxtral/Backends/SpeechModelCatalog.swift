import Foundation

/// Which ASR engine the bundled speechd drives for a model. The helper infers
/// the engine from the model's repo id; this is the app-side declaration of the
/// same mapping (used by the picker and tests).
enum SpeechEngineKind: String, Equatable, Sendable {
    case voxtral
    case nemotron
}

struct SpeechModelOption: Equatable, Sendable {
    let repoID: String
    /// Exact commit downloaded by the app and loaded by speechd. The upstream
    /// loader otherwise resolves `main`, which would let a model-repo edit
    /// change strict weight keys beneath an installed app.
    let revision: String
    let displayName: String
    /// Which streaming engine speechd drives. Defaults to `.voxtral` so the
    /// existing call sites keep compiling; the helper's `SpeechModelLoader`
    /// maps repo id → engine the same way.
    var engine: SpeechEngineKind = .voxtral
}

enum SpeechModelCatalog {
    static let options: [SpeechModelOption] = [
        // Same mistralai/Voxtral-Mini-4B-Realtime-2602 4-bit conversion as the previous
        // mlx-community pin, plus a 4-bit/g64-quantized tied embedding/LM head — the
        // decode loop's dominant per-token cost (~30 ms -> ~3 ms on M1 Pro). Loading it
        // requires the quantized-tied-embedding loader fix pinned in
        // SpeechHelper/Package.swift (upstreamed in Blaizzy/mlx-audio-swift#232).
        SpeechModelOption(
            repoID: "T0mSIlver/Voxtral-Mini-4B-Realtime-2602-4bit-qhead",
            revision: "247f2eeccf962fbcaf85e361731a5e75b2d8cac1",
            displayName: "Voxtral Mini 4B Realtime (4-bit, quantized head)"
        ),
        // NVIDIA Nemotron 3.5 ASR streaming, 0.6B 8-bit. natively streaming at
        // 80ms-1.12s frames, ~0.8 GB on disk and ~1 GB resident vs the Voxtral
        // default's ~2.6 GB — the "fast / low-RAM" tier. License: NVIDIA's
        // Nemotron license (model card "other"); the checkpoint is ungated, so
        // the app's token-less downloader can fetch it, but confirm the license
        // before making it a default. WER on FLEURS (model card): EN 8.88, FR
        // 10.60 at 160ms — higher than Voxtral at its 480ms point; the polish
        // step absorbs some of that (needs an eval to quantify).
        SpeechModelOption(
            repoID: "mlx-community/nemotron-3.5-asr-streaming-0.6b-8bit",
            revision: "7279359e4481b5e9e185a318bd618e429c6d86cd",
            displayName: "Nemotron 3.5 ASR Streaming 0.6B (fast)",
            engine: .nemotron
        ),
    ]

    static let defaultOption: SpeechModelOption = {
        guard let option = option(
            forRepoID: "T0mSIlver/Voxtral-Mini-4B-Realtime-2602-4bit-qhead"
        ) else {
            preconditionFailure("Default speech model missing from the catalog.")
        }
        return option
    }()

    static func option(forRepoID repoID: String) -> SpeechModelOption? {
        options.first { $0.repoID == repoID }
    }
}
