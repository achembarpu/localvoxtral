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

    func testGraniteCatalogUsesSpeech41NotRetiredSpeech40() {
        guard let granite = SpeechModelCatalog.options.first(where: { $0.engine == .granite }) else {
            return XCTFail("Granite Speech 4.1 must remain a managed experimental option.")
        }

        XCTAssertEqual(granite.repoID, "divydeep/granite-speech-4.1-2b-mlx-4bit")
        XCTAssertEqual(granite.revision, "746628663cd779a680e64e0b3f0fb9b34740029d")
        XCTAssertFalse(SpeechModelCatalog.options.contains { $0.repoID.contains("granite-speech-4.0") })
    }

}
