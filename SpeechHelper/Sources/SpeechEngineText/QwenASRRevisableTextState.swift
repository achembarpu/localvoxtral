/// Pure transcript state for Qwen's revisable streaming events.
///
/// The upstream session reports confirmed and provisional text separately.
/// Keeping their composition outside the MLX adapter makes replacement
/// semantics deterministic and testable without loading a model.
public struct QwenASRRevisableTextState: Sendable, Equatable {
    public private(set) var confirmed = ""
    public private(set) var provisional = ""
    public private(set) var finalText: String?

    public init() {}

    public var snapshot: String {
        finalText ?? confirmed + provisional
    }

    public var isFinished: Bool {
        finalText != nil
    }

    public mutating func applyProvisional(_ text: String) {
        guard !isFinished else { return }
        provisional = text
    }

    public mutating func applyConfirmed(_ text: String) {
        guard !isFinished else { return }
        confirmed = text
        provisional = ""
    }

    public mutating func applyDisplayUpdate(confirmed: String, provisional: String) {
        guard !isFinished else { return }
        self.confirmed = confirmed
        self.provisional = provisional
    }

    public mutating func applyFinal(_ text: String) {
        guard !isFinished else { return }
        finalText = text
        provisional = ""
    }
}
