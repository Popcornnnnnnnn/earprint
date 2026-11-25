import XCTest
@testable import Earprint

final class DeviceCatalogTests: XCTestCase {
    private let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    // MARK: - Product ID mapping

    func testAirPodsPro2USBCProductIDMapping() {
        let device = DeviceDescriptor(
            name: "🧸's AirPods Pro",
            manufacturer: "Apple Inc.",
            model: "0x2024",
            localIdentifier: "AA:BB:CC:DD:EE:FF-tacl"
        )
        let info = HeadphoneModelCatalog.resolve(device)
        XCTAssertEqual(info.productID, 0x2024)
        XCTAssertEqual(info.marketingName, "AirPods Pro 2 · USB-C")
        XCTAssertEqual(info.key, .airpodsPro)
        XCTAssertEqual(info.key.kind, .earbuds)
        XCTAssertTrue(info.isApple)
    }

    func testProductIDParsingCaseInsensitiveBareHexAndHardwareFallback() {
        XCTAssertEqual(HeadphoneModelCatalog.productID(from: "0x2024"), 0x2024)
        XCTAssertEqual(HeadphoneModelCatalog.productID(from: "0X200e"), 0x200E)
        XCTAssertEqual(HeadphoneModelCatalog.productID(from: "2024"), 0x2024)
        // Non-Apple bare numbers should NOT be misread as Bluetooth PIDs
        XCTAssertNil(HeadphoneModelCatalog.productID(from: "1234"))
        XCTAssertNil(HeadphoneModelCatalog.productID(from: "2026.1"))

        let viaHardware = DeviceDescriptor(manufacturer: "Apple Inc.", model: nil, hardwareVersion: "0x201F")
        let info = HeadphoneModelCatalog.resolve(viaHardware)
        XCTAssertEqual(info.marketingName, "AirPods Max · USB-C")
        XCTAssertEqual(info.key, .airpodsMax)
        XCTAssertEqual(info.key.kind, .overEar)

        let beats = DeviceDescriptor(manufacturer: "Apple Inc.", model: "0x2012")
        let beatsInfo = HeadphoneModelCatalog.resolve(beats)
        XCTAssertEqual(beatsInfo.marketingName, "Beats Fit Pro")
        XCTAssertEqual(beatsInfo.key, .beatsEarbuds)
        XCTAssertEqual(beatsInfo.key.kind, .sportBuds)
    }

    func testUnknownAppleAndThirdPartyFallbacks() {
        // Unmapped future Apple PID keeps the hex ID visible and guesses shape from nickname
        let futureApple = DeviceDescriptor(name: "Alex's AirPods Max", manufacturer: "Apple Inc.", model: "0x2099")
        let futureInfo = HeadphoneModelCatalog.resolve(futureApple)
        XCTAssertEqual(futureInfo.productID, 0x2099)
        XCTAssertTrue(futureInfo.marketingName.contains("0x2099"))
        XCTAssertEqual(futureInfo.key, .airpodsMax)

        // Third-party over-ear headphone
        let sony = DeviceDescriptor(name: "WH-1000XM5", manufacturer: "Sony", model: "WH-1000XM5")
        let sonyInfo = HeadphoneModelCatalog.resolve(sony)
        XCTAssertEqual(sonyInfo.key, .overEarGeneric)
        XCTAssertEqual(sonyInfo.key.kind, .overEar)
        XCTAssertFalse(sonyInfo.isApple)

        // Third-party in-ear buds
        let buds = DeviceDescriptor(name: "WF-1000XM5", manufacturer: "Sony", model: "WF-1000XM5")
        XCTAssertEqual(HeadphoneModelCatalog.resolve(buds).key, .earbudsGeneric)

        // Nil device falls back cleanly
        let nilInfo = HeadphoneModelCatalog.resolve(nil)
        XCTAssertEqual(nilInfo, HeadphoneModelCatalog.unknownHeadphones)
    }

    // MARK: - Device identity & rename merging

    func testMergesRenamedPhysicalDevicesViaLocalIdentifier() {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let earlier = now.addingTimeInterval(-7200)
        let later = now.addingTimeInterval(-1800)

        // Same physical AirPods Pro renamed by the user; one carries "-tacl" suffix and one doesn't
        let oldDescriptor = DeviceDescriptor(
            name: "AirPods Pro",
            manufacturer: "Apple Inc.",
            model: "0x2024",
            localIdentifier: "AA:BB:CC:DD:EE:01-tacl"
        )
        let newDescriptor = DeviceDescriptor(
            name: "🧸's AirPods Pro",
            manufacturer: "Apple Inc.",
            model: "0x2024",
            localIdentifier: "aa:bb:cc:dd:ee:01"
        )
        XCTAssertEqual(oldDescriptor.identityKey, newDescriptor.identityKey)

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: earlier, end: earlier.addingTimeInterval(600), decibels: 62, device: oldDescriptor),
            RawListeningSample(start: later, end: later.addingTimeInterval(1200), decibels: 66, device: newDescriptor),
        ], now: now, calendar: utcCalendar)

        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: utcCalendar)
        XCTAssertEqual(snap.devices.count, 1)
        let dev = snap.devices[0]
        XCTAssertEqual(dev.nickname, "🧸's AirPods Pro")
        XCTAssertEqual(dev.otherNames, ["AirPods Pro"])
        XCTAssertEqual(dev.lifetimeSeconds, 1800, accuracy: 0.001)
        XCTAssertEqual(dev.sessionCount, 2)
    }

    func testHostDeviceFiltering() {
        XCTAssertTrue(DeviceDescriptor(name: "iPhone", model: "iPhone15,2").isHostDevice)
        XCTAssertTrue(DeviceDescriptor(name: "Apple Watch", model: "Watch6,1").isHostDevice)
        XCTAssertTrue(DeviceDescriptor(name: "iPad Pro", model: "iPad14,3").isHostDevice)
        // Nicknames referencing a Mac or iPhone must NOT be filtered out
        XCTAssertFalse(DeviceDescriptor(name: "MacBook's AirPods", manufacturer: "Apple Inc.", model: "0x2024").isHostDevice)
        XCTAssertFalse(DeviceDescriptor(name: "iPhone's Buds", manufacturer: "Sony", model: "WF-1000XM5").isHostDevice)

        let now = Date(timeIntervalSince1970: 1_795_000_000)
        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(
                start: now.addingTimeInterval(-600),
                end: now,
                decibels: 65,
                device: DeviceDescriptor(name: "iPhone", model: "iPhone17,1")
            )
        ], now: now, calendar: utcCalendar)
        XCTAssertEqual(agg.hostSamples, 1)
        XCTAssertTrue(agg.isEmpty)
    }

    // MARK: - Disk cache round-trip

    func testAggregateCacheRoundTripAndVersionInvalidation() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("earprint-cache-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let device = DeviceDescriptor(name: "Studio Max", manufacturer: "Apple Inc.", model: "0x201F", localIdentifier: "MAX-01")
        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: now.addingTimeInterval(-1200), end: now.addingTimeInterval(-600), decibels: 64, device: device)
        ], now: now, calendar: utcCalendar)

        let cache = AggregateCache(url: tempURL)
        cache.save(aggregate: agg, anchor: nil)

        let loaded = try XCTUnwrap(cache.load())
        XCTAssertEqual(loaded.aggregate.totalSamples, 1)
        XCTAssertEqual(loaded.aggregate.devices[device.identityKey]?.seconds ?? 0, 600, accuracy: 0.001)

        // Schema version mismatch must drop the stale cache cleanly
        var stale = agg
        stale.version = ListeningAggregate.schemaVersion + 1
        cache.save(aggregate: stale, anchor: nil)
        XCTAssertNil(cache.load())
    }

    func testCollectiblesIncludeFallbacksAndKeepDifferentlyNamedDevices() {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let models = [
            DeviceDescriptor(name: "AirPods Pro", manufacturer: "Apple Inc.", model: "0x2027", localIdentifier: "one"),
            DeviceDescriptor(name: "Spare AirPods Pro", manufacturer: "0x004C", model: "0x2027", localIdentifier: "two"),
            DeviceDescriptor(name: "AirPods Pro", manufacturer: "0x009E", model: "0x2027", localIdentifier: "three"),
            DeviceDescriptor(name: "Redmi Buds", manufacturer: "0x0094", model: "0x04", localIdentifier: "four"),
            DeviceDescriptor(name: "AirPods 4", manufacturer: "Apple Inc.", model: "0x201B", localIdentifier: "five"),
        ]
        var aggregate = ListeningAggregate()
        aggregate.ingest(models.map { device in
            RawListeningSample(start: now.addingTimeInterval(-600), end: now, decibels: 62, device: device)
        }, now: now, calendar: utcCalendar)
        let snapshot = LibrarySnapshot(aggregate: aggregate, now: now, calendar: utcCalendar)
        let cards = snapshot.cards(now: now, calendar: utcCalendar)

        XCTAssertEqual(snapshot.devices.count, 5)
        XCTAssertFalse(HeadphoneModelCatalog.resolve(models[2]).isApple)
        XCTAssertEqual(snapshot.lifetimeSeconds, 3000, accuracy: 0.001)
        XCTAssertEqual(Set(cards.map(\.id)), Set(["lid:one", "lid:two", "lid:three", "lid:four", "lid:five"]))
        XCTAssertEqual(cards.first { $0.id == "lid:five" }?.modelKey.collectibleArtwork, "CardRenderAirPods4")
        XCTAssertEqual(cards.first { $0.id == "lid:five" }?.modelAssetName, "AirPods4")
        XCTAssertEqual(cards.first { $0.id == "lid:one" }?.modelAssetName, "AirPodsPro")
        XCTAssertEqual(cards.first { $0.id == "lid:two" }?.modelAssetName, "AirPodsPro")
        for id in ["lid:three", "lid:four"] {
            let card = cards.first { $0.id == id }
            XCTAssertEqual(card?.modelKey, .earbudsGeneric)
            XCTAssertNil(card?.modelKey.collectibleArtwork)
            XCTAssertEqual(card?.modelAssetName, "")
        }

        guard let summary = snapshot.homeSummary(now: now, calendar: utcCalendar) else {
            return XCTFail("Real listening should still produce a summary")
        }
        let widget = WidgetSnapshot(summary: summary, cards: cards, isSample: false, listening: snapshot,
                                    now: now, calendar: utcCalendar)
        XCTAssertEqual(widget.today.minutes, 50, accuracy: 0.001)
        XCTAssertEqual(widget.today.decibels ?? 0, 62, accuracy: 0.001)
        XCTAssertEqual(Set(widget.cards.map(\.id)), Set(cards.map(\.id)))
    }

    func testMatchingAirPodsAccessoryIDsCombineHistoryAndKeepEarlierCardIdentity() throws {
        let now = utcCalendar.startOfDay(for: Date(timeIntervalSince1970: 1_795_000_000)).addingTimeInterval(3600)
        let pro = DeviceDescriptor(name: "Alex’s AirPods", manufacturer: "Apple Inc.", model: "0x2027",
                                   localIdentifier: "first-tacl")
        let proAlias = DeviceDescriptor(name: " ALEX'S AIRPODS ", manufacturer: "0x004C", model: "0x2028",
                                        localIdentifier: "alias")
        let otherGeneration = DeviceDescriptor(name: "Alex’s AirPods", manufacturer: "Apple Inc.", model: "0x2024",
                                               localIdentifier: "other")
        var aggregate = ListeningAggregate()
        aggregate.ingest([
            RawListeningSample(start: now.addingTimeInterval(-900), end: now.addingTimeInterval(-480),
                               decibels: 60, device: pro, source: "Watch"),
            RawListeningSample(start: now.addingTimeInterval(-600), end: now.addingTimeInterval(-300),
                               decibels: 70, device: proAlias, source: "Phone"),
            RawListeningSample(start: now.addingTimeInterval(-400), end: now,
                               decibels: 65, device: otherGeneration),
        ], now: now, calendar: utcCalendar)

        let snapshot = LibrarySnapshot(aggregate: aggregate, now: now, calendar: utcCalendar)
        let combined = try XCTUnwrap(snapshot.devices.first { $0.id == "lid:first" })
        let cards = snapshot.cards(now: now, calendar: utcCalendar)
        let linkedCard = try XCTUnwrap(cards.first { $0.matches(id: "lid:alias") })

        XCTAssertEqual(aggregate.devices.count, 3)
        XCTAssertEqual(snapshot.totalSamples, 3)
        XCTAssertEqual(snapshot.devices.count, 2)
        XCTAssertEqual(snapshot.lifetimeSeconds, 1120, accuracy: 0.001)
        XCTAssertEqual(combined.nickname, "ALEX'S AIRPODS")
        XCTAssertEqual(combined.otherNames, ["Alex’s AirPods"])
        XCTAssertEqual(combined.sources, ["Phone", "Watch"])
        XCTAssertEqual(combined.first, now.addingTimeInterval(-900))
        XCTAssertEqual(combined.last, now.addingTimeInterval(-300))
        XCTAssertEqual(combined.activeDays, 1)
        XCTAssertEqual(combined.sampleCount, 2)
        XCTAssertEqual(combined.sessionCount, 1)
        XCTAssertEqual(combined.longestSession, 600, accuracy: 0.001)
        XCTAssertEqual(combined.weekSeconds, 720, accuracy: 0.001)
        XCTAssertEqual(combined.grid.minutes[27][0], 12, accuracy: 0.001)
        let energy = HearingBudget.energy(decibels: 60, seconds: 420) + HearingBudget.energy(decibels: 70, seconds: 300)
        XCTAssertEqual(combined.weeklyBudget, HearingBudget.dose(energy: energy), accuracy: 0.00001)
        XCTAssertEqual(linkedCard.id, "lid:first")
        XCTAssertEqual(linkedCard.serial, 1)
        XCTAssertEqual(cards.first { $0.id == "lid:other" }?.serial, 3)
    }

    func testAirPods4CaseArtworkIsSpecificToFourthGenerationVariants() {
        let fourthGeneration = [0x2019, 0x201B, 0x201C, 0x201E, 0x2020]
        for id in fourthGeneration {
            XCTAssertEqual(HeadphoneModelCatalog.byProductID[id]?.key.collectionArtwork, "CardRenderAirPodsOpen")
            XCTAssertEqual(HeadphoneModelCatalog.byProductID[id]?.key.collectibleArtwork, "CardRenderAirPods4")
            XCTAssertEqual(HeadphoneModelCatalog.byProductID[id]?.key.collectibleModel, "AirPods4")
        }
        XCTAssertNotNil(Bundle.main.url(forResource: "AirPods4", withExtension: "usdz"))
        XCTAssertEqual(HeadphoneModelCatalog.byProductID[0x2013]?.key.collectibleArtwork, "CardRenderAirPodsOpen")
        XCTAssertEqual(HeadphoneModelCatalog.byProductID[0x2030]?.key.collectibleArtwork, "CardRenderAirPodsOpen")
    }

    #if DEBUG
    func testSimulatorSeederHKSampleRoundTripThroughPipeline() {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let raw = HealthKitSeeder.buildRawSamples(now: now, calendar: utcCalendar)
        XCTAssertGreaterThan(raw.count, 100)

        // Constructs real HKQuantitySample objects with HKDevice + metadata and converts back via HealthIngestor.plain
        let hkSamples = HealthKitSeeder.makeHKSamples(from: raw)
        let roundTripped = hkSamples.map(HealthIngestor.plain)

        var agg = ListeningAggregate()
        agg.ingest(roundTripped, now: now, calendar: utcCalendar)
        let snap = LibrarySnapshot(aggregate: agg, now: now, calendar: utcCalendar)

        // 3 headphones kept, host iPhone samples filtered out
        XCTAssertEqual(snap.devices.count, 3)
        XCTAssertGreaterThan(snap.hostSamples, 0)
        XCTAssertEqual(snap.invalidSamples, 0)

        let cards = snap.cards(now: now, calendar: utcCalendar)
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(cards.first?.model, "AirPods Pro 2 · USB-C")
        XCTAssertEqual(cards.first?.modelKey, .airpodsPro)
        XCTAssertEqual(cards.first?.kind, .earbuds)
        XCTAssertEqual(cards.first { $0.modelKey == .beatsEarbuds }?.modelAssetName, "BeatsBuds")
        // Earlier nickname merged into otherNames via localIdentifier
        XCTAssertEqual(snap.devices.first?.otherNames, ["AirPods Pro"])

        let summary = snap.homeSummary(now: now, calendar: utcCalendar)
        XCTAssertNotNil(summary)
        XCTAssertGreaterThan(summary?.weekMinutes ?? 0, 0)
    }
    #endif
}
