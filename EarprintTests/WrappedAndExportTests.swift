import AVFoundation
import ImageIO
import XCTest
@testable import Earprint

final class WrappedAndExportTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func sample(_ start: Date, minutes: Double, decibels: Double = 70, device: DeviceDescriptor? = nil) -> RawListeningSample {
        RawListeningSample(start: start, end: start.addingTimeInterval(minutes * 60), decibels: decibels, device: device)
    }

    func testWrappedFiltersYearsAndComputesPeakAndStreak() {
        let otherPair = DeviceDescriptor(name: "Other pair", localIdentifier: "other")
        var aggregate = ListeningAggregate()
        aggregate.ingest([
            sample(date(2025, 8, 10), minutes: 340, decibels: 100, device: otherPair),
            sample(date(2025, 12, 31, hour: 23, minute: 30), minutes: 60),
            sample(date(2026, 1, 2), minutes: 60),
            sample(date(2026, 1, 3), minutes: 60),
            sample(date(2026, 7, 9), minutes: 120),
            sample(date(2026, 7, 11), minutes: 90),
            sample(date(2027, 1, 1), minutes: 300, decibels: 100, device: otherPair)
        ], now: date(2027, 2, 1), calendar: calendar)

        let wrapped = WrappedAggregator.summarize(aggregate: aggregate, cards: [], calendar: calendar)
        XCTAssertEqual(wrapped.year, 2026)
        XCTAssertEqual(wrapped.totalMinutes, 360, accuracy: 0.01)
        XCTAssertEqual(wrapped.activeDays, 5)
        XCTAssertEqual(wrapped.totalSessions, 5)
        XCTAssertEqual(wrapped.topDeviceName, "Headphones")
        XCTAssertEqual(wrapped.topDeviceMinutes, 360, accuracy: 0.01)
        XCTAssertEqual(wrapped.peakMonth, 7)
        XCTAssertEqual(wrapped.peakMonthMinutes, 210, accuracy: 0.01)
        XCTAssertEqual(wrapped.longestStreakDays, 3)
        XCTAssertEqual(wrapped.averageDecibels, 70, accuracy: 0.01)
        // Jan 1–3 sits in the 2025-12-29..2026-01-04 cross-year week; only the full July week counts.
        XCTAssertEqual(wrapped.whoSafeWeeksCount, 1)
        XCTAssertFalse(wrapped.isThinData)
    }

    func testThinDataUsesMinutesAndActiveDaysIndependently() {
        func summarize(_ minutes: [Double]) -> WrappedSummary {
            var aggregate = ListeningAggregate()
            let samples = minutes.enumerated().map { index, value in
                sample(date(2026, 3, index + 1), minutes: value)
            }
            aggregate.ingest(samples, now: date(2026, 4, 1), calendar: calendar)
            return WrappedAggregator.summarize(aggregate: aggregate, cards: [], calendar: calendar)
        }

        XCTAssertTrue(summarize([]).isThinData)
        XCTAssertTrue(summarize([100, 100, 99]).isThinData)
        XCTAssertTrue(summarize([155, 155]).isThinData)
        XCTAssertFalse(summarize([100, 100, 100]).isThinData)
        XCTAssertEqual(WrappedSummary.sample(year: 2025).year, 2025)
    }

    func testArchiveCSVHasEscapedMultiYearRowsAndJSONRoundTrips() throws {
        var aggregate = ListeningAggregate()
        aggregate.ingest([
            sample(date(2025, 1, 4), minutes: 18),
            sample(date(2026, 2, 12), minutes: 35)
        ], now: date(2026, 2, 14), calendar: calendar)
        var card = SampleCards.all[0]
        card.aliasIDs = [ListeningAggregate.unattributedKey]
        card.nickname = "Studio, \"Demo\"\nPair"

        let csv = try XCTUnwrap(String(data: ArchiveExporter.csv(aggregate: aggregate, cards: [card]), encoding: .utf8))
        XCTAssertTrue(csv.hasPrefix("type,device_id,device_name,device_model,day,start_utc,end_utc,listening_seconds,average_decibels,peak_decibels\r\n"))
        XCTAssertTrue(csv.contains("\"Studio, \"\"Demo\"\"\nPair\""))
        XCTAssertTrue(csv.contains(",20250104,,,1080.0,,\r\n"))
        XCTAssertTrue(csv.contains(",20260212,,,2100.0,,\r\n"))
        XCTAssertEqual(csv.components(separatedBy: "session,unattributed,").count, 3)

        let now = date(2026, 2, 14)
        let encoded = try ArchiveExporter.json(aggregate: aggregate, cards: [card], now: now)
        let decoded = try JSONDecoder().decode(ArchiveExporter.Archive.self, from: encoded)
        XCTAssertEqual(decoded, ArchiveExporter.archive(aggregate: aggregate, cards: [card], now: now))
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.exportedAt, now)
        XCTAssertEqual(decoded.devices.first?.cardID, card.id)
        XCTAssertEqual(decoded.devices.first?.daily, [20250104: 1080, 20260212: 2100])
        XCTAssertEqual(decoded.devices.first?.sessions.count, 2)
    }

    func testArchiveCSVPrefixesSpreadsheetFormulas() throws {
        var aggregate = ListeningAggregate()
        aggregate.ingest([sample(date(2026, 2, 12), minutes: 15)], now: date(2026, 2, 14), calendar: calendar)
        var card = SampleCards.all[0]
        card.aliasIDs = [ListeningAggregate.unattributedKey]
        card.nickname = "=SUM(A1:A2)"
        card.model = "@MODEL"

        let csv = try XCTUnwrap(String(data: ArchiveExporter.csv(aggregate: aggregate, cards: [card]), encoding: .utf8))
        XCTAssertFalse(csv.contains(",=SUM(A1:A2),"))
        XCTAssertFalse(csv.contains(",@MODEL,"))
        XCTAssertTrue(csv.contains("'=SUM(A1:A2)"))
        XCTAssertTrue(csv.contains("'@MODEL"))
    }

    func testWrappedHandlesNonGregorianCalendarAndPartialBoundaryWeeks() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(secondsFromGMT: 0)!
        buddhist.firstWeekday = 2

        var aggregate = ListeningAggregate()
        // 2026-01-01 is a Thursday (partial first week of 2026), 2026-01-05 is Monday (full week)
        aggregate.ingest([
            sample(date(2026, 1, 1), minutes: 30, decibels: 70),
            sample(date(2026, 1, 5), minutes: 60, decibels: 70)
        ], now: date(2026, 2, 1), calendar: calendar)

        let wrapped = WrappedAggregator.summarize(aggregate: aggregate, cards: [], year: 2026, calendar: buddhist)
        XCTAssertEqual(wrapped.year, 2026)
        XCTAssertEqual(wrapped.totalMinutes, 90, accuracy: 0.01)
        XCTAssertEqual(wrapped.activeDays, 2)
        // Only the full week starting 2026-01-05 (not the partial Dec 29..Jan 4 boundary week) qualifies.
        XCTAssertEqual(wrapped.whoSafeWeeksCount, 1)
    }

    @MainActor
    func testSlabCustomizationPersistsSanitizedValuesAndResetsOneCard() throws {
        let suiteName = "EarprintTests.Slab.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SlabCustomizationStore(defaults: defaults)
        XCTAssertEqual(store.customization(for: "new"), CardCustomization())

        store.update(cardID: "first", customization: CardCustomization(
            proFoil: .goldBullion, engravedTitle: "  ABCDEFGHIJKLMNOPQRSTUVWXYZ  ",
            customSerial: "\n 1234567890123456789  "
        ))
        store.update(cardID: "second", customization: CardCustomization(proFoil: .sakuraPearl))
        let reloaded = SlabCustomizationStore(defaults: defaults)
        XCTAssertEqual(reloaded.customization(for: "first"), CardCustomization(
            proFoil: .goldBullion, engravedTitle: "ABCDEFGHIJKLMNOPQRSTUVWX", customSerial: "1234567890123456"
        ))
        reloaded.reset(cardID: "first")
        let reset = SlabCustomizationStore(defaults: defaults)
        XCTAssertEqual(reset.customization(for: "first"), CardCustomization())
        XCTAssertEqual(reset.customization(for: "second").proFoil, .sakuraPearl)
    }

    @MainActor
    func testVideoExporterWritesValidShortMP4AndGIF() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let exporter = CardVideoExporter(duration: 0.35)
        let renderer = SmokeFrameRenderer()
        let mp4 = try await exporter.export(.mp4, renderer: renderer, directory: directory)
        let gif = try await exporter.export(.gif, renderer: renderer, directory: directory)

        XCTAssertEqual(mp4.pathExtension, "mp4")
        XCTAssertGreaterThan(try XCTUnwrap(mp4.resourceValues(forKeys: [.fileSizeKey]).fileSize), 0)
        let asset = AVURLAsset(url: mp4)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let dimensions = try await track.load(.naturalSize)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(dimensions, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(duration.seconds, 0.35, accuracy: 1.0 / 30)

        XCTAssertEqual(gif.pathExtension, "gif")
        let gifSize = try XCTUnwrap(gif.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        XCTAssertGreaterThan(gifSize, 0)
        XCTAssertLessThan(gifSize, 6_000_000)
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(gif as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), 6)
        let frame = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(frame.width, 540)
        XCTAssertEqual(frame.height, 960)
    }
}

@MainActor
private struct SmokeFrameRenderer: CardVideoFrameRenderer {
    func frame(at progress: Double, size: CGSize) async throws -> CGImage {
        try autoreleasepool {
            let context = try XCTUnwrap(CGContext(
                data: nil, width: Int(size.width), height: Int(size.height),
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ))
            context.setFillColor(red: progress, green: 0.25, blue: 0.45, alpha: 1)
            context.fill(CGRect(origin: .zero, size: size))
            return try XCTUnwrap(context.makeImage())
        }
    }
}
