import SwiftUI
import XCTest
@testable import Earprint

final class DeviceLifecycleTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @MainActor
    func testDeviceLifecycleStoreRetireEditUnretireAndAliasMatching() {
        let suiteName = "DeviceLifecycleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store1 = DeviceLifecycleStore(defaults: defaults)
        var maxCard = SampleCards.all[1]
        maxCard.aliasIDs = ["max-old-lid"]

        XCTAssertFalse(store1.isRetired(maxCard))

        let longNote = "  First flight\n  to Tokyo  " + String(repeating: "x", count: 90)
        let retireDate = date(2026, 9, 2)
        store1.retire(maxCard, at: retireDate, reason: .battery, farewellNote: longNote)

        XCTAssertTrue(store1.isRetired(maxCard))
        let saved = store1.retirement(for: maxCard)
        XCTAssertEqual(saved?.reason, .battery)
        XCTAssertEqual(saved?.retiredAt, retireDate)
        XCTAssertEqual(saved?.farewellNote.count, DeviceRetirement.maxFarewellLength)
        XCTAssertFalse(saved?.farewellNote.contains("\n") ?? true)

        // Reload from UserDefaults and match across alias IDs.
        let store2 = DeviceLifecycleStore(defaults: defaults)
        let mergedCard = HeadphoneCard(
            id: "max-new-lid",
            nickname: maxCard.nickname,
            model: maxCard.model,
            symbol: maxCard.symbol,
            lifetimeMinutes: maxCard.lifetimeMinutes,
            sessions: maxCard.sessions,
            longestMinutes: maxCard.longestMinutes,
            averageDecibels: maxCard.averageDecibels,
            firstMet: maxCard.firstMet,
            lastUsed: maxCard.lastUsed,
            serial: maxCard.serial,
            grid: maxCard.grid,
            modelKey: maxCard.modelKey,
            kind: maxCard.kind,
            aliasIDs: [maxCard.id, "max-old-lid"]
        )
        XCTAssertTrue(store2.isRetired(mergedCard))
        XCTAssertEqual(store2.retirement(for: mergedCard)?.reason, .battery)

        // Re-saving under merged primary ID clears old alias entries and unretire removes all.
        store2.retire(mergedCard, at: retireDate, reason: .upgraded, farewellNote: "Moved to USB-C")
        XCTAssertNil(store2.retirements[maxCard.id])
        XCTAssertEqual(store2.retirement(for: mergedCard)?.reason, .upgraded)
        XCTAssertEqual(store2.retirement(for: mergedCard)?.farewellNote, "Moved to USB-C")

        store2.unretire(mergedCard)
        XCTAssertFalse(store2.isRetired(mergedCard))
        XCTAssertTrue(DeviceLifecycleStore(defaults: defaults).retirements.isEmpty)
    }

    @MainActor
    func testPostRetirementActivityDetectionAndAcknowledgment() {
        let suiteName = "DeviceLifecycleActivityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DeviceLifecycleStore(defaults: defaults)
        let card = SampleCards.all[1]
        let retiredDate = date(2026, 9, 2, hour: 12)
        store.retire(card, at: retiredDate, reason: .giftedOrSold, farewellNote: "")

        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: nil))
        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: retiredDate))
        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: retiredDate.addingTimeInterval(30)))

        let nextDayWear = date(2026, 9, 3, hour: 10)
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: nextDayWear))

        store.acknowledgePostRetirementActivity(for: card, activityDate: nextDayWear)
        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: nextDayWear))

        let laterWear = date(2026, 9, 5, hour: 10)
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: laterWear))
    }

    @MainActor
    func testInactivityNudgeRespects90DaysAndMultipleActivePairs() {
        let suiteName = "DeviceLifecycleNudgeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DeviceLifecycleStore(defaults: defaults)
        let card = SampleCards.all[1]
        let lastWear = date(2026, 8, 1)
        let day89 = utcCalendar.date(byAdding: .day, value: 89, to: lastWear)!
        let day90 = utcCalendar.date(byAdding: .day, value: 90, to: lastWear)!

        XCTAssertFalse(store.shouldSuggestRetirement(for: card, lastWear: lastWear, totalActiveCardCount: 2, now: day89, calendar: utcCalendar))
        XCTAssertFalse(store.shouldSuggestRetirement(for: card, lastWear: lastWear, totalActiveCardCount: 1, now: day90, calendar: utcCalendar))
        XCTAssertTrue(store.shouldSuggestRetirement(for: card, lastWear: lastWear, totalActiveCardCount: 2, now: day90, calendar: utcCalendar))

        store.retire(card, at: lastWear, reason: .upgraded, farewellNote: "")
        XCTAssertFalse(store.shouldSuggestRetirement(for: card, lastWear: lastWear, totalActiveCardCount: 2, now: day90, calendar: utcCalendar))
    }

    func testRetiredDossierFreezesCareerSpanStatsAndReplacesUpcomingMilestone() {
        let cal = utcCalendar
        let start = date(2025, 1, 1, hour: 10)
        let lastSession = date(2025, 3, 2, hour: 10)
        let distantNow = date(2026, 11, 27, hour: 12)

        var sessions: [WearSession] = []
        for dayOffset in 0...60 {
            let s = cal.date(byAdding: .day, value: dayOffset, to: start)!
            sessions.append(WearSession(start: s, minutes: 60, averageDecibels: 64, peakDecibels: 74, isEstimated: false))
        }

        let hardware = DossierSample.hardware(for: SampleCards.all[1])
        let activeDossier = DeviceDossier(
            id: "max",
            nickname: "Studio Max",
            symbol: "airpodsmax",
            serial: 1,
            hardware: hardware,
            sessions: sessions,
            otherDevicesDailyMinutes: [:],
            sampleCount: 120,
            lastSynced: distantNow,
            retirement: nil,
            now: distantNow,
            calendar: cal
        )

        let activeAtLastSession = DeviceDossier(
            id: "max",
            nickname: "Studio Max",
            symbol: "airpodsmax",
            serial: 1,
            hardware: hardware,
            sessions: sessions,
            otherDevicesDailyMinutes: [:],
            sampleCount: 120,
            lastSynced: lastSession,
            retirement: nil,
            now: lastSession,
            calendar: cal
        )

        let retirement = DeviceRetirement(retiredAt: lastSession, reason: .upgraded, farewellNote: "Moved to USB-C")
        let retiredDossier = DeviceDossier(
            id: "max",
            nickname: "Studio Max",
            symbol: "airpodsmax",
            serial: 1,
            hardware: hardware,
            sessions: sessions,
            otherDevicesDailyMinutes: [:],
            sampleCount: 120,
            lastSynced: distantNow,
            retirement: retirement,
            now: distantNow,
            calendar: cal
        )

        XCTAssertTrue(retiredDossier.isRetired)
        XCTAssertEqual(retiredDossier.lifetimeMinutes, activeDossier.lifetimeMinutes, accuracy: 0.01)
        XCTAssertEqual(retiredDossier.historyDays, 61)
        XCTAssertGreaterThan(activeDossier.historyDays, 600)
        XCTAssertEqual(retiredDossier.stats(.all).dailyAverage, 60, accuracy: 0.5)
        XCTAssertGreaterThan(retiredDossier.stats(.all).dailyAverage, activeDossier.stats(.all).dailyAverage * 5)

        XCTAssertFalse(retiredDossier.milestones.contains { $0.kind == .upcoming })
        XCTAssertTrue(retiredDossier.milestones.contains { $0.kind == .retired && $0.title == "Retired to Vault" })
        XCTAssertTrue(activeAtLastSession.milestones.contains { $0.kind == .upcoming })
    }

    @MainActor
    func testWidgetSnapshotExcludesRetiredCardsFromShelfWhileKeepingTodayTotals() {
        let cal = utcCalendar
        let now = date(2026, 11, 20, hour: 15)
        let activeDev = DeviceDescriptor(name: "Pocket Pro", manufacturer: "Apple Inc.", model: "0x2024", localIdentifier: "active-pro")
        let retiredDev = DeviceDescriptor(name: "Old Max", manufacturer: "Apple Inc.", model: "0x200A", localIdentifier: "old-max")

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-1800), decibels: 62, device: activeDev),
            RawListeningSample(start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-5400), decibels: 66, device: retiredDev),
        ], now: now, calendar: cal)

        let snapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let cards = snapshot.cards(now: now, calendar: cal)
        XCTAssertEqual(cards.count, 2)

        let suiteName = "WidgetVaultTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DeviceLifecycleStore(defaults: defaults)
        let maxCard = cards.first { $0.modelKey == .airpodsMax }!
        store.retire(maxCard, at: now, reason: .upgraded, farewellNote: "")

        let activeCards = cards.filter { !store.isRetired($0) }
        let summary = snapshot.combinedHomeSummary(now: now, calendar: cal)!
        let widgetSnapshot = WidgetSnapshot(summary: summary, cards: activeCards, isSample: false, listening: snapshot, now: now, calendar: cal)

        XCTAssertEqual(widgetSnapshot.cards.count, 1)
        XCTAssertEqual(widgetSnapshot.cards.first?.model, "AirPods Pro 2 · USB-C")
        XCTAssertEqual(widgetSnapshot.today.minutes, 60, accuracy: 0.01)
    }

    @MainActor
    func testVaultedViewsAndFarewellPosterRenderCleanly() throws {
        let suiteName = "VaultRenderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DeviceLifecycleStore(defaults: defaults)
        let maxCard = SampleCards.all[1]
        let retirement = DeviceRetirement(
            retiredAt: date(2026, 9, 2),
            reason: .upgraded,
            farewellNote: "Three winters & 40 flights"
        )
        store.retire(maxCard, at: retirement.retiredAt, reason: retirement.reason, farewellNote: retirement.farewellNote)

        let retiredDossier = DeviceDossier.sample(for: maxCard, retirement: retirement, now: DossierSample.referenceNow)
        let color = DeviceColorOption.defaultOption(for: maxCard.modelKey)

        for (idx, scheme) in [ColorScheme.dark, ColorScheme.light].enumerated() {
            let pages = DossierShareRenderer.renderPages(
                card: maxCard,
                dossier: retiredDossier,
                period: .all,
                color: color,
                isSampleData: true,
                format: .simple,
                scheme: scheme
            )
            XCTAssertEqual(pages.count, 1)
            XCTAssertGreaterThan(pages[0].pngData.count, 10_000)

            let longPages = DossierShareRenderer.renderPages(
                card: maxCard,
                dossier: retiredDossier,
                period: .all,
                color: color,
                isSampleData: true,
                format: .long,
                scheme: scheme
            )
            XCTAssertEqual(longPages.count, 4)

            let collection = CollectionView(cards: SampleCards.all, isSampleData: true)
                .environment(store)
                .environment(DeviceColorStore(defaults: defaults))
                .preferredColorScheme(scheme)
            let collectionImage = renderHosting(collection, size: CGSize(width: 393, height: 852))
            XCTAssertGreaterThan(collectionImage.pngData()?.count ?? 0, 10_000)

            if let outDir = ProcessInfo.processInfo.environment["EARPRINT_VAULT_PREVIEW_DIR"] {
                let dirURL = URL(fileURLWithPath: outDir, isDirectory: true)
                let modeName = idx == 0 ? "dark" : "light"
                try pages[0].pngData.write(to: dirURL.appendingPathComponent("farewell-poster-\(modeName).png"))
                if let cData = collectionImage.pngData() {
                    try cData.write(to: dirURL.appendingPathComponent("collection-vault-\(modeName).png"))
                }
                if idx == 0 {
                    let dossierView = DeviceDossierView(card: maxCard, dossier: retiredDossier, isSampleData: true)
                        .environment(store)
                        .environment(DeviceColorStore(defaults: defaults))
                        .preferredColorScheme(.dark)
                    let dossierImg = renderHosting(dossierView, size: CGSize(width: 393, height: 960))
                    if let dData = dossierImg.pngData() {
                        try dData.write(to: dirURL.appendingPathComponent("dossier-vault-dark.png"))
                    }

                    let sheet = RetireDeviceSheet(
                        card: SampleCards.all[0],
                        firstWear: retiredDossier.firstWear,
                        lastWear: SampleCards.all[0].lastWearDate,
                        existingRetirement: nil,
                        onSave: { _ in }
                    )
                    .preferredColorScheme(.dark)
                    let sheetImg = renderHosting(sheet, size: CGSize(width: 393, height: 852))
                    if let sData = sheetImg.pngData() {
                        try sData.write(to: dirURL.appendingPathComponent("retire-sheet-dark.png"))
                    }
                }
            }
        }
    }

    @MainActor
    private func renderHosting<V: View>(_ view: V, size: CGSize) -> UIImage {
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
        return image
    }
}
