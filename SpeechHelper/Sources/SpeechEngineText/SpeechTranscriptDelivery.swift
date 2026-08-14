/// How a realtime client consumes transcript updates.
public enum SpeechTranscriptDelivery: String, Codable, Equatable, Sendable {
    /// Updates are forward-only deltas suitable for direct insertion.
    case appendOnly = "append_only"
    /// Updates carry the authoritative full draft and may replace the client draft.
    case revisableSnapshot = "revisable_snapshot"
}
