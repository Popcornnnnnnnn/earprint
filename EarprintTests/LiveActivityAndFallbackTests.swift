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
    func testActiveRoutePrefersExactMatchOverSubstringAndRejectsAmbiguousSubstring() {
        var first = SampleCards.all[0]
        var second = SampleCards.all[1]
        first.nickname = "AirPods Pro"
        first.model = "Model A"
        second.nickname = "AirPods"
        second.model = "Model B"

        var output = ["AirPods"]
        let monitor = ActiveAudioRouteMonitor(readOutputNames: { output })
        XCTAssertEqual(monitor.activeMatchedCard(in: [first, second])?.id, second.id)

        first.nickname = "Studio Pro"
        second.nickname = "Studio Mini"
        output = ["Studio"]
        monitor.refresh()
        XCTAssertNil(monitor.activeMatchedCard(in: [first, second]))
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

    func testUnattributedExcludedFromCardsAndRecentSessionDecibelsUsesLatestSpanOnly() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let thirdParty = DeviceDescriptor(name: "Studio Monitor", localIdentifier: "studio-1")
        let samples = [
            RawListeningSample(
                start: now.addingTimeInterval(-3 * 3600),
                end: now.addingTimeInterval(-2 * 3600),
                decibels: 70,
                device: nil
            ),
            RawListeningSample(
                start: now.addingTimeInterval(-10 * 3600),
                end: now.addingTimeInterval(-6 * 3600),
                decibels: 85,
                device: thirdParty
            ),
            RawListeningSample(
                start: now.addingTimeInterval(-25 * 60),
                end: now.addingTimeInterval(-10 * 60),
                decibels: 62,
                device: thirdParty
            )
        ]

        var aggregate = ListeningAggregate()
        aggregate.ingest(samples, now: now, calendar: utc)

        let fresh = LibrarySnapshot(aggregate: aggregate, now: now, calendar: utc)
        XCTAssertEqual(fresh.lifetimeSeconds, 315 * 60, accuracy: 0.1)
        let cards = fresh.cards(now: now, calendar: utc)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.nickname, "Studio Monitor")

        let studio = fresh.devices.first { !$0.isUnattributed }
        XCTAssertNotNil(studio)
        XCTAssertGreaterThan(studio?.averageDecibels ?? 0, 80)
        XCTAssertEqual(try XCTUnwrap(studio?.recentSessionDecibels), 62, accuracy: 0.1)

        let stale = LibrarySnapshot(aggregate: aggregate, now: now.addingTimeInterval(35 * 60), calendar: utc)
        XCTAssertNil(stale.devices.first { !$0.isUnattributed }?.recentSessionDecibels)
    }
}
