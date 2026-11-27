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
        let retireDate = date(2026, 9, 2, hour: 15)
        store1.retire(maxCard, at: retireDate, reason: .battery, farewellNote: longNote, calendar: utcCalendar)

        XCTAssertTrue(store1.isRetired(maxCard))
        let saved = store1.retirement(for: maxCard)
        XCTAssertEqual(saved?.reason, .battery)
        XCTAssertEqual(saved?.retiredDay, DeviceRetirement.CalendarDay(year: 2026, month: 9, day: 2))
        XCTAssertEqual(saved?.timeZoneIdentifier, utcCalendar.timeZone.identifier)
        XCTAssertEqual(saved?.formattedRetiredDate, "2026.09.02")
        XCTAssertEqual(saved?.farewellNote.count, DeviceRetirement.maxFarewellLength)
        XCTAssertFalse(saved?.farewellNote.contains("\n") ?? true)
        XCTAssertEqual(DeviceRetirement.clampEditingNote("Line 1\nLine 2 "), "Line 1 Line 2 ")
        XCTAssertEqual(DeviceRetirement.clampEditingNote(longNote).count, DeviceRetirement.maxFarewellLength)

        // Legacy records without retiredDay / timeZoneIdentifier still decode cleanly.
        let legacyJSON = """
        {"retiredAt":1788307200,"reason":"lost","farewellNote":"Left on train"}
        """.data(using: .utf8)!
        let decodedLegacy = try! JSONDecoder().decode(DeviceRetirement.self, from: legacyJSON)
        XCTAssertEqual(decodedLegacy.reason, .lost)
        XCTAssertEqual(decodedLegacy.farewellNote, "Left on train")
        XCTAssertFalse(decodedLegacy.formattedRetiredDate.isEmpty)

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
        store2.retire(mergedCard, at: retireDate, reason: .upgraded, farewellNote: "Moved to USB-C", calendar: utcCalendar)
        XCTAssertNil(store2.retirements[maxCard.id])
        XCTAssertEqual(store2.retirement(for: mergedCard)?.reason, .upgraded)
        XCTAssertEqual(store2.retirement(for: mergedCard)?.farewellNote, "Moved to USB-C")

        store2.unretire(mergedCard)
        XCTAssertFalse(store2.isRetired(mergedCard))
        XCTAssertTrue(DeviceLifecycleStore(defaults: defaults).retirements.isEmpty)
    }

    @MainActor
    func testPostRetirementActivityDetectionUsesDayCutoffAndClearsAckOnDateChange() {
        let suiteName = "DeviceLifecycleActivityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DeviceLifecycleStore(defaults: defaults)
        let card = SampleCards.all[1]
        let retiredDate = date(2026, 9, 2, hour: 10)
        store.retire(card, at: retiredDate, reason: .giftedOrSold, farewellNote: "", calendar: utcCalendar)

        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: nil))
        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: retiredDate))
        // Later the same calendar day does not trigger post-retirement reactivation.
        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: date(2026, 9, 2, hour: 23)))

        let nextDayWear = date(2026, 9, 3, hour: 0)
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: nextDayWear))

        store.acknowledgePostRetirementActivity(for: card, activityDate: nextDayWear)
        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: nextDayWear))

        let laterWear = date(2026, 9, 5, hour: 10)
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: laterWear))

        // Changing retirement day invalidates prior activity acknowledgment.
        let edited = DeviceRetirement(retiredAt: date(2026, 9, 1), reason: .giftedOrSold, farewellNote: "", calendar: utcCalendar)
        store.saveRetirement(edited, for: card)
        XCTAssertNil(store.retirement(for: card)?.acknowledgedActivityAt)
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: nextDayWear))
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

        store.retire(card, at: lastWear, reason: .upgraded, farewellNote: "", calendar: utcCalendar)
        XCTAssertFalse(store.shouldSuggestRetirement(for: card, lastWear: lastWear, totalActiveCardCount: 2, now: day90, calendar: utcCalendar))
    }

    @MainActor
    func testRetiredDossierFreezesStatsAtCutoffAcrossBackdatedSyncAndTimeZones() {
        let cal = utcCalendar
        let start = date(2025, 1, 1, hour: 10)
        let lastSession = date(2025, 3, 2, hour: 10)
        let distantNow = date(2026, 11, 27, hour: 12)

        var sessions: [WearSession] = []
        for dayOffset in 0...60 {
            let s = cal.date(byAdding: .day, value: dayOffset, to: start)!
            sessions.append(WearSession(start: s, minutes: 60, averageDecibels: 64, peakDecibels: 74, isEstimated: false))
        }
        // Session starting before cutoff and crossing midnight should clamp to careerEndMoment (23:59:59).
        let boundarySession = WearSession(
            start: date(2025, 3, 2, hour: 23),
            minutes: 120,
            averageDecibels: 64,
            peakDecibels: 74,
            isEstimated: false
        )
        // Post-retirement synced sessions must never alter the frozen archive.
        let postWearDay = date(2025, 3, 3, hour: 0)
        let loudPostSession1 = WearSession(start: postWearDay, minutes: 180, averageDecibels: 92, peakDecibels: 98, isEstimated: false)
        let loudPostSession2 = WearSession(start: date(2025, 3, 10, hour: 14), minutes: 600, averageDecibels: 94, peakDecibels: 101, isEstimated: false)

        let combinedSessions = sessions + [boundarySession, loudPostSession1, loudPostSession2]

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

        let retirement = DeviceRetirement(retiredAt: lastSession, reason: .upgraded, farewellNote: "Moved to USB-C", calendar: cal)
        let retiredDossier = DeviceDossier(
            id: "max",
            nickname: "Studio Max",
            symbol: "airpodsmax",
            serial: 1,
            hardware: hardware,
            sessions: combinedSessions,
            otherDevicesDailyMinutes: [:],
            sampleCount: 120,
            lastSynced: distantNow,
            retirement: retirement,
            now: distantNow,
            calendar: cal
        )

        XCTAssertTrue(retiredDossier.isRetired)
        // 61 daily 60m sessions + 59.9833m clamped boundary session = 3719.98m; loud Mar 3/10 sessions excluded.
        XCTAssertEqual(retiredDossier.sessions.count, 62)
        XCTAssertEqual(retiredDossier.lifetimeMinutes, 61 * 60 + 59.983333, accuracy: 0.05)
        XCTAssertEqual(retiredDossier.averageDecibels, 64, accuracy: 0.05)
        XCTAssertEqual(retiredDossier.historyDays, 61)
        XCTAssertGreaterThan(activeDossier.historyDays, 600)
        XCTAssertEqual(retiredDossier.stats(.all).dailyAverage, retiredDossier.lifetimeMinutes / 61, accuracy: 0.5)
        XCTAssertGreaterThan(retiredDossier.stats(.all).dailyAverage, activeDossier.stats(.all).dailyAverage * 5)

        XCTAssertEqual(retiredDossier.liveFirstWearDate, start)
        XCTAssertEqual(retiredDossier.liveLastWearStartDate, loudPostSession2.start)
        XCTAssertEqual(retiredDossier.liveLastWearDate, loudPostSession2.end)

        // Card snapshot reflects frozen stats even if live card gained post-retirement sessions.
        var liveCard = SampleCards.all[1]
        liveCard.lifetimeMinutes = 10_000
        liveCard.sessions = 999
        let frozenCard = retiredDossier.cardSnapshot(from: liveCard)
        XCTAssertEqual(frozenCard.lifetimeMinutes, retiredDossier.lifetimeMinutes, accuracy: 0.01)
        XCTAssertEqual(frozenCard.sessions, 62)
        XCTAssertEqual(frozenCard.averageDecibels, 64, accuracy: 0.5)
        XCTAssertEqual(frozenCard.rarity, retiredDossier.rarity)

        XCTAssertFalse(retiredDossier.milestones.contains { $0.kind == .upcoming })
        XCTAssertTrue(retiredDossier.milestones.contains { $0.kind == .retired && $0.title == "Retired to Vault" })
        XCTAssertTrue(activeAtLastSession.milestones.contains { $0.kind == .upcoming })

        // Post-retirement detection still sees liveLastWearDate.
        let store = DeviceLifecycleStore(defaults: UserDefaults(suiteName: "FreezeCheck.\(UUID().uuidString)")!)
        store.saveRetirement(retirement, for: liveCard)
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: liveCard, lastWear: retiredDossier.liveLastWearDate))

        // Traveling to a different caller timezone preserves the archival date, cutoff, and metrics.
        var shanghaiCal = Calendar(identifier: .gregorian)
        shanghaiCal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var laCal = Calendar(identifier: .gregorian)
        laCal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let shanghaiRet = DeviceRetirement(
            retiredDay: DeviceRetirement.CalendarDay(year: 2025, month: 3, day: 2),
            timeZoneIdentifier: "Asia/Shanghai",
            reason: .upgraded,
            farewellNote: ""
        )
        let shanghaiAtCut = shanghaiCal.date(from: DateComponents(year: 2025, month: 3, day: 2, hour: 22))!
        let shanghaiAfter = shanghaiCal.date(from: DateComponents(year: 2025, month: 3, day: 3, hour: 0, minute: 15))!
        let tzSessions = [
            WearSession(start: shanghaiCal.date(from: DateComponents(year: 2025, month: 3, day: 1, hour: 12))!, minutes: 45, averageDecibels: 62, peakDecibels: 70, isEstimated: false),
            WearSession(start: shanghaiAtCut, minutes: 30, averageDecibels: 62, peakDecibels: 70, isEstimated: false),
            WearSession(start: shanghaiAfter, minutes: 120, averageDecibels: 85, peakDecibels: 92, isEstimated: false),
        ]
        let dossierInLA = DeviceDossier(
            id: "max", nickname: "Studio Max", symbol: "airpodsmax", serial: 1, hardware: hardware,
            sessions: tzSessions, otherDevicesDailyMinutes: [:], sampleCount: 3,
            lastSynced: distantNow, retirement: shanghaiRet, now: distantNow, calendar: laCal
        )
        XCTAssertEqual(shanghaiRet.formattedRetiredDate, "2025.03.02")
        XCTAssertEqual(dossierInLA.lifetimeMinutes, 75, accuracy: 0.01)
        XCTAssertEqual(dossierInLA.sessions.count, 2)
        let retiredMilestone = dossierInLA.milestones.first { $0.kind == .retired }
        XCTAssertEqual(retiredMilestone.map { DateText.dotted($0.date, calendar: dossierInLA.calendar) }, "2025.03.02")
    }

    @MainActor
    func testWidgetSnapshotExcludesRetiredCardsFromShelfWhilePreservingLifetimeAndWeeklyBreakdown() {
        let cal = utcCalendar
        let now = date(2026, 11, 20, hour: 15)
        let activeDev = DeviceDescriptor(name: "Pocket Pro", manufacturer: "Apple Inc.", model: "0x2024", localIdentifier: "active-pro")
        let retiredDev = DeviceDescriptor(name: "Old Max", manufacturer: "Apple Inc.", model: "0x200A", localIdentifier: "old-max")
        let thirdPartyDev = DeviceDescriptor(name: "Desk Bose", manufacturer: "Bose", model: "QC Ultra", localIdentifier: "desk-bose")

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-2400), decibels: 62, device: activeDev),
            RawListeningSample(start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-4800), decibels: 66, device: retiredDev),
            RawListeningSample(start: cal.date(byAdding: .day, value: -10, to: now)!, end: cal.date(byAdding: .day, value: -10, to: now)!.addingTimeInterval(3600), decibels: 65, device: retiredDev),
            RawListeningSample(start: now.addingTimeInterval(-10800), end: now.addingTimeInterval(-9900), decibels: 64, device: thirdPartyDev),
        ], now: now, calendar: cal)

        let snapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let cards = snapshot.cards(now: now, calendar: cal)
        XCTAssertEqual(cards.count, 2)

        let suiteName = "WidgetVaultTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DeviceLifecycleStore(defaults: defaults)
        let maxCard = cards.first { $0.modelKey == .airpodsMax }!
        store.retire(maxCard, at: now, reason: .upgraded, farewellNote: "", calendar: cal)

        let summary = snapshot.combinedHomeSummary(now: now, calendar: cal)!
        let widgetSnapshot = WidgetSnapshot.forApp(
            summary: summary,
            allCards: cards,
            lifecycleStore: store,
            isSample: false,
            listening: snapshot,
            now: now,
            calendar: cal
        )

        XCTAssertEqual(widgetSnapshot.cards.count, 1)
        XCTAssertEqual(widgetSnapshot.cards.first?.model, "AirPods Pro 2 · USB-C")
        XCTAssertEqual(widgetSnapshot.today.minutes, 75, accuracy: 0.01)
        XCTAssertEqual(widgetSnapshot.week.minutes, 75, accuracy: 0.01)
        XCTAssertEqual(widgetSnapshot.resolvedLifetimeMinutes, 135, accuracy: 0.01)
        XCTAssertEqual(widgetSnapshot.resolvedWeeklyBreakdown.map(\.model), [
            "AirPods Max · Lightning",
            "AirPods Pro 2 · USB-C",
            "Bose headphones"
        ])
        let linksByModel = Dictionary(uniqueKeysWithValues: widgetSnapshot.resolvedWeeklyBreakdown.map { ($0.model, $0.deepLink) })
        XCTAssertEqual(linksByModel["AirPods Pro 2 · USB-C"], EarprintLink.card(cards.first { $0.modelKey == .airpodsPro }!.id))
        XCTAssertEqual(linksByModel["AirPods Max · Lightning"], EarprintLink.card(maxCard.id))
        XCTAssertEqual(linksByModel["Bose headphones"], EarprintLink.rings)
    }

    @MainActor
    func testMidnightAdjacentSamplesIsolateEnergyAndDetectPostRetirementWear() {
        let cal = utcCalendar
        let maxDev = DeviceDescriptor(name: "Studio Max", manufacturer: "Apple Inc.", model: "0x200A", localIdentifier: "midnight-max")
        let retireDayNoon = date(2026, 9, 2, hour: 12)
        let morningStart = date(2026, 9, 2, hour: 10)
        let morningEnd = morningStart.addingTimeInterval(1800)
        let preMidnightStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23, minute: 59, second: 0))!
        let preMidnightEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23, minute: 59, second: 59))!
        let postMidnightStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 0, minute: 0, second: 30))!
        let postMidnightEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 0, minute: 4, second: 30))!
        let now = date(2026, 9, 3, hour: 12)

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: morningStart, end: morningEnd, decibels: 60, device: maxDev),
            RawListeningSample(start: preMidnightStart, end: preMidnightEnd, decibels: 60, device: maxDev),
            RawListeningSample(start: postMidnightStart, end: postMidnightEnd, decibels: 90, device: maxDev),
        ], now: now, calendar: cal)

        let snapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let cards = snapshot.cards(now: now, calendar: cal)
        let card = cards[0]

        let defaults = UserDefaults(suiteName: "MidnightEnergyTests.\(UUID().uuidString)")!
        let store = DeviceLifecycleStore(defaults: defaults)
        store.retire(card, at: retireDayNoon, reason: .upgraded, farewellNote: "", calendar: cal)
        let retirement = store.retirement(for: card)!

        let dossier = snapshot.dossier(forCardID: card.id, retirement: retirement, now: now, calendar: cal)!
        XCTAssertEqual(dossier.lifetimeMinutes, 1859.0 / 60, accuracy: 0.02)
        XCTAssertEqual(dossier.averageDecibels, 60.0, accuracy: 0.05)
        XCTAssertEqual(card.lastWearStartDate, postMidnightStart)
        XCTAssertEqual(card.lastWearDate, postMidnightEnd)
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWearEnd: card.lastWearDate, lastWearStart: card.lastWearStartDate))

        // Sample ending at exact midnight does not falsely trigger post-retirement activity.
        let boundaryEnd = date(2026, 9, 3, hour: 0)
        XCTAssertFalse(store.hasUnacknowledgedPostRetirementActivity(
            for: card,
            lastWearEnd: boundaryEnd,
            lastWearStart: date(2026, 9, 2, hour: 23)
        ))
    }

    func testSaoPauloDSTCutoffAndBuddhistCalendarStayOnIntendedDay() {
        // Brazil 2018-11-04 sprang forward at midnight (00:00 -> 01:00); cutoff must still be Nov 5 00:00, not 01:00.
        let spTZ = TimeZone(identifier: "America/Sao_Paulo")!
        var spCal = Calendar(identifier: .gregorian)
        spCal.timeZone = spTZ
        let spRetirement = DeviceRetirement(
            retiredDay: DeviceRetirement.CalendarDay(year: 2018, month: 11, day: 4),
            timeZoneIdentifier: "America/Sao_Paulo",
            reason: .other,
            farewellNote: ""
        )
        let cutoffComps = spCal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: spRetirement.careerCutoffEnd)
        XCTAssertEqual(cutoffComps.year, 2018)
        XCTAssertEqual(cutoffComps.month, 11)
        XCTAssertEqual(cutoffComps.day, 5)
        XCTAssertEqual(cutoffComps.hour, 0)
        XCTAssertEqual(cutoffComps.minute, 0)
        XCTAssertEqual(cutoffComps.second, 0)

        var buddhistCal = Calendar(identifier: .buddhist)
        buddhistCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let buddhistRetirement = DeviceRetirement(
            retiredAt: date(2026, 9, 2, hour: 12),
            reason: .upgraded,
            farewellNote: "",
            calendar: buddhistCal
        )
        XCTAssertEqual(buddhistRetirement.retiredDay, DeviceRetirement.CalendarDay(year: 2026, month: 9, day: 2))
        XCTAssertEqual(buddhistRetirement.formattedRetiredDate, "2026.09.02")
    }

    @MainActor
    func testVaultedViewsAndFarewellPosterRenderCleanly() throws {
        let suiteName = "VaultRenderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DeviceLifecycleStore(defaults: defaults)
        let maxCard = SampleCards.all[1]
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = .current
        let sep2Local = localCal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12))!
        let retirement = DeviceRetirement(
            retiredAt: sep2Local,
            reason: .upgraded,
            farewellNote: "Three winters & 40 flights",
            calendar: localCal
        )
        store.saveRetirement(retirement, for: maxCard)

        let retiredDossier = DeviceDossier.sample(for: maxCard, retirement: retirement, now: DossierSample.referenceNow)
        let color = DeviceColorOption.defaultOption(for: maxCard.modelKey)

        var hiddenFirstWearOptions = DossierShareOptions.default
        hiddenFirstWearOptions.simple.showFirstWear = false
        let hiddenFirstWearPages = DossierShareRenderer.renderPages(
            card: maxCard,
            dossier: retiredDossier,
            period: .all,
            color: color,
            isSampleData: true,
            format: .simple,
            options: hiddenFirstWearOptions,
            scheme: .dark
        )
        XCTAssertEqual(hiddenFirstWearPages.count, 1)
        XCTAssertGreaterThan(hiddenFirstWearPages[0].pngData.count, 10_000)

        var hiddenLongOptions = DossierShareOptions.default
        hiddenLongOptions.long.showFirstWear = false
        let hiddenLongPages = DossierShareRenderer.renderPages(
            card: maxCard,
            dossier: retiredDossier,
            period: .all,
            color: color,
            isSampleData: true,
            format: .long,
            options: hiddenLongOptions,
            scheme: .dark
        )
        XCTAssertEqual(hiddenLongPages.count, 4)

        var hiddenMilestonesOnlyOptions = DossierShareOptions.default
        hiddenMilestonesOnlyOptions.long.showFirstWear = false
        hiddenMilestonesOnlyOptions.long.includeCoverPage = false
        hiddenMilestonesOnlyOptions.long.includeRhythmPage = false
        hiddenMilestonesOnlyOptions.long.includeHabitsPage = false
        hiddenMilestonesOnlyOptions.long.showCertificate = false
        hiddenMilestonesOnlyOptions.long.showMilestones = true
        let hiddenMilestonesOnlyPages = DossierShareRenderer.renderPages(
            card: maxCard,
            dossier: retiredDossier,
            period: .all,
            color: color,
            isSampleData: true,
            format: .long,
            options: hiddenMilestonesOnlyOptions,
            scheme: .dark
        )
        XCTAssertEqual(hiddenMilestonesOnlyPages.count, 1)
        XCTAssertGreaterThan(hiddenMilestonesOnlyPages[0].pngData.count, 10_000)

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
                    try hiddenFirstWearPages[0].pngData.write(to: dirURL.appendingPathComponent("farewell-poster-no-firstwear.png"))
                    try hiddenLongPages[1].pngData.write(to: dirURL.appendingPathComponent("farewell-long-rhythm-no-firstwear.png"))
                    try hiddenMilestonesOnlyPages[0].pngData.write(to: dirURL.appendingPathComponent("farewell-long-cert-no-firstwear.png"))

                    let dossierView = DeviceDossierView(card: maxCard, dossier: retiredDossier, isSampleData: true)
                        .environment(store)
                        .environment(DeviceColorStore(defaults: defaults))
                        .preferredColorScheme(.dark)
                    let dossierImg = renderHosting(dossierView, size: CGSize(width: 393, height: 960))
                    if let dData = dossierImg.pngData() {
                        try dData.write(to: dirURL.appendingPathComponent("dossier-vault-dark.png"))
                    }

                    let dossierAx3Img = renderHosting(
                        dossierView.environment(\.dynamicTypeSize, .accessibility3),
                        size: CGSize(width: 393, height: 1120)
                    )
                    if let dAx3Data = dossierAx3Img.pngData() {
                        try dAx3Data.write(to: dirURL.appendingPathComponent("dossier-vault-ax3.png"))
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

                    let sheetAx3Img = renderHosting(
                        sheet.environment(\.dynamicTypeSize, .accessibility3),
                        size: CGSize(width: 393, height: 1080)
                    )
                    if let sAx3Data = sheetAx3Img.pngData() {
                        try sAx3Data.write(to: dirURL.appendingPathComponent("retire-sheet-ax3.png"))
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
