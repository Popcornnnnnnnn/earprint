import SwiftUI
import Vision
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

        let liveSnapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let card = liveSnapshot.cards(now: now, calendar: cal)[0]

        let defaults = UserDefaults(suiteName: "MidnightEnergyTests.\(UUID().uuidString)")!
        let store = DeviceLifecycleStore(defaults: defaults)
        store.retire(card, at: retireDayNoon, reason: .upgraded, farewellNote: "", calendar: cal)
        let retirement = store.retirement(for: card)!
        let scopes = DeviceLifecycleStore.persistedCutoffScopes(defaults: defaults)

        var retiredAgg = ListeningAggregate()
        retiredAgg.ingest([
            RawListeningSample(start: morningStart, end: morningEnd, decibels: 60, device: maxDev),
            RawListeningSample(start: preMidnightStart, end: preMidnightEnd, decibels: 60, device: maxDev),
            RawListeningSample(start: postMidnightStart, end: postMidnightEnd, decibels: 90, device: maxDev),
        ], now: now, calendar: cal, cutoffScopes: scopes)
        let snapshot = LibrarySnapshot(aggregate: retiredAgg, now: now, calendar: cal, cutoffScopes: scopes)

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
                    try hiddenLongPages[2].pngData.write(to: dirURL.appendingPathComponent("farewell-long-habits-no-firstwear.png"))
                    try hiddenLongPages[3].pngData.write(to: dirURL.appendingPathComponent("farewell-long-cert-source-no-firstwear.png"))
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
    func testSchemaVersionInvalidatesV2CacheAndNilLastSampleStartDoesNotFalseTrigger() throws {
        XCTAssertGreaterThanOrEqual(ListeningAggregate.schemaVersion, 3)

        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("earprint-v2-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: cacheURL) }
        var stale = ListeningAggregate()
        stale.version = 2
        let cache = AggregateCache(url: cacheURL)
        cache.save(aggregate: stale, anchor: nil)
        XCTAssertNil(cache.load(), "Legacy v2 caches must be invalidated after schemaVersion bump")

        let midnightCutoff = date(2026, 9, 3, hour: 0)
        let dev = DeviceDescriptor(name: "Legacy Max", manufacturer: "Apple Inc.", model: "0x200A", localIdentifier: "legacy-max")
        var acc = DeviceAccumulator(key: dev.identityKey, descriptor: dev, descriptorDate: midnightCutoff)
        acc.sampleCount = 1
        acc.seconds = 1800
        acc.energy = HearingBudget.energy(decibels: 64, seconds: 1800)
        acc.first = midnightCutoff.addingTimeInterval(-1800)
        acc.last = midnightCutoff
        acc.lastSampleStart = nil
        acc.sessions.insert(
            start: midnightCutoff.addingTimeInterval(-1800).timeIntervalSince1970,
            end: midnightCutoff.timeIntervalSince1970,
            gap: ListeningAggregate.sessionGap,
            listeningSeconds: 1800,
            energy: acc.energy,
            peakDecibels: 64
        )
        var agg = ListeningAggregate()
        agg.devices[dev.identityKey] = acc
        let snapshot = LibrarySnapshot(aggregate: agg, now: midnightCutoff, calendar: utcCalendar)
        let card = try XCTUnwrap(snapshot.cards(now: midnightCutoff, calendar: utcCalendar).first)
        XCTAssertNil(card.lastWearStartDate)

        let defaults = UserDefaults(suiteName: "NilSampleStartTests.\(UUID().uuidString)")!
        let store = DeviceLifecycleStore(defaults: defaults)
        store.retire(card, at: date(2026, 9, 2, hour: 12), reason: .other, farewellNote: "", calendar: utcCalendar)

        XCTAssertFalse(
            store.hasUnacknowledgedPostRetirementActivity(for: card, lastWearEnd: midnightCutoff, lastWearStart: nil),
            "Exact midnight end without lastWearStart must not trigger post-retirement reactivation"
        )
        XCTAssertTrue(
            store.hasUnacknowledgedPostRetirementActivity(for: card, lastWearEnd: midnightCutoff.addingTimeInterval(1), lastWearStart: nil)
        )
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: card, lastWear: midnightCutoff))
    }

    @MainActor
    func testCrossTimezoneIngestionAndAliasCombineIsolateSavedRetirementCutoffs() throws {
        var laCal = Calendar(identifier: .gregorian)
        laCal.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let maxDevPrimary = DeviceDescriptor(name: "Studio Max", manufacturer: "Apple Inc.", model: "0x200A", localIdentifier: "la-max-1")
        let maxDevAlias = DeviceDescriptor(name: "Studio Max", manufacturer: "Apple Inc.", model: "0x200A", localIdentifier: "la-max-2")
        let otherDev = DeviceDescriptor(name: "Daily Pro", manufacturer: "Apple Inc.", model: "0x2024", localIdentifier: "la-pro-1")
        let utcRet = DeviceRetirement(
            retiredDay: DeviceRetirement.CalendarDay(year: 2026, month: 9, day: 2),
            timeZoneIdentifier: "UTC",
            reason: .upgraded,
            farewellNote: ""
        )

        let preStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23, minute: 58, second: 0))!
        let preEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23, minute: 59, second: 59))!
        let postStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 0, minute: 1, second: 0))!
        let postEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 0, minute: 5, second: 0))!
        let now = date(2026, 9, 3, hour: 12)

        // Pre-retirement ingestion with empty scopes merges aliases under live 5-min rule,
        // and keeps other pairs unsplit even across UTC/local midnight.
        var preRetired = ListeningAggregate()
        preRetired.ingest([
            RawListeningSample(start: preStart, end: preEnd, decibels: 60, device: maxDevPrimary),
            RawListeningSample(start: postStart, end: postEnd, decibels: 90, device: maxDevAlias),
            RawListeningSample(start: preStart, end: preEnd, decibels: 64, device: otherDev),
            RawListeningSample(start: postStart, end: postEnd, decibels: 64, device: otherDev),
        ], now: now, calendar: laCal, cutoffScopes: [])

        let preSnapshot = LibrarySnapshot(aggregate: preRetired, now: now, calendar: laCal, cutoffScopes: [])
        let liveMaxCard = try XCTUnwrap(preSnapshot.cards(now: now, calendar: laCal).first { $0.modelKey == .airpodsMax })
        // Pure 5-min live session rule merges both before retirement without midnight splitting.
        let preMaxDossier = try XCTUnwrap(preSnapshot.dossier(forCardID: liveMaxCard.id, retirement: nil, now: now, calendar: laCal))
        XCTAssertEqual(preMaxDossier.sessions.count, 1)
        XCTAssertGreaterThan(preMaxDossier.averageDecibels, 80)

        let suite = "CrossTZCutoffTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DeviceLifecycleStore(defaults: defaults)
        store.saveRetirement(utcRet, for: liveMaxCard)
        let scopes = DeviceLifecycleStore.persistedCutoffScopes(defaults: defaults)
        XCTAssertEqual(scopes.count, 1)

        // Even when source accumulators had no crossing (samples arrived on separate aliases),
        // refreshing the snapshot with the new cutoff scopes isolates the merged alias session.
        XCTAssertFalse(preRetired.hasSpanCrossing(scopes: scopes))
        let postSaveSnapshot = LibrarySnapshot(aggregate: preRetired, now: now, calendar: laCal, cutoffScopes: scopes)
        let savedDossier = try XCTUnwrap(postSaveSnapshot.dossier(forCardID: liveMaxCard.id, retirement: utcRet, now: now, calendar: laCal))
        XCTAssertEqual(savedDossier.sessions.count, 1)
        XCTAssertEqual(savedDossier.lifetimeMinutes, 119.0 / 60, accuracy: 0.05)
        XCTAssertEqual(savedDossier.averageDecibels, 60.0, accuracy: 0.05)
        XCTAssertTrue(store.hasUnacknowledgedPostRetirementActivity(for: liveMaxCard, lastWearEnd: liveMaxCard.lastWearDate, lastWearStart: liveMaxCard.lastWearStartDate))

        // Unrelated other pair stays on a single continuous 5-min session even when Max is retired.
        let proCard = try XCTUnwrap(postSaveSnapshot.cards(now: now, calendar: laCal).first { $0.modelKey == .airpodsPro })
        let proDossier = try XCTUnwrap(postSaveSnapshot.dossier(forCardID: proCard.id, retirement: nil, now: now, calendar: laCal))
        XCTAssertEqual(proDossier.sessions.count, 1)

        // Single-device pre-retirement span crossing cutoff is detected by hasSpanCrossing(scopes:)
        // and split cleanly upon isolated re-ingestion.
        var unsplit = ListeningAggregate()
        unsplit.ingest([
            RawListeningSample(start: preStart, end: preEnd, decibels: 60, device: maxDevPrimary),
            RawListeningSample(start: postStart, end: postEnd, decibels: 90, device: maxDevPrimary),
        ], now: now, calendar: laCal)
        XCTAssertTrue(unsplit.hasSpanCrossing(scopes: scopes))
        XCTAssertTrue(unsplit.needsRebuild(for: scopes))

        var isolated = ListeningAggregate()
        isolated.ingest([
            RawListeningSample(start: preStart, end: preEnd, decibels: 60, device: maxDevPrimary),
            RawListeningSample(start: postStart, end: postEnd, decibels: 90, device: maxDevAlias),
        ], now: now, calendar: laCal, cutoffScopes: scopes)
        XCTAssertFalse(isolated.hasSpanCrossing(scopes: scopes))
        XCTAssertFalse(isolated.needsRebuild(for: scopes))
    }

    @MainActor
    func testRetiredDossierWearShareClipsOtherPairAttendanceInRetirementCalendar() throws {
        var laCal = Calendar(identifier: .gregorian)
        laCal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let maxDev = DeviceDescriptor(name: "Studio Max", manufacturer: "Apple Inc.", model: "0x200A", localIdentifier: "share-max")
        let proDev = DeviceDescriptor(name: "Daily Pro", manufacturer: "Apple Inc.", model: "0x2024", localIdentifier: "share-pro")

        let utcRet = DeviceRetirement(
            retiredDay: DeviceRetirement.CalendarDay(year: 2026, month: 9, day: 2),
            timeZoneIdentifier: "UTC",
            reason: .other,
            farewellNote: ""
        )
        let suite = "ShareClipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DeviceLifecycleStore(defaults: defaults)

        // Pair A worn 60m on Sep 2 UTC (12:00Z-13:00Z).
        let maxStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12, minute: 0))!
        let maxEnd = maxStart.addingTimeInterval(3600)
        // Pair B has two samples within 5m gap across UTC cutoff: 23:45Z-23:55Z (10m) and 00:00Z-00:10Z (10m).
        // Live sessions merge into a single 20m session whose WearSession.start is 23:45Z and minutes = 20
        // (so synthetic WearSession.end would have been 00:05Z -> 15m pre-cutoff instead of the true 10m!).
        let proPreStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23, minute: 45))!
        let proPreEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23, minute: 55))!
        let proPostStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 0, minute: 0))!
        let proPostEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 0, minute: 10))!
        let now = date(2026, 9, 4, hour: 12)

        var seedAgg = ListeningAggregate()
        seedAgg.ingest([
            RawListeningSample(start: maxStart, end: maxEnd, decibels: 64, device: maxDev),
        ], now: now, calendar: laCal)
        let maxCard = try XCTUnwrap(LibrarySnapshot(aggregate: seedAgg, now: now, calendar: laCal).cards(now: now, calendar: laCal).first)
        store.saveRetirement(utcRet, for: maxCard)
        let scopes = DeviceLifecycleStore.persistedCutoffScopes(defaults: defaults)

        var unindexedAgg = ListeningAggregate()
        unindexedAgg.ingest([
            RawListeningSample(start: maxStart, end: maxEnd, decibels: 64, device: maxDev),
            RawListeningSample(start: proPreStart, end: proPreEnd, decibels: 64, device: proDev),
            RawListeningSample(start: proPostStart, end: proPostEnd, decibels: 64, device: proDev),
        ], now: now, calendar: laCal)
        XCTAssertTrue(unindexedAgg.needsRebuild(for: scopes))

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: maxStart, end: maxEnd, decibels: 64, device: maxDev),
            RawListeningSample(start: proPreStart, end: proPreEnd, decibels: 64, device: proDev),
            RawListeningSample(start: proPostStart, end: proPostEnd, decibels: 64, device: proDev),
        ], now: now, calendar: laCal, cutoffScopes: scopes)
        XCTAssertFalse(agg.needsRebuild(for: scopes))

        let snapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: laCal, cutoffScopes: scopes)
        let dossier = try XCTUnwrap(snapshot.dossier(forCardID: maxCard.id, retirement: utcRet, now: now, calendar: laCal))

        // True pre-cutoff minutes across both pairs = 60m (Max) + 10m (Pro) = 70m, NOT 75m from merged session duration.
        XCTAssertEqual(dossier.stats(.all).allDevicesMinutes, 70, accuracy: 0.05)
        XCTAssertEqual(dossier.stats(.all).share, 60.0 / 70.0, accuracy: 0.01)

        // Pair B itself still keeps a single continuous live session across midnight (pure 5-min rule).
        let proCard = try XCTUnwrap(snapshot.cards(now: now, calendar: laCal).first { $0.modelKey == .airpodsPro })
        let proDossier = try XCTUnwrap(snapshot.dossier(forCardID: proCard.id, retirement: nil, now: now, calendar: laCal))
        XCTAssertEqual(proDossier.sessions.count, 1)

        // If Pair A is unretired, a backdated/new sync arrives without scopes, and Pair A is re-retired
        // with the same cutoff date, the stale archival bucket must be invalidated so rebuild triggers
        // and any pre-rebuild snapshot falls back to clipped sessions instead of reading stale bucket data.
        agg.ingest([
            RawListeningSample(start: date(2026, 9, 2, hour: 15), end: date(2026, 9, 2, hour: 15).addingTimeInterval(600), decibels: 64, device: proDev),
        ], now: now, calendar: laCal, cutoffScopes: [])
        XCTAssertTrue(agg.needsRebuild(for: scopes))
        let preRebuildSnapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: laCal, cutoffScopes: scopes)
        let preRebuildDossier = try XCTUnwrap(preRebuildSnapshot.dossier(forCardID: maxCard.id, retirement: utcRet, now: now, calendar: laCal))
        XCTAssertGreaterThanOrEqual(preRebuildDossier.stats(.all).allDevicesMinutes, 80)
    }

    @MainActor
    func testActiveDossierAllocatesOtherPairDailySecondsAcrossMidnight() throws {
        let cal = utcCalendar
        let maxDev = DeviceDescriptor(name: "Studio Max", manufacturer: "Apple Inc.", model: "0x200A", localIdentifier: "active-max")
        let proDev = DeviceDescriptor(name: "Daily Pro", manufacturer: "Apple Inc.", model: "0x2024", localIdentifier: "active-pro")
        let day1OtherStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23, minute: 45))!
        let day1OtherEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23, minute: 55))!
        let day2OtherStart = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 0, minute: 0))!
        let day2OtherEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 0, minute: 10))!
        let maxDay1 = date(2026, 9, 2, hour: 12)
        let now = date(2026, 9, 3, hour: 18)

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: maxDay1, end: maxDay1.addingTimeInterval(1800), decibels: 64, device: maxDev),
            RawListeningSample(start: day1OtherStart, end: day1OtherEnd, decibels: 64, device: proDev),
            RawListeningSample(start: day2OtherStart, end: day2OtherEnd, decibels: 64, device: proDev),
        ], now: now, calendar: cal)

        let snapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let maxCard = try XCTUnwrap(snapshot.cards(now: now, calendar: cal).first { $0.modelKey == .airpodsMax })
        let activeDossier = try XCTUnwrap(snapshot.dossier(forCardID: maxCard.id, retirement: nil, now: now, calendar: cal))

        XCTAssertEqual(activeDossier.days.count, 2)
        // Day 1: 30m (Max) + 10m (Pro) = 40m; Day 2: 0m (Max) + 10m (Pro) = 10m.
        XCTAssertEqual(activeDossier.days[0].allDevicesMinutes, 40, accuracy: 0.05)
        XCTAssertEqual(activeDossier.days[1].allDevicesMinutes, 10, accuracy: 0.05)
    }

    @MainActor
    func testSaoPauloDSTBuildDaysAndStatsDoNotDropPostJumpDay() {
        var spCal = Calendar(identifier: .gregorian)
        spCal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let day1Start = spCal.date(from: DateComponents(year: 2018, month: 11, day: 4, hour: 10, minute: 0))!
        let day2Start = spCal.date(from: DateComponents(year: 2018, month: 11, day: 5, hour: 10, minute: 0))!
        let now = spCal.date(from: DateComponents(year: 2018, month: 11, day: 5, hour: 18, minute: 0))!

        let dossier = DeviceDossier(
            id: "sp-max",
            nickname: "Studio Max",
            symbol: "airpodsmax",
            serial: 1,
            hardware: DossierSample.hardware(for: SampleCards.all[1]),
            sessions: [
                WearSession(start: day1Start, minutes: 45, averageDecibels: 65, peakDecibels: 72, isEstimated: false),
                WearSession(start: day2Start, minutes: 30, averageDecibels: 67, peakDecibels: 74, isEstimated: false),
            ],
            otherDevicesDailyMinutes: [:],
            sampleCount: 2,
            lastSynced: now,
            retirement: nil,
            now: now,
            calendar: spCal
        )

        XCTAssertEqual(dossier.days.count, 2)
        XCTAssertEqual(dossier.historyDays, 2)
        XCTAssertEqual(dossier.days[0].minutes, 45, accuracy: 0.01)
        XCTAssertEqual(dossier.days[1].minutes, 30, accuracy: 0.01)
        let allStats = dossier.stats(.all)
        XCTAssertEqual(allStats.spanDays, 2)
        XCTAssertEqual(allStats.totalMinutes, 75, accuracy: 0.01)
        XCTAssertEqual(allStats.buckets.count, 2)
    }

    @MainActor
    func testLongFarewellRedactsSpanAndHistoryDaysAcrossPeriodsAndTimezoneRange() throws {
        let maxCard = SampleCards.all[1]
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = .current
        let sep2Local = localCal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12))!
        let retirement = DeviceRetirement(
            retiredAt: sep2Local,
            reason: .upgraded,
            farewellNote: "Three winters",
            calendar: localCal
        )
        let retiredDossier = DeviceDossier.sample(for: maxCard, retirement: retirement, now: DossierSample.referenceNow)
        let color = DeviceColorOption.defaultOption(for: maxCard.modelKey)

        var hiddenOpts = DossierShareOptions.default
        hiddenOpts.long.showFirstWear = false
        hiddenOpts.long.showSourceMetadata = true
        let hiddenAllPages = DossierShareRenderer.renderPages(
            card: maxCard,
            dossier: retiredDossier,
            period: .all,
            color: color,
            isSampleData: true,
            format: .long,
            options: hiddenOpts,
            scheme: .dark,
            locale: Locale(identifier: "en"),
            scale: 3
        )
        XCTAssertEqual(hiddenAllPages.count, 4)

        let rhythmAllText = try recognizeText(fromPNG: hiddenAllPages[1].pngData, languages: ["en-US"])
        XCTAssertFalse(rhythmAllText.contains("daily avg"), "Hidden DAILY AVG appeared in .all Rhythm OCR: \(rhythmAllText)")
        XCTAssertFalse(rhythmAllText.contains("since minted"), "Hidden 'Since minted' appeared in .all Rhythm OCR: \(rhythmAllText)")
        XCTAssertFalse(rhythmAllText.contains("a day"), "Hidden DayClock per-day average appeared in .all Rhythm OCR: \(rhythmAllText)")

        let habitsAllText = try recognizeText(fromPNG: hiddenAllPages[2].pngData, languages: ["en-US"])
        XCTAssertTrue(habitsAllText.contains("active days"), "Expected active days tile in Habits OCR: \(habitsAllText)")
        XCTAssertFalse(habitsAllText.contains("/ \(retiredDossier.stats(.all).spanDays)"), "Hidden spanDays leaked in Habits OCR: \(habitsAllText)")

        let certAllText = try recognizeText(fromPNG: hiddenAllPages[3].pngData, languages: ["en-US"])
        XCTAssertTrue(certAllText.contains("record days"), "Expected record days label in Certificate OCR: \(certAllText)")
        XCTAssertFalse(certAllText.contains("of \(retiredDossier.historyDays) days"), "Hidden historyDays leaked in Certificate OCR: \(certAllText)")

        // Short-lived pair (first worn 3 days before retirement -> spanDays = 4 in .week) must also redact '/ 4', 'DAILY AVG', and DayClock 'a day' in .week.
        let shortStart = date(2026, 8, 30, hour: 12)
        let shortEndSession = date(2026, 9, 2, hour: 14)
        let utcRet = DeviceRetirement(
            retiredDay: DeviceRetirement.CalendarDay(year: 2026, month: 9, day: 2),
            timeZoneIdentifier: "UTC",
            reason: .other,
            farewellNote: ""
        )
        let shortDossier = DeviceDossier(
            id: "short-max",
            nickname: "Short Max",
            symbol: "airpodsmax",
            serial: 2,
            hardware: DossierSample.hardware(for: maxCard),
            sessions: [
                WearSession(start: shortStart, minutes: 60, averageDecibels: 64, peakDecibels: 70, isEstimated: false),
                WearSession(start: shortEndSession, minutes: 45, averageDecibels: 66, peakDecibels: 72, isEstimated: false),
            ],
            otherDevicesDailyMinutes: [:],
            sampleCount: 2,
            lastSynced: date(2026, 9, 3, hour: 10),
            retirement: utcRet,
            now: date(2026, 9, 3, hour: 10),
            calendar: utcCalendar
        )
        XCTAssertEqual(shortDossier.stats(.week).spanDays, 4)

        let hiddenWeekPages = DossierShareRenderer.renderPages(
            card: maxCard,
            dossier: shortDossier,
            period: .week,
            color: color,
            isSampleData: false,
            format: .long,
            options: hiddenOpts,
            scheme: .dark,
            locale: Locale(identifier: "en"),
            scale: 3
        )
        XCTAssertEqual(hiddenWeekPages.count, 4)
        let weekRhythmText = try recognizeText(fromPNG: hiddenWeekPages[1].pngData, languages: ["en-US"])
        XCTAssertFalse(weekRhythmText.contains("daily avg"), "Hidden DAILY AVG leaked in .week Rhythm OCR: \(weekRhythmText)")
        XCTAssertFalse(weekRhythmText.contains("a day"), "Hidden DayClock per-day average leaked in .week Rhythm OCR: \(weekRhythmText)")
        XCTAssertTrue(weekRhythmText.contains("wears"), "Expected WEARS tile in redacted Rhythm OCR: \(weekRhythmText)")
        let weekHabitsText = try recognizeText(fromPNG: hiddenWeekPages[2].pngData, languages: ["en-US"])
        XCTAssertFalse(weekHabitsText.contains("/ 4"), "Hidden 4-day span leaked in .week Habits OCR: \(weekHabitsText)")

        // Single-wear retired pair must redact the dated "Best day" / "Best month" caption so the first wear date isn't revealed.
        let singleWearDossier = DeviceDossier(
            id: "single-max",
            nickname: "Single Max",
            symbol: "airpodsmax",
            serial: 3,
            hardware: DossierSample.hardware(for: maxCard),
            sessions: [WearSession(start: shortStart, minutes: 60, averageDecibels: 64, peakDecibels: 70, isEstimated: false)],
            otherDevicesDailyMinutes: [:],
            sampleCount: 1,
            lastSynced: date(2026, 9, 3, hour: 10),
            retirement: utcRet,
            now: date(2026, 9, 3, hour: 10),
            calendar: utcCalendar
        )
        let singleWeekPages = DossierShareRenderer.renderPages(
            card: maxCard,
            dossier: singleWearDossier,
            period: .week,
            color: color,
            isSampleData: false,
            format: .long,
            options: hiddenOpts,
            scheme: .dark,
            locale: Locale(identifier: "en"),
            scale: 3
        )
        XCTAssertEqual(singleWeekPages.count, 4)
        let singleWeekRhythmText = try recognizeText(fromPNG: singleWeekPages[1].pngData, languages: ["en-US"])
        XCTAssertFalse(singleWeekRhythmText.contains("aug 30"), "Single-wear Best day caption leaked first-wear date: \(singleWeekRhythmText)")
        let singleWeekCertText = try recognizeText(fromPNG: singleWeekPages[3].pngData, languages: ["en-US"])
        XCTAssertTrue(singleWeekCertText.contains("retired to vault"), "Expected Retired milestone on Certificate: \(singleWeekCertText)")
        XCTAssertFalse(singleWeekCertText.contains("2026.08.30"), "Single-wear Certificate milestones leaked first-wear date: \(singleWeekCertText)")
        XCTAssertFalse(singleWeekCertText.contains("aug 30"), "Single-wear Certificate milestones leaked first-wear date: \(singleWeekCertText)")

        // Localized zh-Hans Rhythm caption + timezone-anchored date range.
        var zhOpts = DossierShareOptions.default
        zhOpts.long.showFirstWear = true
        let zhPages = DossierShareRenderer.renderPages(
            card: maxCard,
            dossier: retiredDossier,
            period: .all,
            color: color,
            isSampleData: true,
            format: .long,
            options: zhOpts,
            scheme: .dark,
            locale: Locale(identifier: "zh-Hans"),
            scale: 3
        )
        XCTAssertEqual(zhPages.count, 4)
        let rhythmZhText = try recognizeText(fromPNG: zhPages[1].pngData, languages: ["zh-Hans", "en-US"])
        XCTAssertFalse(rhythmZhText.contains("wears in"), "Expected localized Rhythm caption, got English: \(rhythmZhText)")
        XCTAssertTrue(rhythmZhText.contains("共聆听"), "Expected Simplified Chinese Rhythm caption: \(rhythmZhText)")

        let utcRange = DateText.range(date(2026, 8, 27, hour: 0), date(2026, 9, 2, hour: 23), calendar: utcCalendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(utcRange, "Aug 27 – Sep 2")
    }

    func testWidgetSnapshotStoreRejectsStaleSnapshotWrites() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-stale-guard-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let newerTime = Date(timeIntervalSince1970: 1_788_436_800.9004)
        let olderSubMillisecond = Date(timeIntervalSince1970: 1_788_436_800.9001)
        let emptyCards: [HeadphoneCard] = []
        let newer = WidgetSnapshot(summary: SampleData.summary, cards: emptyCards, isSample: false, now: newerTime)
        let olderWithCards = WidgetSnapshot(summary: SampleData.summary, cards: SampleCards.all, isSample: false, now: olderSubMillisecond)

        XCTAssertTrue(try WidgetSnapshotStore.save(newer, to: url))
        XCTAssertFalse(try WidgetSnapshotStore.save(olderWithCards, to: url))
        let loaded = try XCTUnwrap(WidgetSnapshotStore.load(from: url))
        XCTAssertEqual(loaded.cards.count, 0)
        XCTAssertEqual(loaded.resolvedGeneratedAtEpoch, newerTime.timeIntervalSince1970, accuracy: 0.00001)

        // Whole-second ISO-8601 snapshots written by earlier app builds still decode cleanly.
        let legacyEncoder = JSONEncoder()
        legacyEncoder.dateEncodingStrategy = .iso8601
        let wholeSecond = WidgetSnapshot(
            summary: SampleData.summary,
            cards: emptyCards,
            isSample: false,
            now: Date(timeIntervalSince1970: 1_788_436_700)
        )
        try legacyEncoder.encode(wholeSecond).write(to: url, options: .atomic)
        let decodedLegacy = try XCTUnwrap(WidgetSnapshotStore.load(from: url))
        XCTAssertEqual(decodedLegacy.generatedAt.timeIntervalSince1970, 1_788_436_700, accuracy: 0.001)
    }

    private func recognizeText(fromPNG data: Data, languages: [String]) throws -> String {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            XCTFail("Expected valid PNG image")
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .lowercased()
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
