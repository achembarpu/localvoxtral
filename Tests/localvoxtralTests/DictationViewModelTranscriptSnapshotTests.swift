import Foundation
import XCTest
@testable import localvoxtral

@MainActor
final class DictationViewModelTranscriptSnapshotTests: XCTestCase {
    private static var retainedViewModels: [DictationViewModel] = []

    private func makeViewModel(output: DictationOutputMode) -> (
        viewModel: DictationViewModel, coordinator: SnapshotOverlayCoordinator
    ) {
        let suiteName = "localvoxtral.TranscriptSnapshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults, environment: [:])
        settings.dictationOutputMode = output
        let coordinator = SnapshotOverlayCoordinator()
        let viewModel = DictationViewModel(
            settings: settings, overlayBufferCoordinator: coordinator, startRuntimeServices: false
        )
        Self.retainedViewModels.append(viewModel)
        viewModel.isDictating = true
        viewModel.sessionOutputMode = output
        return (viewModel, coordinator)
    }

    func testRevisableOverlaySnapshotReplacesTentativeTextAndRejectsStaleFrame() {
        let (viewModel, coordinator) = makeViewModel(output: .overlayBuffer)
        viewModel.sessionTranscriptDelivery = .revisableSnapshot

        viewModel.handle(event: .transcriptSnapshot(.init(
            text: "I went too", sequence: 3, isFinal: false
        )))
        viewModel.handle(event: .transcriptSnapshot(.init(
            text: "I went to", sequence: 4, isFinal: false
        )))
        viewModel.handle(event: .transcriptSnapshot(.init(
            text: "stale text", sequence: 3, isFinal: false
        )))

        XCTAssertEqual(viewModel.pendingSegmentText, "I went to")
        XCTAssertEqual(viewModel.livePartialText, "I went to")
        XCTAssertEqual(coordinator.refreshes.map(\.display), ["I went too", "I went to"])
        XCTAssertEqual(coordinator.refreshes.map(\.commit), ["I went too", "I went to"])
    }

    func testLiveAutoPasteRejectsSnapshotReplacementEvenIfMisconfigured() {
        let (viewModel, coordinator) = makeViewModel(output: .liveAutoPaste)
        // Defence in depth: a misbehaving server must never make the live
        // insertion route behave like it can backspace text in another app.
        viewModel.sessionTranscriptDelivery = .revisableSnapshot

        viewModel.handle(event: .transcriptSnapshot(.init(
            text: "must not insert", sequence: 0, isFinal: false
        )))

        XCTAssertTrue(viewModel.pendingSegmentText.isEmpty)
        XCTAssertTrue(coordinator.refreshes.isEmpty)
    }

    func testFinalTranscriptAfterSnapshotPromotesOnlyAuthoritativeTextOnce() {
        let (viewModel, _) = makeViewModel(output: .overlayBuffer)
        viewModel.sessionTranscriptDelivery = .revisableSnapshot

        viewModel.handle(event: .transcriptSnapshot(.init(
            text: "I went too", sequence: 0, isFinal: false
        )))
        viewModel.handle(event: .transcriptSnapshot(.init(
            text: "I went to", sequence: 1, isFinal: true
        )))
        viewModel.handle(event: .finalTranscript("I went to"))

        XCTAssertEqual(viewModel.transcriptText, "I went to")
        XCTAssertTrue(viewModel.pendingSegmentText.isEmpty)
        XCTAssertTrue(viewModel.livePartialText.isEmpty)
    }

    func testEmptyFinalTranscriptClearsARevisableProvisionalSnapshot() {
        let (viewModel, coordinator) = makeViewModel(output: .overlayBuffer)
        viewModel.sessionTranscriptDelivery = .revisableSnapshot
        viewModel.handle(event: .transcriptSnapshot(.init(
            text: "tentative words", sequence: 0, isFinal: false
        )))

        viewModel.handle(event: .finalTranscript(""))

        XCTAssertTrue(viewModel.transcriptText.isEmpty)
        XCTAssertTrue(viewModel.pendingSegmentText.isEmpty)
        XCTAssertEqual(coordinator.refreshes.last?.display, "")
    }
}

private final class SnapshotOverlayCoordinator: OverlayBufferSessionCoordinating {
    struct Refresh: Equatable { let display: String; let commit: String }
    var refreshes: [Refresh] = []
    var commitTargetAppPID: pid_t? { nil }

    func resolveAnchorNow() -> OverlayAnchor {
        OverlayAnchor(targetRect: .zero, source: .windowCenter)
    }
    func startSession(preResolvedAnchor _: OverlayAnchor?, claudeJoin _: OverlayClaudeJoinBadge) {}
    func beginFinalizing(displayBufferText _: String, commitBufferText _: String) {}
    func refresh(displayBufferText: String, commitBufferText: String) {
        refreshes.append(.init(display: displayBufferText, commit: commitBufferText))
    }
    func commitIfNeeded(
        using _: OverlayTextCommitting, autoCopyEnabled _: Bool
    ) -> OverlayBufferCommitOutcome { .succeeded }
    func dismissAfterHold(minimumVisibility _: TimeInterval) {}
    func reset() {}
    func captureLiveCommitTargetAppPID() {}
}
