import XCTest
@testable import Earprint

final class IntegrationRegressionTests: XCTestCase {
    /// Regression for P0: real HealthKit headphones first worn after DossierSample.referenceNow must not crash.
    func testDossierSampleHandlesFutureFirstMetDateWithoutCrashing() {
        var card = SampleCards.all[0]
        card.firstMet = "2027.03.15"
        card.lastUsed = "Today"

        let dossier = DeviceDossier.sample(for: card)
        XCTAssertFalse(dossier.days.isEmpty)
        XCTAssertGreaterThan(dossier.lifetimeMinutes, 0)
        XCTAssertGreaterThan(dossier.stats(.all).totalMinutes, 0)
    }

    /// Regression for P1: real HealthKit device IDs containing '/', '?', '#', '|' must round-trip through EarprintLink.
    func testDeepLinkRoundTripsSpecialCharactersInDeviceID() {
        let specialIDs = [
            "nm:Sony/WH-1000XM5|Sony|-",
            "nm:Bob's AirPods? #1|Apple Inc.|0x2024",
            "udi:com.apple.bt/ABC#123?v=2",
            "pro2"
        ]
        for id in specialIDs {
            let url = EarprintLink.card(id)
            XCTAssertEqual(EarprintLink.route(for: url), .card(id), "Failed to round-trip \(id)")
        }
        // Legacy path-based URLs remain supported.
        let legacy = URL(string: "earprint://card/pro2")!
        XCTAssertEqual(EarprintLink.route(for: legacy), .card("pro2"))
    }
}
