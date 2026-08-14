import Foundation

/// How interim transcript frames are delivered for one realtime session.
/// Snapshot replacement is intentionally opt-in because live insertion cannot
/// safely revise text that has already reached another application.
enum RealtimeTranscriptDelivery: String, Sendable, Equatable {
    case appendOnly = "append_only"
    case revisableSnapshot = "revisable_snapshot"
}

struct RealtimeTranscriptSnapshot: Sendable, Equatable {
    let text: String
    let sequence: UInt64
    let isFinal: Bool
}

struct RealtimeSessionConfiguration: Sendable {
    let endpoint: URL
    let apiKey: String
    let model: String
    let transcriptDelivery: RealtimeTranscriptDelivery

    init(
        endpoint: URL,
        apiKey: String,
        model: String,
        transcriptDelivery: RealtimeTranscriptDelivery = .appendOnly
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.transcriptDelivery = transcriptDelivery
    }
}

enum RealtimeEvent: Sendable, Equatable {
    case connected
    case disconnected
    case status(String)
    case partialTranscript(String)
    case transcriptSnapshot(RealtimeTranscriptSnapshot)
    case finalTranscript(String)
    case transcriptionFinalized
    case error(String)
}

protocol RealtimeClient: AnyObject {
    var supportsPeriodicCommit: Bool { get }
    var isConnected: Bool { get }

    func setEventHandler(_ handler: @escaping @Sendable (RealtimeEvent) -> Void)
    func connect(configuration: RealtimeSessionConfiguration) throws
    func disconnect()
    func sendAudioChunk(_ pcm16Data: Data)
    func sendCommit(final: Bool)
}
