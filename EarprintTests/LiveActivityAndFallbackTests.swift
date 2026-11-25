import RealityKit
import XCTest
@testable import Earprint

final class LiveActivityAndFallbackTests: XCTestCase {
    func testCollectibleModelFallbacks() {
        XCTAssertEqual(HeadphoneModelKey.overEarGeneric.collectibleModel, "HeadphoneGeneric")
        XCTAssertEqual(HeadphoneModelKey.earbudsGeneric.collectibleModel, "EarbudsGeneric")
        XCTAssertEqual(HeadphoneModelKey.beatsOverEar.collectibleModel, "BeatsOverEar")
        XCTAssertEqual(HeadphoneModelKey.beatsEarbuds.collectibleModel, "BeatsBuds")
        XCTAssertEqual(HeadphoneModelKey.beatsEarhook.collectibleModel, "BeatsEarhook")
        for key in [HeadphoneModelKey.airpods, .airpods3, .airpods4] {
            XCTAssertEqual(key.collectibleModel, "AirPods4")
        }
        for key in [HeadphoneModelKey.airpods, .airpods3] {
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

        func firstBaseTexture(in entity: Entity) -> MaterialParameters.Texture? {
            if let model = (entity as? ModelEntity)?.model {
                for mat in model.materials {
                    if let pbr = mat as? PhysicallyBasedMaterial, let tex = pbr.baseColor.texture {
                        return tex
                    }
                }
            }
            for child in entity.children {
                if let tex = firstBaseTexture(in: child) { return tex }
            }
            return nil
        }
        XCTAssertNotNil(firstBaseTexture(in: overEar))

        for (asset, key, kind) in [
            ("BeatsBuds", HeadphoneModelKey.beatsEarbuds, HeadphoneKind.sportBuds),
            ("BeatsEarhook", HeadphoneModelKey.beatsEarhook, HeadphoneKind.sportBuds),
            ("BeatsOverEar", HeadphoneModelKey.beatsOverEar, HeadphoneKind.overEar),
            ("EarbudsGeneric", HeadphoneModelKey.earbudsGeneric, HeadphoneKind.earbuds),
        ] {
            XCTAssertNotNil(Bundle.main.url(forResource: asset, withExtension: "usdz"), "Missing \(asset).usdz")
            let loaded = await HeadphoneModelLoader.load(kind, finish: .matteBlack, assetName: asset, modelKey: key)
            XCTAssertGreaterThan(loaded.visualBounds(relativeTo: nil).extents.x, 0)
            if let alt = DeviceColorOption.options(for: key).last {
                HeadphoneModelLoader.applyFinish(alt.modelFinish, to: loaded, modelKey: key)
            }
            XCTAssertGreaterThan(loaded.visualBounds(relativeTo: nil).extents.x, 0)
        }

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
        // Third-party generic devices stay in Rings stats & recent dB, without minting Collection cards.
        let cards = fresh.cards(now: now, calendar: utc)
        XCTAssertTrue(cards.isEmpty)

        let studio = fresh.devices.first { !$0.isUnattributed }
        XCTAssertNotNil(studio)
        XCTAssertGreaterThan(studio?.averageDecibels ?? 0, 80)
        XCTAssertEqual(try XCTUnwrap(studio?.recentSessionDecibels), 62, accuracy: 0.1)

        let stale = LibrarySnapshot(aggregate: aggregate, now: now.addingTimeInterval(35 * 60), calendar: utc)
        XCTAssertNil(stale.devices.first { !$0.isUnattributed }?.recentSessionDecibels)
    }

    @MainActor
    func testManualActivityFlagRestoresForMatchingActivityAndClearsWhenGone() throws {
        let suite = "earprint.tests.manualActivity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        LiveActivityController.persistManualState(true, activeActivityID: "act-123", defaults: defaults)
        XCTAssertTrue(LiveActivityController.restoreManualState(activeActivityID: "act-123", defaults: defaults))
        XCTAssertTrue(LiveActivityController.restoreManualState(activeActivityID: "act-123", defaults: defaults))

        // Different surviving activity clears stale manual flag.
        XCTAssertFalse(LiveActivityController.restoreManualState(activeActivityID: "act-other", defaults: defaults))
        XCTAssertFalse(LiveActivityController.restoreManualState(activeActivityID: "act-123", defaults: defaults))

        // Missing activity clears persisted manual flag.
        LiveActivityController.persistManualState(true, activeActivityID: "act-456", defaults: defaults)
        XCTAssertFalse(LiveActivityController.restoreManualState(activeActivityID: nil, defaults: defaults))
        XCTAssertFalse(LiveActivityController.restoreManualState(activeActivityID: "act-456", defaults: defaults))
    }
}
