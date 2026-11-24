import RealityKit
import XCTest
@testable import Earprint

final class LiveActivityAndFallbackTests: XCTestCase {
    func testCollectibleModelFallbacks() {
        for key in [HeadphoneModelKey.overEarGeneric, .beatsOverEar] {
            XCTAssertEqual(key.collectibleModel, "HeadphoneGeneric")
        }
        for key in [HeadphoneModelKey.earbudsGeneric, .beatsEarbuds, .beatsEarhook] {
            XCTAssertEqual(key.collectibleModel, "")
        }
        for key in [HeadphoneModelKey.airpods, .airpods3] {
            XCTAssertNil(key.collectibleModel)
            XCTAssertEqual(key.collectibleArtwork, "CardRenderAirPodsOpen")
        }
    }

    @MainActor
    func testFallbackModelsHaveVisibleGeometry() async {
        XCTAssertNotNil(Bundle.main.url(forResource: "HeadphoneGeneric", withExtension: "usdz"))
        let overEar = await HeadphoneModelLoader.load(
            .overEar, finish: .spaceGray, assetName: "HeadphoneGeneric", modelKey: .overEarGeneric
        )
        XCTAssertGreaterThan(overEar.visualBounds(relativeTo: nil).extents.x, 0)

        let sportBuds = ProceduralHeadphones.make(.sportBuds, finish: .matteBlack)
        XCTAssertEqual(sportBuds.children.count, 2)
        XCTAssertGreaterThan(sportBuds.visualBounds(relativeTo: nil).extents.x, 0)

        let earbuds = await HeadphoneModelLoader.load(
            .earbuds, finish: .spaceGray, assetName: "", modelKey: .earbudsGeneric
        )
        XCTAssertEqual(earbuds.children.first?.children.count, 5)
        XCTAssertGreaterThan(earbuds.visualBounds(relativeTo: nil).extents.x, 0)
    }

    @MainActor
    func testActiveRouteReportsChangesAndReturnsFirstMatchingCard() {
        let cards = SampleCards.all
        var outputNames: [String] = []
        let monitor = ActiveAudioRouteMonitor(readOutputNames: { outputNames })
        var changes: [[String]] = []
        monitor.onRouteChange = { changes.append($0) }

        XCTAssertNil(monitor.activeMatchedCard(in: cards))
        let connectedNames = [cards[2].nickname, cards[1].nickname]
        outputNames = connectedNames
        monitor.refresh()
        monitor.refresh()
        XCTAssertEqual(monitor.activeMatchedCard(in: cards)?.id, cards[1].id)

        outputNames = []
        monitor.refresh()
        XCTAssertNil(monitor.activeMatchedCard(in: cards))
        XCTAssertEqual(changes, [connectedNames, []])
    }

    @MainActor
    func testRestIntervalClampsAndPersists() throws {
        let suite = "earprint.tests.liveActivity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let controller = LiveActivityController(defaults: defaults)
        XCTAssertEqual(controller.restIntervalMinutes, 60)
        XCTAssertEqual(controller.restInterval, 3_600)

        controller.restIntervalMinutes = 5
        XCTAssertEqual(controller.restInterval, 900)
        XCTAssertEqual(LiveActivityController(defaults: defaults).restIntervalMinutes, 15)

        controller.restIntervalMinutes = 240
        XCTAssertEqual(controller.restInterval, 10_800)
        XCTAssertEqual(LiveActivityController(defaults: defaults).restIntervalMinutes, 180)

        controller.restInterval = 2_700
        XCTAssertEqual(LiveActivityController(defaults: defaults).restIntervalMinutes, 45)
    }

    @MainActor
    func testRouteSyncDoesNotStartForLockedOrUnmatchedRoute() throws {
        let controller = LiveActivityController()
        try XCTSkipIf(controller.isRunning, "A Live Activity is already running in the test host.")
        let cards = SampleCards.all
        let monitor = ActiveAudioRouteMonitor(readOutputNames: { [cards[0].nickname] })

        controller.syncWithActiveRoute(cards: cards, routeMonitor: monitor, proUnlocked: false)
        XCTAssertFalse(controller.isRunning)
        XCTAssertNil(controller.lastError)

        controller.syncWithActiveRoute(cards: [], routeMonitor: monitor, proUnlocked: true)
        XCTAssertFalse(controller.isRunning)
        XCTAssertNil(controller.lastError)
    }
}
