/// Owns the append-only Qwen utterance buffer independently of MLX inference.
///
/// Qwen's native stream can revise provisional text, so the adapter retains
/// audio until the final offline decode. Keeping this lifecycle state separate
/// makes the no-partials and finish-once guarantees testable without Metal or
/// model weights.
public struct QwenASRFinalizationState: Sendable {
    public static let decodeLanguage = "English"

    private var samples: [Float] = []
    public private(set) var isFinished = false

    public init() {}

    @discardableResult
    public mutating func append(_ newSamples: [Float]) -> Bool {
        guard !isFinished else { return false }
        samples.append(contentsOf: newSamples)
        return true
    }

    /// Returns the one audio snapshot that may be decoded. Subsequent calls
    /// return an empty array, making finish idempotent and preventing duplicate
    /// final transcripts after repeated commit messages.
    public mutating func finish() -> [Float] {
        guard !isFinished else { return [] }
        isFinished = true
        defer { samples.removeAll(keepingCapacity: false) }
        return samples
    }
}
