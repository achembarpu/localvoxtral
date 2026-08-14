import XCTest

@testable import localvoxtral

final class SpeechModelCatalogTests: XCTestCase {
    func testManagedCatalogContainsOnlyBundledHelpers() {
        XCTAssertEqual(BackendCatalog.speechd.displayName, "Dictation engine")
        XCTAssertEqual(BackendCatalog.speechd.executableName, "localvoxtral-speechd")
        XCTAssertEqual(BackendCatalog.speechd.port, 8471)
        XCTAssertEqual(BackendCatalog.all.map(\.id), ["speechd", "polishd"])
        XCTAssertEqual(BackendCatalog.polishd.executableName, "localvoxtral-polishd")
    }

    func testSpeechModelCatalogPinsFullCommitSHA() {
        let option = SpeechModelCatalog.defaultOption
        XCTAssertEqual(option.repoID, "T0mSIlver/Voxtral-Mini-4B-Realtime-2602-4bit-qhead")
        XCTAssertEqual(option.revision.count, 40)
        XCTAssertTrue(option.revision.allSatisfy(\.isHexDigit))
    }

    @MainActor
    func testManagedSpeechModelSelectionPersistsAndResolvesCatalogOption() throws {
        let suiteName = "localvoxtral.speech-model.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults, environment: [:])

        XCTAssertEqual(settings.resolvedManagedSpeechModel, SpeechModelCatalog.defaultOption.repoID)
        XCTAssertEqual(settings.managedSpeechModel, SpeechModelCatalog.defaultOption.repoID)
        let nemotron = try XCTUnwrap(SpeechModelCatalog.option(forRepoID: "mlx-community/nemotron-3.5-asr-streaming-0.6b-8bit"))
        settings.managedSpeechModel = nemotron.repoID

        XCTAssertEqual(SettingsStore(defaults: defaults, environment: [:]).resolvedManagedSpeechModel, nemotron.repoID)
        XCTAssertEqual(SpeechModelCatalog.option(forRepoID: settings.resolvedManagedSpeechModel), nemotron)
    }

    @MainActor
    func testManagedSpeechModelSelectionRejectsUnknownStoredRepo() {
        let suiteName = "localvoxtral.speech-model.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unknown/model", forKey: "settings.managed_speech_model")

        let settings = SettingsStore(defaults: defaults, environment: [:])

        XCTAssertEqual(settings.resolvedManagedSpeechModel, SpeechModelCatalog.defaultOption.repoID)
        XCTAssertEqual(settings.managedSpeechModel, SpeechModelCatalog.defaultOption.repoID)
    }

}
