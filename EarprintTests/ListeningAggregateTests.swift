import XCTest
@testable import Earprint

final class ListeningAggregateTests: XCTestCase {
    private let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private let airPods = DeviceDescriptor(
        name: "My AirPods",
        manufacturer: "Apple Inc.",
        model: "0x2024",
        localIdentifier: "AA:BB:CC:DD:EE:01-tacl"
    )

    // MARK: - Session merging

    func testSessionMergingAtAndUnderFiveMinuteGap() {
        var sessions = SessionSet()
        // 10:00-10:10, then 10:15-10:20 (exact 5 min = 300s gap -> merges)
        sessions.insert(start: 0, end: 600, gap: ListeningAggregate.sessionGap)
        sessions.insert(start: 900, end: 1200, gap: ListeningAggregate.sessionGap)
        // 10:22-10:25 (2 min gap -> merges)
        sessions.insert(start: 1320, end: 1500, gap: ListeningAggregate.sessionGap)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.longest, 1500, accuracy: 0.001)
        XCTAssertEqual(sessions.totalSpan, 1500, accuracy: 0.001)
    }

    func testSessionSplittingOverFiveMinuteGap() {
        var sessions = SessionSet()
        // 0..600, then 901..1200 (301s gap > 300s -> splits into 2 sessions)
        sessions.insert(start: 0, end: 600, gap: ListeningAggregate.sessionGap)
        sessions.insert(start: 901, end: 1200, gap: ListeningAggregate.sessionGap)

        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions.longest, 600, accuracy: 0.001)
        XCTAssertEqual(sessions.totalSpan, 899, accuracy: 0.001)
    }

    func testSessionMergingOutOfOrderBridgesExistingSpans() {
        var sessions = SessionSet()
        // Insert first and third sessions separated by 10 minutes
        sessions.insert(start: 0, end: 300, gap: 300)
        sessions.insert(start: 900, end: 1200, gap: 300)
        XCTAssertEqual(sessions.count, 2)

        // Late-arriving middle sample (450..750) is within 150s of both ends -> bridges into 1 session
        sessions.insert(start: 450, end: 750, gap: 300)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.longest, 1200, accuracy: 0.001)
    }

    func testAggregateSessionStatsThroughSnapshot() {
        let now = date(2026, 11, 19, 18, 0)
        let samples = [
            // Session 1: 10:00-10:20 (two clips with 3 min gap = 20 min span)
            RawListeningSample(start: date(2026, 11, 19, 10, 0), end: date(2026, 11, 19, 10, 10), decibels: 65, device: airPods),
            RawListeningSample(start: date(2026, 11, 19, 10, 13), end: date(2026, 11, 19, 10, 20), decibels: 65, device: airPods),
            // Session 2: 11:00-11:40 (40 min gap > 5 min -> separate 40 min session)
            RawListeningSample(start: date(2026, 11, 19, 11, 0), end: date(2026, 11, 19, 11, 40), decibels: 70, device: airPods),
        ]

        var agg = ListeningAggregate()
        agg.ingest(samples, now: now, calendar: utcCalendar)
        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: utcCalendar)

        XCTAssertEqual(snap.devices.count, 1)
        let dev = snap.devices[0]
        XCTAssertEqual(dev.sessionCount, 2)
        XCTAssertEqual(dev.longestSession, 40 * 60, accuracy: 0.001)
        XCTAssertEqual(dev.averageSession, 30 * 60, accuracy: 0.001)
        // Active listening time is 10 + 7 + 40 = 57 min (excludes the 3 min silence inside session 1)
        XCTAssertEqual(dev.lifetimeSeconds, 57 * 60, accuracy: 0.001)
    }

    // MARK: - Energy-averaged dB (Leq)

    func testEnergyAveragedDecibelsEqualDurations() {
        // Equal durations of 60 dB and 70 dB -> 10 * log10((10^6 + 10^7) / 2) ≈ 67.4036 dB (NOT 65 dB)
        let e1 = HearingBudget.energy(decibels: 60, seconds: 600)
        let e2 = HearingBudget.energy(decibels: 70, seconds: 600)
        let leq = HearingBudget.averageDecibels(energy: e1 + e2, seconds: 1200)

        let expected = 10 * log10((pow(10.0, 6.0) + pow(10.0, 7.0)) / 2)
        XCTAssertNotNil(leq)
        XCTAssertEqual(leq!, expected, accuracy: 1e-6)
        XCTAssertGreaterThan(leq!, 67.4)
    }

    func testEnergyAveragedDecibelsWeightedAndEdgeCases() {
        // 10s at 80 dB + 90s at 70 dB -> energy = 10*10^8 + 90*10^7 = 1.9*10^9 over 100s -> 10*log10(1.9e7)
        let e = HearingBudget.energy(decibels: 80, seconds: 10) + HearingBudget.energy(decibels: 70, seconds: 90)
        let leq = HearingBudget.averageDecibels(energy: e, seconds: 100)!
        XCTAssertEqual(leq, 10 * log10(1.9e7), accuracy: 1e-6)

        // Constant level returns the exact same level
        let same = HearingBudget.averageDecibels(energy: HearingBudget.energy(decibels: 63.5, seconds: 123), seconds: 123)!
        XCTAssertEqual(same, 63.5, accuracy: 1e-9)

        // Zero duration or zero energy -> nil
        XCTAssertNil(HearingBudget.averageDecibels(energy: 0, seconds: 60))
        XCTAssertNil(HearingBudget.averageDecibels(energy: 100, seconds: 0))
    }

    func testInvalidAndClippedSamples() {
        let now = date(2026, 11, 19, 18, 0)
        let samples = [
            // Invalid: negative duration
            RawListeningSample(start: date(2026, 11, 19, 12, 0), end: date(2026, 11, 19, 11, 0), decibels: 65, device: airPods),
            // Invalid: NaN dB
            RawListeningSample(start: date(2026, 11, 19, 12, 0), end: date(2026, 11, 19, 12, 10), decibels: .nan, device: airPods),
            // Invalid: out-of-range dB
            RawListeningSample(start: date(2026, 11, 19, 12, 0), end: date(2026, 11, 19, 12, 10), decibels: 180, device: airPods),
            RawListeningSample(start: date(2026, 11, 19, 12, 0), end: date(2026, 11, 19, 12, 10), decibels: -5, device: airPods),
            // Valid but 10 hours long -> clipped to 6 hours
            RawListeningSample(start: date(2026, 11, 19, 1, 0), end: date(2026, 11, 19, 11, 0), decibels: 60, device: airPods),
        ]

        var agg = ListeningAggregate()
        agg.ingest(samples, now: now, calendar: utcCalendar)

        XCTAssertEqual(agg.totalSamples, 5)
        XCTAssertEqual(agg.invalidSamples, 4)
        XCTAssertEqual(agg.clippedSamples, 1)
        XCTAssertEqual(agg.devices[airPods.identityKey]?.seconds ?? 0, 6 * 3600, accuracy: 0.001)
    }

    // MARK: - WHO weekly hearing budget math

    func testWHOWeeklyHearingBudgetReferenceAndExchangeRate() {
        // 80 dB(A) for 40 hours = 100% of weekly budget
        XCTAssertEqual(HearingBudget.dose(decibels: 80, seconds: 40 * 3600), 1.0, accuracy: 1e-9)

        // 80 dB(A) for 20 hours = 50%
        XCTAssertEqual(HearingBudget.dose(decibels: 80, seconds: 20 * 3600), 0.5, accuracy: 1e-9)

        // Equal-energy halving: +10*log10(2) ≈ +3.0103 dB for 20 hours = 100%
        let doubleEnergyDelta = 10 * log10(2.0)
        XCTAssertEqual(HearingBudget.dose(decibels: 80 + doubleEnergyDelta, seconds: 20 * 3600), 1.0, accuracy: 1e-9)

        // +10 dB (90 dB) = 10x sound energy -> 4 hours = 100%
        XCTAssertEqual(HearingBudget.dose(decibels: 90, seconds: 4 * 3600), 1.0, accuracy: 1e-9)

        // Dose is linear / additive in sound energy
        let e1 = HearingBudget.energy(decibels: 80, seconds: 10 * 3600) // 25%
        let e2 = HearingBudget.energy(decibels: 90, seconds: 1 * 3600)  // 25%
        XCTAssertEqual(HearingBudget.dose(energy: e1 + e2), 0.5, accuracy: 1e-9)
    }

    func testWeeklyBudgetOnlyCountsLastSevenLocalDays() {
        let now = date(2026, 11, 19, 18, 0)
        // 10 days ago: 4 hours at 90 dB (would be 100% if counted, but outside 7-day window)
        let oldSample = RawListeningSample(
            start: date(2026, 11, 9, 10, 0),
            end: date(2026, 11, 9, 14, 0),
            decibels: 90,
            device: airPods
        )
        // Today: 2 hours at 90 dB (exactly 50% of WHO weekly budget)
        let recentSample = RawListeningSample(
            start: date(2026, 11, 19, 10, 0),
            end: date(2026, 11, 19, 12, 0),
            decibels: 90,
            device: airPods
        )

        var agg = ListeningAggregate()
        agg.ingest([oldSample, recentSample], now: now, calendar: utcCalendar)
        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: utcCalendar)

        let dev = try! XCTUnwrap(snap.devices.first)
        XCTAssertEqual(dev.weeklyBudget, 0.5, accuracy: 1e-6)
        XCTAssertEqual(dev.weekSeconds, 2 * 3600, accuracy: 0.001)
        XCTAssertEqual(dev.weekDecibels ?? 0, 90, accuracy: 1e-6)
        // Home summary uses the exact budget from the snapshot
        let summary = try! XCTUnwrap(snap.homeSummary(now: now, calendar: utcCalendar))
        XCTAssertEqual(summary.weeklyBudgetUsed, 0.5, accuracy: 1e-6)
    }
}
