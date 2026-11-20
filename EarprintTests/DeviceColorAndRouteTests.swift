import RealityKit
import XCTest
@testable import Earprint

final class DeviceColorAndRouteTests: XCTestCase {
    func testOnlyMultiColorAppleAndBeatsDevicesExposeColors() {
        XCTAssertEqual(DeviceColorOption.options(for: .airpodsMax).count, 10)
        XCTAssertEqual(DeviceColorOption.options(for: .beatsEarbuds).count, 6)
        XCTAssertEqual(DeviceColorOption.options(for: .beatsEarhook).count, 6)
        XCTAssertEqual(DeviceColorOption.options(for: .beatsOverEar).count, 4)

        // Single-color white AirPods models expose no color selector.
        XCTAssertTrue(DeviceColorOption.options(for: .airpodsPro).isEmpty)
        XCTAssertTrue(DeviceColorOption.options(for: .airpods).isEmpty)
        XCTAssertTrue(DeviceColorOption.options(for: .airpods3).isEmpty)
        XCTAssertTrue(DeviceColorOption.options(for: .airpods4).isEmpty)
    }

    @MainActor
    func testDeviceColorStorePersistsPerCardSelection() {
        let suiteName = "DeviceColorStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let maxCard = SampleCards.all.first { $0.modelKey == .airpodsMax }!
        let proCard = SampleCards.all.first { $0.modelKey == .airpodsPro }!
        let orange = DeviceColorOption.airPodsMaxFinishes.first { $0.id == "apm.orange" }!

        let store1 = DeviceColorStore(defaults: defaults)
        XCTAssertNil(store1.selectedColor(for: proCard))
        XCTAssertEqual(store1.selectedColor(for: maxCard)?.id, "apm.spaceGray")

        store1.select(orange, for: maxCard)
        XCTAssertEqual(store1.selectedColor(for: maxCard)?.id, "apm.orange")

        let store2 = DeviceColorStore(defaults: defaults)
        XCTAssertEqual(store2.selectedColor(for: maxCard)?.id, "apm.orange")

        var combined = HeadphoneCard(id: "first", nickname: maxCard.nickname, model: maxCard.model,
                                     symbol: maxCard.symbol, lifetimeMinutes: maxCard.lifetimeMinutes,
                                     sessions: maxCard.sessions, longestMinutes: maxCard.longestMinutes,
                                     averageDecibels: maxCard.averageDecibels, firstMet: maxCard.firstMet,
                                     lastUsed: maxCard.lastUsed, serial: maxCard.serial, grid: maxCard.grid,
                                     modelKey: .airpodsMax, aliasIDs: [maxCard.id])
        XCTAssertEqual(store2.selectedColor(for: combined)?.id, "apm.orange")
        let blue = DeviceColorOption.airPodsMaxFinishes.first { $0.id == "apm.blue" }!
        store2.select(blue, for: combined)
        XCTAssertEqual(store2.selectedColor(for: combined)?.id, "apm.blue")
        combined.aliasIDs = []
        XCTAssertEqual(store2.selectedColor(for: combined)?.id, "apm.blue")
    }

    func testActiveAudioRouteMatchingNormalizesApostrophesAndCase() {
        XCTAssertTrue(ActiveAudioRouteMonitor.matches(
            cardNickname: "🧸's AirPods Pro",
            cardModel: "AirPods Pro 2 · USB-C",
            activeOutputNames: ["🧸’s AirPods Pro"]
        ))
        XCTAssertTrue(ActiveAudioRouteMonitor.matches(
            cardNickname: "Studio Max",
            cardModel: "AirPods Max",
            activeOutputNames: ["  studio max "]
        ))
        XCTAssertFalse(ActiveAudioRouteMonitor.matches(
            cardNickname: "Gym buds",
            cardModel: "Beats Fit Pro",
            activeOutputNames: ["🧸’s AirPods Pro"]
        ))
    }

    func testCardDeckNavigationBoundsAndNeighbors() {
        let cards = SampleCards.all
        XCTAssertEqual(cards.count, 3)

        XCTAssertNil(CardDeckNavigation.neighbor(of: cards[0], in: cards, step: -1))
        XCTAssertEqual(CardDeckNavigation.neighbor(of: cards[0], in: cards, step: 1)?.id, cards[1].id)
        XCTAssertEqual(CardDeckNavigation.neighbor(of: cards[1], in: cards, step: -1)?.id, cards[0].id)
        XCTAssertEqual(CardDeckNavigation.neighbor(of: cards[1], in: cards, step: 1)?.id, cards[2].id)
        XCTAssertNil(CardDeckNavigation.neighbor(of: cards[2], in: cards, step: 1))
        XCTAssertNil(CardDeckNavigation.neighbor(of: cards[0], in: [cards[0]], step: 1))
    }

    func testCardSwipesFollowTheirDirectionAndIgnoreShortOrVerticalDrags() {
        func swipe(_ x: CGFloat, _ y: CGFloat, predictedX: CGFloat) -> CardFlipDirection? {
            CardFlipDirection.swipe(translation: CGSize(width: x, height: y),
                                    predicted: CGSize(width: predictedX, height: y))
        }

        XCTAssertEqual(swipe(-95, 5, predictedX: -100)?.rawValue, -180)
        XCTAssertEqual(swipe(95, -5, predictedX: 100)?.rawValue, 180)
        XCTAssertEqual(swipe(34, 4, predictedX: 140), .right)
        XCTAssertNil(swipe(34, 4, predictedX: -140))
        XCTAssertNil(swipe(17, 0, predictedX: 42))
        XCTAssertNil(swipe(82, 115, predictedX: 135))
    }

    @MainActor
    func testAirPodsMaxFinishKeepsBothCanopyTextures() async throws {
        let standard = try XCTUnwrap(DeviceColorOption.defaultOption(for: .airpodsMax))
        let orange = try XCTUnwrap(DeviceColorOption.airPodsMaxFinishes.first { $0.id == "apm.orange" })
        let max = await HeadphoneModelLoader.load(.overEar, finish: standard.modelFinish, modelKey: .airpodsMax)
        let canopyNames: Set<String> = ["DeFxnmzQHJkzqmx", "DpauuenuPBdCvhC"]

        func canopies(in entity: Entity) -> [PhysicallyBasedMaterial] {
            let materials = (entity as? ModelEntity)?.model?.materials ?? []
            let local = materials.compactMap { material -> PhysicallyBasedMaterial? in
                guard let pbr = material as? PhysicallyBasedMaterial,
                      let name = pbr.name, canopyNames.contains(name) else { return nil }
                return pbr
            }
            return local + entity.children.flatMap { canopies(in: $0) }
        }

        for finish in [standard, orange] {
            HeadphoneModelLoader.applyFinish(finish.modelFinish, to: max, modelKey: .airpodsMax)
            let canopyMaterials = canopies(in: max)
            XCTAssertEqual(Set(canopyMaterials.compactMap(\.name)), canopyNames)
            XCTAssertTrue(canopyMaterials.allSatisfy { $0.baseColor.texture != nil })
        }
    }

    func testCardStackPoseForActiveBehindAndDealtCards() {
        let top = CardStackPose.pose(forDelta: 0)
        XCTAssertEqual(top.offsetX, 0)
        XCTAssertEqual(top.offsetY, 0)
        XCTAssertEqual(top.scale, 1.0)
        XCTAssertEqual(top.rotationDegrees, 0)
        XCTAssertEqual(top.opacity, 1.0)
        XCTAssertEqual(top.dimAmount, 0)

        // Mid-swipe outgoing card stays 100% solid opaque while overlapping the deck (no ghosting).
        let midSwipe = CardStackPose.pose(forDelta: -0.45)
        XCTAssertEqual(midSwipe.opacity, 1.0)
        XCTAssertLessThan(midSwipe.offsetX, -100)

        // Waiting card tucked behind stays opaque and uses dark dimming instead of transparency.
        let behind = CardStackPose.pose(forDelta: 1)
        XCTAssertGreaterThan(behind.offsetX, 0)
        XCTAssertGreaterThan(behind.offsetY, 0)
        XCTAssertLessThan(behind.scale, 1.0)
        XCTAssertGreaterThan(behind.rotationDegrees, 0)
        XCTAssertEqual(behind.opacity, 1.0)
        XCTAssertGreaterThan(behind.dimAmount, 0.1)
        XCTAssertLessThan(behind.zIndex, top.zIndex)

        let dealt = CardStackPose.pose(forDelta: -1)
        XCTAssertLessThan(dealt.offsetX, -200)
        XCTAssertLessThan(dealt.rotationDegrees, -10)
        XCTAssertLessThan(dealt.opacity, 0.1)
        XCTAssertGreaterThan(dealt.zIndex, top.zIndex)
    }

    func testTenTierAchievementProgressionUpTo2000Hours() {
        XCTAssertEqual(
            Rarity.allAscending,
            [.bronze, .silver, .gold, .emerald, .sapphire, .amethyst, .platinum, .diamond, .obsidian, .holo]
        )
        XCTAssertEqual(Rarity(minutes: 0), .bronze)
        XCTAssertEqual(Rarity(minutes: 9.9 * 60), .bronze)
        XCTAssertEqual(Rarity(minutes: 10 * 60), .silver)
        XCTAssertEqual(Rarity(minutes: 35 * 60), .gold)
        XCTAssertEqual(Rarity(minutes: 80 * 60), .emerald)
        XCTAssertEqual(Rarity(minutes: 160 * 60), .sapphire)
        XCTAssertEqual(Rarity(minutes: 300 * 60), .amethyst)
        XCTAssertEqual(Rarity(minutes: 550 * 60), .platinum)
        XCTAssertEqual(Rarity(minutes: 900 * 60), .diamond)
        XCTAssertEqual(Rarity(minutes: 1400 * 60), .obsidian)
        XCTAssertEqual(Rarity(minutes: 1999.9 * 60), .obsidian)
        XCTAssertEqual(Rarity(minutes: 2000 * 60), .holo)
        XCTAssertEqual(Rarity(minutes: 5000 * 60), .holo)

        XCTAssertEqual(Rarity.bronze.nextTier, .silver)
        XCTAssertEqual(Rarity.diamond.nextTier, .obsidian)
        XCTAssertEqual(Rarity.obsidian.nextTier, .holo)
        XCTAssertNil(Rarity.holo.nextTier)
        XCTAssertEqual(Rarity.sapphire.progressToNextTier(minutes: 230 * 60), 0.5, accuracy: 0.001)
        XCTAssertEqual(Rarity.holo.progressToNextTier(minutes: 2500 * 60), 1.0, accuracy: 0.001)

        XCTAssertEqual(Set(Rarity.allCases.map(\.title)).count, 10)
        XCTAssertTrue(Rarity.allCases.allSatisfy { !$0.finishLabel.isEmpty })
        XCTAssertEqual(Rarity.obsidian.material, .carbon)
        XCTAssertEqual(Rarity.holo.material, .holo)
    }

    func testMultiDeviceCombinedHomeSummaryAndSingleDeviceSelection() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = utc.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 15))!
        let earlierStart = now.addingTimeInterval(-3600)
        let maxDevice = DeviceDescriptor(name: "Studio Max", manufacturer: "Apple Inc.", model: "0x201F", localIdentifier: "max-1")
        let budsDevice = DeviceDescriptor(name: "AirPods 4", manufacturer: "Apple Inc.", model: "0x201B", localIdentifier: "ap4-1")

        var agg = ListeningAggregate()
        agg.ingest([
            RawListeningSample(start: earlierStart, end: earlierStart.addingTimeInterval(600), decibels: 60, device: maxDevice),
            RawListeningSample(start: earlierStart, end: earlierStart.addingTimeInterval(600), decibels: 70, device: budsDevice),
            RawListeningSample(start: now.addingTimeInterval(-1800), end: now.addingTimeInterval(-600), decibels: 66, device: budsDevice),
        ], now: now, calendar: utc)
        let snapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: utc)
        XCTAssertEqual(snapshot.devices.count, 2)

        let combined = snapshot.combinedHomeSummary(now: now, calendar: utc)
        XCTAssertNotNil(combined)
        XCTAssertEqual(combined?.lifetimeMinutes ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(combined?.weekMinutes ?? 0, 40, accuracy: 0.001)
        // Energy-weighted average across equal 60 dB + 70 dB overlapping 10m + 20m @ 66 dB
        let expectedEnergy = HearingBudget.energy(decibels: 60, seconds: 600)
            + HearingBudget.energy(decibels: 70, seconds: 600)
            + HearingBudget.energy(decibels: 66, seconds: 1200)
        XCTAssertEqual(
            combined?.weeklyBudgetUsed ?? 0,
            HearingBudget.dose(energy: expectedEnergy),
            accuracy: 0.0001
        )

        let onlyMax = snapshot.summary(for: maxDevice.identityKey, now: now, calendar: utc)
        XCTAssertEqual(onlyMax?.lifetimeMinutes ?? 0, 10, accuracy: 0.001)
        let onlyBuds = snapshot.summary(for: budsDevice.identityKey, now: now, calendar: utc)
        XCTAssertEqual(onlyBuds?.lifetimeMinutes ?? 0, 30, accuracy: 0.001)
    }

    func testAirPodsProUsesOpenCaseSnapshotForCollectibleCard() {
        XCTAssertEqual(HeadphoneModelCatalog.byProductID[0x2024]?.key.collectibleArtwork, "CardRenderAirPodsProCase")
        XCTAssertEqual(HeadphoneModelCatalog.byProductID[0x2024]?.key.collectionArtwork, "CardRenderAirPodsPro")
    }

    func testModelGalleryDeduplicatesVariantsAndUsesZeroFakeStats() {
        let entries = ModelGalleryCatalog.allEntries
        let names = entries.map(\.model.marketingName)
        XCTAssertEqual(Set(names).count, names.count, "Model Gallery must not show duplicate model names")

        let airPods4 = entries.first { $0.model.marketingName == "AirPods 4" }
        XCTAssertEqual(airPods4?.productIDs, [0x2019, 0x201C, 0x201E, 0x2020])
        XCTAssertNotNil(entries.first { $0.model.marketingName == "AirPods 4 (ANC)" })

        for entry in entries {
            XCTAssertEqual(entry.card.lifetimeMinutes, 0)
            XCTAssertEqual(entry.card.sessions, 0)
            XCTAssertTrue(entry.card.firstMet.isEmpty)
        }

        // Sample cards include AirPods Pro 2 · USB-C, AirPods Max (generic sample name), Beats Fit Pro.
        let owned = [
            HeadphoneCard(
                id: "test-1", nickname: "My AirPods", model: "AirPods 4 (ANC)", symbol: "airpods.gen4",
                lifetimeMinutes: 600, sessions: 10, longestMinutes: 60, averageDecibels: 62,
                firstMet: "2026.01.01", lastUsed: "Today", serial: 1, grid: ListeningGrid(minutes: [], decibels: []),
                modelKey: .airpods4, kind: .earbuds
            )
        ]
        XCTAssertEqual(ModelGalleryCatalog.unlockedCount(for: owned), 1)
    }
}
