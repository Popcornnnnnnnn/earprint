import SwiftUI
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

    func testMotionHubDeadzoneFiltersGyroJitterAndAllowsRealTilt() {
        let origin = CGSize.zero
        XCTAssertFalse(MotionHub.shouldPublish(from: origin, to: CGSize(width: 0.002, height: -0.004)))
        XCTAssertFalse(MotionHub.shouldPublish(from: CGSize(width: 0.4, height: 0.2), to: CGSize(width: 0.405, height: 0.205)))
        XCTAssertTrue(MotionHub.shouldPublish(from: origin, to: CGSize(width: 0.01, height: 0)))
        XCTAssertTrue(MotionHub.shouldPublish(from: origin, to: CGSize(width: 0, height: -0.02)))
    }

    func testListeningGridOptimizedQueriesAndPersonaSinglePass() {
        // Empty grid edge case
        let empty = ListeningGrid(minutes: [], decibels: [])
        XCTAssertEqual(empty.maxMinutes, 0)
        XCTAssertEqual(empty.totalMinutes(lastDays: 7), 0)
        XCTAssertEqual(empty.averageDecibels(lastDays: 7), 0)
        XCTAssertEqual(empty.share(hours: [22, 23, 0], lastDays: 28), 0)
        XCTAssertNil(empty.dayAverageDecibels(dayIndex: 0))

        // Night-owl listening grid (all listening at 23:00 and 00:00)
        var minutes = Array(repeating: Array(repeating: 0.0, count: 24), count: 28)
        var decibels = Array(repeating: Array(repeating: 0.0, count: 24), count: 28)
        minutes[27][23] = 30
        decibels[27][23] = 60
        minutes[27][0] = 30
        decibels[27][0] = 70
        let grid = ListeningGrid(minutes: minutes, decibels: decibels)

        XCTAssertEqual(grid.maxMinutes, 30, accuracy: 0.001)
        XCTAssertEqual(grid.totalMinutes(lastDays: 7), 60, accuracy: 0.001)
        let expectedLeq = 10 * log10((pow(10.0, 6.0) + pow(10.0, 7.0)) / 2)
        XCTAssertEqual(grid.dayAverageDecibels(dayIndex: 27) ?? 0, expectedLeq, accuracy: 0.001)
        XCTAssertNil(grid.dayAverageDecibels(dayIndex: 26))
        XCTAssertNil(grid.dayAverageDecibels(dayIndex: 99))

        let summary = ListeningSummary(
            deviceName: "Test",
            deviceModel: "Test",
            periodLabel: "Nov 14 – 20",
            grid: grid,
            lifetimeMinutes: 60,
            sessions: 2,
            averageSessionMinutes: 30,
            longestSessionMinutes: 30,
            firstUse: "Nov 20"
        )
        XCTAssertEqual(summary.persona, .nightOwl(1.0))
    }

    func testCachedDateTextRespectsDifferentCalendarsAndTimeZones() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        // 2026-11-20 20:00 UTC is 2026-11-21 05:00 JST
        let date = utc.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 20))!
        XCTAssertEqual(DateText.dotted(date, calendar: utc), "2026.11.20")
        XCTAssertEqual(DateText.dotted(date, calendar: tokyo), "2026.11.21")
    }

    @MainActor
    func testHeadphoneLibraryCachesCombinedAndPerCardSummariesWithAliases() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("earprint-lib-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date()
        let pro1 = DeviceDescriptor(name: "My AirPods", manufacturer: "Apple Inc.", model: "0x2027", localIdentifier: "id-a")
        let proAlias = DeviceDescriptor(name: "MY AIRPODS", manufacturer: "0x004C", model: "0x2028", localIdentifier: "id-b")
        let maxDev = DeviceDescriptor(name: "Studio Max", manufacturer: "Apple Inc.", model: "0x201F", localIdentifier: "id-c")

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-3000), decibels: 62, device: pro1),
            RawListeningSample(start: now.addingTimeInterval(-2400), end: now.addingTimeInterval(-1800), decibels: 64, device: proAlias),
            RawListeningSample(start: now.addingTimeInterval(-1200), end: now.addingTimeInterval(-600), decibels: 68, device: maxDev),
        ], now: now, calendar: utc)

        let cache = AggregateCache(url: tempURL)
        cache.save(aggregate: agg, anchor: nil)

        let library = HeadphoneLibrary(cache: cache)
        XCTAssertEqual(library.cards.count, 2)
        let combined = library.summary(forCardID: nil)
        XCTAssertEqual(combined.lifetimeMinutes, 30, accuracy: 0.01)

        // Looking up by primary ID OR merged alias ID returns the exact same cached device summary
        let byPrimary = library.summary(forCardID: "lid:id-a")
        let byAlias = library.summary(forCardID: "lid:id-b")
        XCTAssertEqual(byPrimary, byAlias)
        XCTAssertEqual(byPrimary.lifetimeMinutes, 20, accuracy: 0.01)

        let maxSummary = library.summary(forCardID: "lid:id-c")
        XCTAssertEqual(maxSummary.lifetimeMinutes, 10, accuracy: 0.01)

        // Unknown ID safely falls back to combined summary
        XCTAssertEqual(library.summary(forCardID: "nonexistent"), combined)
    }

    @MainActor
    func testRingsHomeViewRendersFullHeightWithHoloAllHeadphones() throws {
        var holoSummary = SampleData.summary
        holoSummary.deviceName = "All Headphones"
        holoSummary.deviceModel = "7 pairs"
        holoSummary.deviceSymbol = "headphones"
        holoSummary.lifetimeMinutes = 2_450 * 60 + 18
        holoSummary.weeklyBudgetOverride = 0.34

        let view = HomeView(
            summary: holoSummary,
            primaryCard: nil,
            cards: SampleCards.all,
            summaryForCardID: { _ in holoSummary },
            isSampleData: false,
            isActiveTab: false
        )
        .preferredColorScheme(.dark)

        let size = CGSize(width: 393, height: 1280)
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true

        XCTAssertEqual(image.size.width, size.width, accuracy: 1)
        XCTAssertEqual(image.size.height, size.height, accuracy: 1)

        if let outPath = ProcessInfo.processInfo.environment["EARPRINT_RINGS_SNAPSHOT_PATH"],
           let png = image.pngData() {
            try png.write(to: URL(fileURLWithPath: outPath))
        }
    }

    @MainActor
    func testMotionHubScrollPauseHoldsTiltWithoutSnappingToZero() {
        let hub = MotionHub.shared
        hub.setScrolling(false, source: "test-scroll")
        hub.ingestRawTilt(CGSize(width: 0.8, height: -0.5))
        let held = hub.tilt
        XCTAssertGreaterThan(abs(held.width), 0.1)
        XCTAssertGreaterThan(abs(held.height), 0.1)

        // Pausing during scroll must hold the exact last tilt (no snap to .zero) and ignore updates.
        hub.setScrolling(true, source: "test-scroll")
        XCTAssertTrue(hub.isScrollPaused)
        XCTAssertEqual(hub.tilt, held)
        hub.ingestRawTilt(.zero)
        XCTAssertEqual(hub.tilt, held)

        // Resuming scroll re-enables tilt ingestion cleanly.
        hub.setScrolling(false, source: "test-scroll")
        XCTAssertFalse(hub.isScrollPaused)
        hub.ingestRawTilt(.zero)
        XCTAssertNotEqual(hub.tilt, held)

        // Clean up shared state back to rest.
        for _ in 0..<25 { hub.ingestRawTilt(.zero) }
    }

    func testListeningSummaryPrecomputedMetricsMatchGridQueriesAndUpdateOnGridMutation() {
        var minutes = Array(repeating: Array(repeating: 0.0, count: 24), count: 28)
        var decibels = Array(repeating: Array(repeating: 0.0, count: 24), count: 28)
        minutes[27][22] = 40
        decibels[27][22] = 70
        minutes[25][23] = 20
        decibels[25][23] = 80
        let grid = ListeningGrid(minutes: minutes, decibels: decibels)

        var summary = ListeningSummary(
            deviceName: "Pair",
            deviceModel: "AirPods Pro",
            periodLabel: "Nov 14 – 20",
            grid: grid,
            lifetimeMinutes: 60,
            sessions: 2,
            averageSessionMinutes: 30,
            longestSessionMinutes: 40,
            firstUse: "Nov 18"
        )

        XCTAssertTrue(summary.has28DayData)
        XCTAssertEqual(summary.weekMinutes, grid.totalMinutes(lastDays: 7), accuracy: 0.001)
        XCTAssertEqual(summary.weekDecibels, grid.averageDecibels(lastDays: 7), accuracy: 0.001)
        XCTAssertEqual(summary.last7Days.count, 7)
        XCTAssertEqual(summary.last7Days[6].minutes, 40, accuracy: 0.001)
        XCTAssertEqual(summary.last7Days[6].decibels ?? 0, 70, accuracy: 0.001)
        XCTAssertEqual(summary.last7Days[4].minutes, 20, accuracy: 0.001)
        XCTAssertEqual(summary.last7Days[4].decibels ?? 0, 80, accuracy: 0.001)
        XCTAssertNil(summary.last7Days[0].decibels)
        XCTAssertEqual(summary.persona, .nightOwl(1.0))

        // Mutating `grid` must automatically refresh precomputed values.
        summary.grid = ListeningGrid(minutes: [], decibels: [])
        XCTAssertFalse(summary.has28DayData)
        XCTAssertEqual(summary.weekMinutes, 0)
        XCTAssertEqual(summary.last7Days.count, 0)
        XCTAssertEqual(summary.persona, .allDay)
    }

    @MainActor
    func testSampleModeLibraryUsesCurrentLocalizedWeekRange() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("earprint-empty-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let library = HeadphoneLibrary(cache: AggregateCache(url: tempURL))
        let combined = library.summary(forCardID: nil)
        let expectedRange = DateText.weekRange(endingAt: Date(), calendar: .current)
        XCTAssertEqual(combined.periodLabel, expectedRange)
    }

    func testOptimizedDeviceDossierStatsConsistencyOnHeavyTwoYearHoloCard() {
        var holo = SampleCards.all[0]
        holo.lifetimeMinutes = 2_450 * 60
        holo.sessions = 1_200
        holo.longestMinutes = 360
        holo.firstMet = "2024.11.20"
        holo.lastUsed = "Today"

        let dossier = DeviceDossier.sample(for: holo, now: DossierSample.referenceNow)
        XCTAssertGreaterThan(dossier.days.count, 700)
        XCTAssertEqual(dossier.rarity, .holo)

        for period in DossierPeriod.allCases {
            let stats = dossier.stats(period)
            let hourSum = stats.hours.reduce(0) { $0 + $1.minutes }
            XCTAssertEqual(hourSum, stats.totalMinutes, accuracy: 0.01, "24h sum mismatch for \(period)")
            let bucketSum = stats.buckets.reduce(0) { $0 + $1.minutes }
            if period != .year {
                XCTAssertEqual(bucketSum, stats.totalMinutes, accuracy: 0.5, "Bucket sum mismatch for \(period)")
            }
            XCTAssertGreaterThan(stats.buckets.count, 0)
        }
    }

    @MainActor
    func testShareCardAndBatchedEarprintGlyphRenderNonBlankImage() {
        let defaultRenderer = ImageRenderer(
            content: ShareCardView(summary: SampleData.summary, primaryCard: SampleCards.all.first)
                .environment(\.colorScheme, .dark)
        )
        defaultRenderer.scale = 2
        let defaultImage = defaultRenderer.uiImage
        XCTAssertNotNil(defaultImage)
        XCTAssertEqual(defaultImage?.size.width ?? 0, 360, accuracy: 1)
        XCTAssertEqual(defaultImage?.size.height ?? 0, 480, accuracy: 1)
        XCTAssertGreaterThan(defaultImage?.pngData()?.count ?? 0, 10_000)

        let lightPortraitRenderer = ImageRenderer(
            content: ShareCardView(
                summary: SampleData.summary,
                primaryCard: SampleCards.all.first,
                aspect: .portrait3x4,
                colorScheme: .light
            )
            .environment(\.colorScheme, .light)
        )
        lightPortraitRenderer.scale = 2
        let lightPortrait = lightPortraitRenderer.uiImage
        XCTAssertNotNil(lightPortrait)
        XCTAssertEqual(lightPortrait?.size.width ?? 0, 360, accuracy: 1)
        XCTAssertEqual(lightPortrait?.size.height ?? 0, 480, accuracy: 1)
        XCTAssertGreaterThan(lightPortrait?.pngData()?.count ?? 0, 10_000)

        let storyRenderer = ImageRenderer(
            content: ShareCardView(
                summary: SampleData.summary,
                primaryCard: SampleCards.all.first,
                aspect: .story9x16,
                colorScheme: .dark
            )
            .environment(\.colorScheme, .dark)
        )
        storyRenderer.scale = 2
        let storyImage = storyRenderer.uiImage
        XCTAssertNotNil(storyImage)
        XCTAssertEqual(storyImage?.size.width ?? 0, 360, accuracy: 1)
        XCTAssertEqual(storyImage?.size.height ?? 0, 640, accuracy: 1)
        XCTAssertGreaterThan(storyImage?.pngData()?.count ?? 0, 10_000)
    }

    @MainActor
    func testRingsHomeViewExtremeNarrowAndEdgeCaseBudgetsRenderCleanly() throws {
        var narrowSummary = SampleData.summary
        narrowSummary.deviceName = "All Headphones"
        narrowSummary.deviceModel = "7 pairs"
        narrowSummary.deviceSymbol = "headphones"
        narrowSummary.lifetimeMinutes = 620 * 60 + 45 // DEEP PURPLE (longest shortName!)
        narrowSummary.weeklyBudgetOverride = 0.001 // Rounds to 0% used

        let view = HomeView(
            summary: narrowSummary,
            primaryCard: nil,
            cards: SampleCards.all,
            summaryForCardID: { _ in narrowSummary },
            isSampleData: false,
            isActiveTab: false
        )
        .preferredColorScheme(.dark)

        let size = CGSize(width: 375, height: 1280)
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true

        XCTAssertEqual(image.size.width, size.width, accuracy: 1)
        XCTAssertEqual(image.size.height, size.height, accuracy: 1)

        if let outPath = ProcessInfo.processInfo.environment["EARPRINT_RINGS_NARROW_SNAPSHOT_PATH"],
           let png = image.pngData() {
            try png.write(to: URL(fileURLWithPath: outPath))
        }
    }

    @MainActor
    func testCardTiersFullBinderRendersCleanly() throws {
        var maxHoloCard = SampleCards.all[0]
        maxHoloCard.lifetimeMinutes = 2_100 * 60
        let cards = [maxHoloCard] + SampleCards.all.dropFirst()
        let size = CGSize(width: 393, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2

        for (index, scheme) in [ColorScheme.dark, ColorScheme.light].enumerated() {
            let view = NavigationStack {
                CardTiersView(ownedCards: cards)
            }
            .preferredColorScheme(scheme)

            let host = UIHostingController(rootView: view)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            window.isHidden = true

            XCTAssertEqual(image.size.width, size.width, accuracy: 1)
            XCTAssertEqual(image.size.height, size.height, accuracy: 1)
            XCTAssertGreaterThan(image.pngData()?.count ?? 0, 10_000)

            if index == 0,
               let outPath = ProcessInfo.processInfo.environment["EARPRINT_TIERS_SNAPSHOT_PATH"],
               let png = image.pngData() {
                try png.write(to: URL(fileURLWithPath: outPath))
            }
        }
    }

    @MainActor
    func testCardDetailMultiCardDeckRendersCleanly() {
        let cards = SampleCards.all
        XCTAssertGreaterThanOrEqual(cards.count, 3)

        let view = CardDetail(
            card: cards[1],
            cards: cards,
            colorStore: DeviceColorStore(defaults: UserDefaults(suiteName: "CardDetailRenderTest") ?? .standard),
            onSelectCard: { _ in },
            openDossier: {},
            openTiers: {},
            close: {}
        )
        .preferredColorScheme(.dark)

        let size = CGSize(width: 393, height: 852)
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true

        XCTAssertEqual(image.size.width, size.width, accuracy: 1)
        XCTAssertEqual(image.size.height, size.height, accuracy: 1)
        XCTAssertGreaterThan(image.pngData()?.count ?? 0, 5_000)
    }
}
