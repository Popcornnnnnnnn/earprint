import XCTest
@testable import Earprint

final class GridBucketingTests: XCTestCase {
    private let airPods = DeviceDescriptor(
        name: "Test AirPods",
        manufacturer: "Apple Inc.",
        model: "0x2024",
        localIdentifier: "GRID-TEST-01"
    )

    private func calendar(identifier: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: identifier)!
        return cal
    }

    private func makeDate(_ cal: Calendar, _ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    func testMidnightCrossingSplitsAcrossTwoDaysAndHours() {
        let cal = calendar(identifier: "UTC")
        let now = makeDate(cal, 2026, 11, 19, 12, 0)
        // 23:40 on Nov 18 -> 00:20 on Nov 19 (40 min total, split 20 + 20 across midnight)
        let sample = RawListeningSample(
            start: makeDate(cal, 2026, 11, 18, 23, 40),
            end: makeDate(cal, 2026, 11, 19, 0, 20),
            decibels: 68,
            device: airPods
        )

        var agg = ListeningAggregate()
        agg.ingest([sample], now: now, calendar: cal)
        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let dev = try! XCTUnwrap(snap.devices.first)

        XCTAssertEqual(dev.activeDays, 2)
        XCTAssertEqual(dev.grid.days, 28)
        // Day 27 is today (Nov 19), Day 26 is yesterday (Nov 18)
        XCTAssertEqual(dev.grid.minutes[26][23], 20, accuracy: 0.001)
        XCTAssertEqual(dev.grid.decibels[26][23], 68, accuracy: 0.001)
        XCTAssertEqual(dev.grid.minutes[27][0], 20, accuracy: 0.001)
        XCTAssertEqual(dev.grid.decibels[27][0], 68, accuracy: 0.001)
        XCTAssertEqual(dev.grid.minutes[26][22], 0, accuracy: 0.001)
        XCTAssertEqual(dev.grid.minutes[27][1], 0, accuracy: 0.001)
    }

    func testSpringForwardDSTSkipsMissingHourAndPreservesDayIndices() {
        // America/New_York springs forward on Sunday 2026-03-08 at 02:00 EST -> 03:00 EDT.
        let cal = calendar(identifier: "America/New_York")
        let now = makeDate(cal, 2026, 3, 10, 12, 0)

        // Start at 01:30 EST on 2026-03-08, run for 60 elapsed minutes -> ends at 03:30 EDT.
        let start = makeDate(cal, 2026, 3, 8, 1, 30)
        let end = start.addingTimeInterval(3600)
        XCTAssertEqual(cal.component(.hour, from: end), 3)

        // Also add a sample the day after (Mar 9 at 09:00 EDT) to verify day index alignment across DST.
        let nextDayStart = makeDate(cal, 2026, 3, 9, 9, 0)
        let nextDayEnd = nextDayStart.addingTimeInterval(1800)

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: start, end: end, decibels: 64, device: airPods),
            RawListeningSample(start: nextDayStart, end: nextDayEnd, decibels: 72, device: airPods),
        ], now: now, calendar: cal)

        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let dev = try! XCTUnwrap(snap.devices.first)

        // Today is Mar 10 -> index 27; Mar 9 -> index 26; Mar 8 (DST day) -> index 25
        XCTAssertEqual(dev.grid.minutes[25][1], 30, accuracy: 0.001)
        XCTAssertEqual(dev.grid.minutes[25][2], 0, accuracy: 0.001)   // Skipped 2 AM hour stays empty
        XCTAssertEqual(dev.grid.minutes[25][3], 30, accuracy: 0.001)
        XCTAssertEqual(dev.grid.minutes[26][9], 30, accuracy: 0.001)
        XCTAssertEqual(dev.grid.decibels[26][9], 72, accuracy: 0.001)
    }

    func testFallBackDSTAccumulatesRepeatedHourWithEnergyAverage() {
        // America/New_York falls back on Sunday 2026-11-01 at 02:00 EDT -> 01:00 EST.
        let cal = calendar(identifier: "America/New_York")
        let now = makeDate(cal, 2026, 11, 2, 12, 0)

        // Anchor unambiguously from 00:00 EDT on 2026-11-01:
        // +1h is 01:00 EDT (first 1 AM), +2h is 01:00 EST (second 1 AM).
        let midnight = cal.startOfDay(for: makeDate(cal, 2026, 11, 1, 12, 0))
        let firstOneAM = midnight.addingTimeInterval(3600)       // 01:00 EDT
        let secondOneAM = midnight.addingTimeInterval(2 * 3600)  // 01:00 EST
        XCTAssertEqual(cal.component(.hour, from: firstOneAM), 1)
        XCTAssertEqual(cal.component(.hour, from: secondOneAM), 1)

        // 30 min at 60 dB during first 1 AM + 30 min at 70 dB during second 1 AM -> 60 min in hour 1 at ~67.4 dB
        let s1 = RawListeningSample(start: firstOneAM, end: firstOneAM.addingTimeInterval(1800), decibels: 60, device: airPods)
        let s2 = RawListeningSample(start: secondOneAM, end: secondOneAM.addingTimeInterval(1800), decibels: 70, device: airPods)

        var agg = ListeningAggregate()
        agg.ingest([s1, s2], now: now, calendar: cal)
        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let dev = try! XCTUnwrap(snap.devices.first)

        // Nov 2 is index 27; Nov 1 (fall-back day) is index 26
        XCTAssertEqual(dev.grid.minutes[26][1], 60, accuracy: 0.001)
        let expectedDb = 10 * log10((pow(10.0, 6.0) + pow(10.0, 7.0)) / 2)
        XCTAssertEqual(dev.grid.decibels[26][1], expectedDb, accuracy: 0.001)
    }

    func testHalfHourOffsetTimeZoneBucketing() {
        // Asia/Kolkata is UTC+5:30; 15-min absolute slots must still align to local hour boundaries.
        let cal = calendar(identifier: "Asia/Kolkata")
        let now = makeDate(cal, 2026, 11, 19, 18, 0)
        // 14:45 IST -> 15:15 IST (15 min in hour 14, 15 min in hour 15)
        let sample = RawListeningSample(
            start: makeDate(cal, 2026, 11, 19, 14, 45),
            end: makeDate(cal, 2026, 11, 19, 15, 15),
            decibels: 62,
            device: airPods
        )

        var agg = ListeningAggregate()
        agg.ingest([sample], now: now, calendar: cal)
        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let dev = try! XCTUnwrap(snap.devices.first)

        XCTAssertEqual(dev.grid.minutes[27][14], 15, accuracy: 0.001)
        XCTAssertEqual(dev.grid.minutes[27][15], 15, accuracy: 0.001)
    }

    func testGridExcludesSamplesOlderThan28DaysAndPrunesOldSlots() {
        let cal = calendar(identifier: "UTC")
        let now = makeDate(cal, 2026, 11, 19, 12, 0)

        let old40Days = RawListeningSample(
            start: makeDate(cal, 2026, 10, 10, 10, 0),
            end: makeDate(cal, 2026, 10, 10, 10, 30),
            decibels: 65,
            device: airPods
        )
        let day28Ago = RawListeningSample(
            start: makeDate(cal, 2026, 10, 22, 10, 0),
            end: makeDate(cal, 2026, 10, 22, 10, 30),
            decibels: 65,
            device: airPods
        )
        let todaySample = RawListeningSample(
            start: makeDate(cal, 2026, 11, 19, 10, 0),
            end: makeDate(cal, 2026, 11, 19, 10, 30),
            decibels: 65,
            device: airPods
        )

        var agg = ListeningAggregate()
        agg.ingest([old40Days, day28Ago, todaySample], now: now, calendar: cal)
        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: cal)
        let dev = try! XCTUnwrap(snap.devices.first)

        // Lifetime includes all 3 samples (90 min)
        XCTAssertEqual(dev.lifetimeSeconds, 90 * 60, accuracy: 0.001)
        // Grid only spans 28 days (Oct 23..Nov 19): todaySample is at index 27, Oct 22 is day -28 so excluded
        XCTAssertEqual(dev.grid.totalMinutes(lastDays: 28), 30, accuracy: 0.001)
        XCTAssertEqual(dev.grid.minutes[27][10], 30, accuracy: 0.001)
        // 40-day-old sample was outside 35-day slot retention so never stored in slots
        XCTAssertEqual(agg.devices[airPods.identityKey]?.slots.count, 4) // 2 slots for Oct 22 + 2 slots for Nov 19
    }
}
