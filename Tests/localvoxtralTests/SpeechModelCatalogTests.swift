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

    func testNemotronOptionSelectsStreamingEngineAndPinnedRevision() {
        let repoID = "mlx-community/nemotron-3.5-asr-streaming-0.6b-8bit"
        let option = SpeechModelCatalog.option(forRepoID: repoID)

        XCTAssertEqual(option?.repoID, repoID)
        XCTAssertEqual(option?.engine, .nemotron)
        XCTAssertEqual(option?.revision, "7279359e4481b5e9e185a318bd618e429c6d86cd")
    }

    func testCatalogOptionsHaveUniquePinnedModelIDs() {
        let repoIDs = SpeechModelCatalog.options.map(\.repoID)

        XCTAssertEqual(Set(repoIDs).count, repoIDs.count)
        XCTAssertTrue(SpeechModelCatalog.options.allSatisfy {
            $0.revision.count == 40 && $0.revision.allSatisfy(\.isHexDigit)
        })
    }
}
