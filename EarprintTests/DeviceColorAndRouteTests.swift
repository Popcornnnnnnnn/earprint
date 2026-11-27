import RealityKit
import SwiftUI
import UIKit
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
        let canopyEntityNames: Set<String> = ["AExPvRSHRbARooZ", "AANWpKMFljrFwQj"]

        func canopies(in entity: Entity) -> [(String, PhysicallyBasedMaterial)] {
            let local: [(String, PhysicallyBasedMaterial)]
            if let modelEntity = entity as? ModelEntity, canopyEntityNames.contains(modelEntity.name),
               let pbr = modelEntity.model?.materials.first as? PhysicallyBasedMaterial {
                local = [(modelEntity.name, pbr)]
            } else {
                local = []
            }
            return local + entity.children.flatMap { canopies(in: $0) }
        }

        for finish in [standard, orange] {
            HeadphoneModelLoader.applyFinish(finish.modelFinish, to: max, modelKey: .airpodsMax)
            let canopyMaterials = canopies(in: max)
            XCTAssertEqual(Set(canopyMaterials.map(\.0)), canopyEntityNames)
            XCTAssertTrue(canopyMaterials.allSatisfy { $0.1.baseColor.texture != nil })
        }
    }

    @MainActor
    func testAirPodsMaxRepeatedColorSwitchesUpdateEarmuffsAndCanopy() async throws {
        let sequenceIDs = ["apm.spaceGray", "apm.orange", "apm.green", "apm.pink"]
        let finishes = try sequenceIDs.map { id in
            try XCTUnwrap(DeviceColorOption.airPodsMaxFinishes.first { $0.id == id })
        }
        let initial = try XCTUnwrap(finishes.first)
        let pink = try XCTUnwrap(finishes.last)
        let model = await HeadphoneModelLoader.load(.overEar, finish: initial.modelFinish, modelKey: .airpodsMax)

        // Apply multiple finishes sequentially on the SAME loaded entity to catch stripped material names.
        for option in finishes.dropFirst() {
            HeadphoneModelLoader.applyFinish(option.modelFinish, to: model, modelKey: .airpodsMax)
        }

        func material(forEntity target: String, in entity: Entity) -> PhysicallyBasedMaterial? {
            if let modelEntity = entity as? ModelEntity, modelEntity.name == target,
               let pbr = modelEntity.model?.materials.first as? PhysicallyBasedMaterial {
                return pbr
            }
            for child in entity.children {
                if let found = material(forEntity: target, in: child) {
                    return found
                }
            }
            return nil
        }

        func sRGBComponents(_ color: UIColor) -> [CGFloat] {
            let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
            let converted = color.cgColor.converted(to: srgb, intent: .defaultIntent, options: nil) ?? color.cgColor
            return converted.components ?? []
        }

        func assertColorMatches(_ actual: UIColor, _ expected: UIColor, label: String) {
            let a = sRGBComponents(actual)
            let e = sRGBComponents(expected)
            XCTAssertGreaterThanOrEqual(a.count, 3, label)
            XCTAssertGreaterThanOrEqual(e.count, 3, label)
            XCTAssertEqual(a[0], e[0], accuracy: 0.06, "\(label) R")
            XCTAssertEqual(a[1], e[1], accuracy: 0.06, "\(label) G")
            XCTAssertEqual(a[2], e[2], accuracy: 0.06, "\(label) B")
        }

        let expectedFinish = pink.modelFinish
        let shell = try XCTUnwrap(material(forEntity: "BNOZVCaFckcMAnz", in: model))
        let outerCushion = try XCTUnwrap(material(forEntity: "LSwgFSweioaiCgt", in: model))
        let rightInnerMesh = try XCTUnwrap(material(forEntity: "QVkyuxLuHiwiZGe", in: model))
        let leftInnerMesh = try XCTUnwrap(material(forEntity: "PNdaALJHbSHKuWS", in: model))
        let headband = try XCTUnwrap(material(forEntity: "WWtYjswGShSaNES", in: model))
        let canopyOuter = try XCTUnwrap(material(forEntity: "AExPvRSHRbARooZ", in: model))
        let canopyInner = try XCTUnwrap(material(forEntity: "AANWpKMFljrFwQj", in: model))

        assertColorMatches(shell.baseColor.tint, expectedFinish.shell, label: "shell")
        assertColorMatches(outerCushion.baseColor.tint, expectedFinish.accent, label: "outerCushion")
        assertColorMatches(rightInnerMesh.baseColor.tint, expectedFinish.cushion, label: "rightInnerMesh")
        assertColorMatches(leftInnerMesh.baseColor.tint, expectedFinish.cushion, label: "leftInnerMesh")
        assertColorMatches(headband.baseColor.tint, expectedFinish.cushion, label: "headband")
        assertColorMatches(canopyOuter.baseColor.tint, expectedFinish.accent, label: "canopyOuter")
        assertColorMatches(canopyInner.baseColor.tint, expectedFinish.accent, label: "canopyInner")
        XCTAssertNotNil(canopyOuter.baseColor.texture)
        XCTAssertNotNil(canopyInner.baseColor.texture)
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

    func testSixTierAchievementProgressionAndLegacyCodableFallback() throws {
        XCTAssertEqual(
            Rarity.allAscending,
            [.bronze, .silver, .sapphire, .platinum, .obsidian, .holo]
        )
        XCTAssertEqual(Rarity(minutes: 0), .bronze)
        XCTAssertEqual(Rarity(minutes: 24.9 * 60), .bronze)
        XCTAssertEqual(Rarity(minutes: 25 * 60), .silver)
        XCTAssertEqual(Rarity(minutes: 120 * 60), .sapphire)
        XCTAssertEqual(Rarity(minutes: 400 * 60), .platinum)
        XCTAssertEqual(Rarity(minutes: 1000 * 60), .obsidian)
        XCTAssertEqual(Rarity(minutes: 1999.9 * 60), .obsidian)
        XCTAssertEqual(Rarity(minutes: 2000 * 60), .holo)
        XCTAssertEqual(Rarity(minutes: 5000 * 60), .holo)

        XCTAssertEqual(Rarity.bronze.nextTier, .silver)
        XCTAssertEqual(Rarity.silver.nextTier, .sapphire)
        XCTAssertEqual(Rarity.sapphire.nextTier, .platinum)
        XCTAssertEqual(Rarity.platinum.nextTier, .obsidian)
        XCTAssertEqual(Rarity.obsidian.nextTier, .holo)
        XCTAssertNil(Rarity.holo.nextTier)
        XCTAssertEqual(Rarity.sapphire.progressToNextTier(minutes: 260 * 60), 0.5, accuracy: 0.001)
        XCTAssertEqual(Rarity.holo.progressToNextTier(minutes: 2500 * 60), 1.0, accuracy: 0.001)

        XCTAssertEqual(Set(Rarity.allCases.map(\.title)).count, 6)
        XCTAssertEqual(Set(Rarity.allCases.map(\.shortName)).count, 6)
        XCTAssertTrue(Rarity.allCases.allSatisfy { !$0.finishLabel.isEmpty })
        XCTAssertTrue(Rarity.allCases.allSatisfy { $0.meshColors.count == 9 && $0.ink == .white })
        XCTAssertEqual(Rarity.holo.baseColors.count, 5)
        XCTAssertGreaterThanOrEqual(Rarity.holo.prismRimColors.count, 6)
        XCTAssertEqual(Rarity.obsidian.material, .carbon)
        XCTAssertEqual(Rarity.holo.material, .holo)

        // Legacy 10-tier raw strings map cleanly to the 6-tier system via Codable.
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(Rarity.self, from: Data(#""GOLD""#.utf8)), .silver)
        XCTAssertEqual(try decoder.decode(Rarity.self, from: Data(#""EMERALD""#.utf8)), .sapphire)
        XCTAssertEqual(try decoder.decode(Rarity.self, from: Data(#""AMETHYST""#.utf8)), .platinum)
        XCTAssertEqual(try decoder.decode(Rarity.self, from: Data(#""DIAMOND""#.utf8)), .obsidian)
        XCTAssertEqual(try decoder.decode(Rarity.self, from: Data(#""UNKNOWN_TIER""#.utf8)), .bronze)
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

    @MainActor
    func testPersistentModelRigSwapsModelsAndClearsWithoutTearingDownScene() async throws {
        let rig = ModelRig()
        let initialRoot = rig.root
        let initialIBL = rig.iblLightEntity
        var readyIDs: [String] = []

        let pro = await HeadphoneModelLoader.load(.earbuds, finish: .glossWhite, modelKey: .airpodsPro)
        rig.installModel(
            pro,
            modelID: "pro",
            finishID: "default",
            studioLighting: nil,
            tintKey: "HOLO",
            onModelReady: { readyIDs.append($0) }
        )
        XCTAssertEqual(rig.spinPivot.children.count, 1)
        XCTAssertEqual(rig.displayedModelID, "pro")
        XCTAssertTrue(rig.spinPivot.isEnabled)

        let orange = try XCTUnwrap(DeviceColorOption.airPodsMaxFinishes.first { $0.id == "apm.orange" })
        let max = await HeadphoneModelLoader.load(.overEar, finish: orange.modelFinish, modelKey: .airpodsMax)
        rig.installModel(
            max,
            modelID: "max",
            finishID: orange.id,
            studioLighting: nil,
            tintKey: "GOLD",
            onModelReady: { readyIDs.append($0) }
        )
        XCTAssertEqual(rig.spinPivot.children.count, 1)
        XCTAssertEqual(rig.displayedModelID, "max")
        XCTAssertIdentical(rig.root, initialRoot)
        XCTAssertIdentical(rig.iblLightEntity, initialIBL)

        rig.clearLoadedModel()
        XCTAssertTrue(rig.spinPivot.children.isEmpty)
        XCTAssertNil(rig.displayedModelID)
        XCTAssertFalse(rig.spinPivot.isEnabled)
    }

    @MainActor
    func testPersistentModelRigConfirmsHiddenAfterTwoClearedFrames() async throws {
        await HeadphoneModelLoader.prewarm(assetName: "AirPodsPro")
        let rig = ModelRig()
        var readyIDs: [String] = []
        var confirmedTokens: [Int] = []

        func sync(isVisible: Bool, hideToken: Int) {
            rig.syncModel(
                modelID: "pro",
                kind: .earbuds,
                finish: .glossWhite,
                finishID: "default",
                modelKey: .airpodsPro,
                assetName: "AirPodsPro",
                modelSize: 0.18,
                tint: [],
                tintKey: "BRONZE",
                tilt: .zero,
                isVisible: isVisible,
                reduceMotion: false,
                hideToken: hideToken,
                onModelReady: { readyIDs.append($0) },
                onHiddenConfirmed: { confirmedTokens.append($0) }
            )
        }

        sync(isVisible: true, hideToken: 0)
        for _ in 0..<200 where rig.displayedModelID != "pro" {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(rig.displayedModelID, "pro")

        // Step 2 GPU warmup frames and 1 visible frame.
        rig.stepFrameForTesting(1 / 60)
        rig.stepFrameForTesting(1 / 60)
        XCTAssertEqual(readyIDs, ["pro"])
        rig.stepFrameForTesting(1 / 60)
        XCTAssertTrue(rig.spinPivot.isEnabled)

        // Requesting a swap hide must disable rendering immediately and confirm after 2 cleared frames.
        sync(isVisible: false, hideToken: 1)
        XCTAssertFalse(rig.spinPivot.isEnabled)
        XCTAssertTrue(confirmedTokens.isEmpty)

        rig.stepFrameForTesting(1 / 60)
        XCTAssertFalse(rig.spinPivot.isEnabled)
        XCTAssertTrue(confirmedTokens.isEmpty)

        rig.stepFrameForTesting(1 / 60)
        XCTAssertFalse(rig.spinPivot.isEnabled)
        XCTAssertEqual(confirmedTokens, [1])
    }

    func testCardDeckNavigationTargetIndexHandlesHalfStopPullbackAndMidFlightCatch() {
        // Half-stop past threshold commits to the next card.
        XCTAssertEqual(
            CardDeckNavigation.targetIndex(
                activeIndex: 0,
                count: 5,
                originPosition: 0,
                currentPosition: 0.36,
                dragDeltaX: -80,
                predictedDeltaX: -80
            ),
            1
        )

        // Dragging past 56pt then pulling back reverses the predicted position and cancels cleanly.
        XCTAssertEqual(
            CardDeckNavigation.targetIndex(
                activeIndex: 0,
                count: 5,
                originPosition: 0,
                currentPosition: 0.32,
                dragDeltaX: -70,
                predictedDeltaX: 10
            ),
            0
        )

        // Catching mid-flight (card 1 settling while position is at 0.55) and pulling back returns to 0.
        XCTAssertEqual(
            CardDeckNavigation.targetIndex(
                activeIndex: 1,
                count: 5,
                originPosition: 0.55,
                currentPosition: 0.25,
                dragDeltaX: 66,
                predictedDeltaX: 66
            ),
            0
        )

        // Catching mid-flight and continuing forward settles on card 1.
        XCTAssertEqual(
            CardDeckNavigation.targetIndex(
                activeIndex: 1,
                count: 5,
                originPosition: 0.55,
                currentPosition: 0.85,
                dragDeltaX: -66,
                predictedDeltaX: -66
            ),
            1
        )

        // Fast short flick after drag-origin baseline subtraction still commits.
        XCTAssertEqual(
            CardDeckNavigation.targetIndex(
                activeIndex: 0,
                count: 5,
                originPosition: 0,
                currentPosition: 0.08,
                dragDeltaX: -15,
                predictedDeltaX: -185
            ),
            1
        )
        XCTAssertEqual(
            CardDeckNavigation.targetIndex(
                activeIndex: 1,
                count: 5,
                originPosition: 1,
                currentPosition: 0.92,
                dragDeltaX: 15,
                predictedDeltaX: 185
            ),
            0
        )
    }

    func testCardDeckNavigationShouldTriggerOverlayReloadRecoversInterruptedHide() {
        XCTAssertTrue(
            CardDeckNavigation.shouldTriggerOverlayReload(
                activeCardID: "pro2",
                overlayCardID: "pro2",
                loadedCardID: nil,
                hasAsset: true
            )
        )
        XCTAssertFalse(
            CardDeckNavigation.shouldTriggerOverlayReload(
                activeCardID: "pro2",
                overlayCardID: "pro2",
                loadedCardID: "pro2",
                hasAsset: true
            )
        )
        XCTAssertFalse(
            CardDeckNavigation.shouldTriggerOverlayReload(
                activeCardID: "max",
                overlayCardID: "pro2",
                loadedCardID: nil,
                hasAsset: true
            )
        )
        XCTAssertFalse(
            CardDeckNavigation.shouldTriggerOverlayReload(
                activeCardID: "beats",
                overlayCardID: "beats",
                loadedCardID: nil,
                hasAsset: false
            )
        )
    }

    func testCardDeckNavigationDragPositionTracksMonotonicallyAndRubberBandsBoundaries() {
        // Steady global-space left drag must advance monotonically without oscillation.
        var previous: CGFloat = 0
        for deltaX in stride(from: CGFloat(-20), through: CGFloat(-220), by: -20) {
            let pos = CardDeckNavigation.dragPosition(origin: 0, activeIndex: 0, count: 4, dragDeltaX: deltaX)
            XCTAssertGreaterThan(pos, previous)
            previous = pos
        }
        XCTAssertEqual(previous, 1.0, accuracy: 0.0001)

        // Holding mid-drag with tiny finger jitter stays tightly clustered (no sign flip / frame strobe).
        let midA = CardDeckNavigation.dragPosition(origin: 1, activeIndex: 1, count: 3, dragDeltaX: -80)
        let midB = CardDeckNavigation.dragPosition(origin: 1, activeIndex: 1, count: 3, dragDeltaX: -81)
        let midC = CardDeckNavigation.dragPosition(origin: 1, activeIndex: 1, count: 3, dragDeltaX: -79)
        XCTAssertEqual(midA, 1 + 80.0 / 220.0, accuracy: 0.0001)
        XCTAssertEqual(midB, midA, accuracy: 0.01)
        XCTAssertEqual(midC, midA, accuracy: 0.01)

        // Deck start and deck end rubber-band at 0.22x resistance.
        XCTAssertEqual(
            CardDeckNavigation.dragPosition(origin: 0, activeIndex: 0, count: 3, dragDeltaX: 110),
            -0.11,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CardDeckNavigation.dragPosition(origin: 2, activeIndex: 2, count: 3, dragDeltaX: -110),
            2.11,
            accuracy: 0.0001
        )

        // Dragging further than one card step rubber-bands gently beyond activeIndex ± 1.
        XCTAssertEqual(
            CardDeckNavigation.dragPosition(origin: 0, activeIndex: 0, count: 5, dragDeltaX: -330),
            1.11,
            accuracy: 0.0001
        )

        // Mid-flight catch between 0 and 1 can drag 1:1 back to 0 or forward to 2.
        XCTAssertEqual(
            CardDeckNavigation.dragPosition(origin: 0.55, activeIndex: 1, count: 5, dragDeltaX: 121),
            0.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CardDeckNavigation.dragPosition(origin: 0.55, activeIndex: 1, count: 5, dragDeltaX: -220),
            1.55,
            accuracy: 0.0001
        )

        // Single-card deck never moves off index 0.
        XCTAssertEqual(
            CardDeckNavigation.dragPosition(origin: 0, activeIndex: 0, count: 1, dragDeltaX: -120),
            0,
            accuracy: 0.0001
        )
    }

    func testCardDeckNavigationShouldCompleteOverlaySwapRejectsDragAndStaleToken() {
        XCTAssertTrue(
            CardDeckNavigation.shouldCompleteOverlaySwap(
                confirmedToken: 3,
                currentHideToken: 3,
                isHidingForSwap: true,
                isDragging: false
            )
        )
        XCTAssertFalse(
            CardDeckNavigation.shouldCompleteOverlaySwap(
                confirmedToken: 3,
                currentHideToken: 3,
                isHidingForSwap: true,
                isDragging: true
            )
        )
        XCTAssertFalse(
            CardDeckNavigation.shouldCompleteOverlaySwap(
                confirmedToken: 2,
                currentHideToken: 3,
                isHidingForSwap: true,
                isDragging: false
            )
        )
        XCTAssertFalse(
            CardDeckNavigation.shouldCompleteOverlaySwap(
                confirmedToken: 3,
                currentHideToken: 3,
                isHidingForSwap: false,
                isDragging: false
            )
        )
    }

    func testCardDeckFlipStateKeysByCardIDAndPreventsIncomingFlipLeakage() {
        var state = CardDeckFlipState()
        state.toggle(cardID: "card-0", direction: .left)
        XCTAssertTrue(state.isShowingBack(for: "card-0"))
        XCTAssertEqual(state.frontFaceAngle(for: "card-0"), -180)
        XCTAssertEqual(state.backFaceAngle(for: "card-0"), -180)

        // Immediately upon switching to card-1 — even BEFORE `.onChange(of: card.id)` calls promoteToActive —
        // card-1 must NEVER inherit card-0's -180° flip angle, and card-0 must retain its back face.
        XCTAssertFalse(state.isShowingBack(for: "card-1"))
        XCTAssertEqual(state.frontFaceAngle(for: "card-1"), 0)
        XCTAssertEqual(state.backFaceAngle(for: "card-1"), 0)
        XCTAssertTrue(state.isShowingBack(for: "card-0"))
        XCTAssertEqual(state.outgoingCardIDs(excluding: "card-1"), ["card-0"])

        // Rapid flip-switch-flip-back: flipping card-1 while card-0 is still outgoing preserves BOTH cards independently.
        state.promoteToActive(cardID: "card-1")
        state.toggle(cardID: "card-1", direction: .left)
        XCTAssertTrue(state.isShowingBack(for: "card-0"))
        XCTAssertTrue(state.isShowingBack(for: "card-1"))
        XCTAssertEqual(state.outgoingCardIDs(excluding: "card-0"), ["card-1"])

        // Catching card-0 mid-flight restores its back face seamlessly without losing card-1's outgoing back face.
        state.promoteToActive(cardID: "card-0")
        XCTAssertTrue(state.isShowingBack(for: "card-0"))
        XCTAssertEqual(state.frontFaceAngle(for: "card-0"), -180)
        XCTAssertTrue(state.isShowingBack(for: "card-1"))

        // Tucked back card dissolves cleanly in two steps: flat front underneath opaque flat back, then fade back to 0.
        state.prepareDissolveBack(cardID: "card-1")
        XCTAssertTrue(state.isDissolvingBack(for: "card-1"))
        XCTAssertTrue(state.isShowingBack(for: "card-1"))
        XCTAssertEqual(state.frontFaceAngle(for: "card-1"), 0)
        XCTAssertEqual(state.backFaceAngle(for: "card-1"), -180)
        XCTAssertEqual(state.backFaceOpacity(for: "card-1"), 1)

        state.fadeOutDissolvingBack(cardID: "card-1")
        XCTAssertEqual(state.backFaceOpacity(for: "card-1"), 0)
        XCTAssertFalse(state.isShowingBack(for: "card-1"))

        // Returning to a card that has already started dissolving lands cleanly face-up.
        state.promoteToActive(cardID: "card-1")
        XCTAssertFalse(state.hasTrackedFlip(for: "card-1"))
        XCTAssertFalse(state.isShowingBack(for: "card-1"))
        XCTAssertEqual(state.frontFaceAngle(for: "card-1"), 0)
    }

    @MainActor
    func testPersistentModelRigReloadsAfterHideTokenCancelsInFlightLoad() async throws {
        await HeadphoneModelLoader.prewarm(assetName: "AirPodsPro")
        let rig = ModelRig()
        var readyIDs: [String] = []
        var confirmedTokens: [Int] = []

        func sync(isVisible: Bool, hideToken: Int) {
            rig.syncModel(
                modelID: "pro",
                kind: .earbuds,
                finish: .glossWhite,
                finishID: "default",
                modelKey: .airpodsPro,
                assetName: "AirPodsPro",
                modelSize: 0.18,
                tint: [],
                tintKey: "BRONZE",
                tilt: .zero,
                isVisible: isVisible,
                reduceMotion: false,
                hideToken: hideToken,
                onModelReady: { readyIDs.append($0) },
                onHiddenConfirmed: { confirmedTokens.append($0) }
            )
        }

        // Start loading "pro", then immediately cancel via hideToken before load completes.
        sync(isVisible: true, hideToken: 0)
        sync(isVisible: false, hideToken: 1)
        rig.stepFrameForTesting(1 / 60)
        rig.stepFrameForTesting(1 / 60)
        XCTAssertEqual(confirmedTokens, [1])
        XCTAssertNil(rig.displayedModelID)

        // Returning to "pro" must restart loading cleanly rather than staying permanently blank.
        sync(isVisible: true, hideToken: 1)
        for _ in 0..<200 where rig.displayedModelID != "pro" {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(rig.displayedModelID, "pro")
    }

    @MainActor
    func testModelRigCancelInteractionResetsStuckDraggingAndZoomWithoutWipingMomentum() {
        let rig = ModelRig()
        rig.dragging = true
        rig.zoom = 1.28
        rig.velocity = SIMD2<Float>(3.5, -1.2)

        rig.cancelInteractionIfNeeded()
        XCTAssertFalse(rig.dragging)
        XCTAssertEqual(rig.zoom, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rig.velocity.x, 3.5, accuracy: 0.0001)
        XCTAssertEqual(rig.velocity.y, -1.2, accuracy: 0.0001)
    }

    func testLibrarySnapshotComputesRealTierAchievedDatesFromDailyHistory() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let day1 = utc.date(from: DateComponents(year: 2025, month: 10, day: 1, hour: 8))!
        let day2 = utc.date(from: DateComponents(year: 2025, month: 10, day: 2, hour: 8))!
        let day3 = utc.date(from: DateComponents(year: 2025, month: 10, day: 3, hour: 8))!
        let now = utc.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 15))!

        let device = DeviceDescriptor(name: "AirPods Pro", manufacturer: "Apple Inc.", model: "0x2024", localIdentifier: "pro-history")
        var agg = ListeningAggregate()
        // Keep each sample <= maxSampleDuration (6h): 12h + 12h + 2h = 26h, crossing 25h on day3,
        // and keep all dates older than the 35-day slot window so lifetime daily history drives dates.
        agg.ingest([
            RawListeningSample(start: day1, end: day1.addingTimeInterval(6 * 3600), decibels: 62, device: device),
            RawListeningSample(start: day1.addingTimeInterval(7 * 3600), end: day1.addingTimeInterval(13 * 3600), decibels: 63, device: device),
            RawListeningSample(start: day2, end: day2.addingTimeInterval(6 * 3600), decibels: 64, device: device),
            RawListeningSample(start: day2.addingTimeInterval(7 * 3600), end: day2.addingTimeInterval(13 * 3600), decibels: 64, device: device),
            RawListeningSample(start: day3, end: day3.addingTimeInterval(2 * 3600), decibels: 65, device: device),
        ], now: now, calendar: utc)

        let snapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: utc)
        XCTAssertEqual(snapshot.devices.count, 1)
        let summary = snapshot.devices[0]
        XCTAssertEqual(summary.tierAchievedDates[.bronze], day1)
        if let silverDate = summary.tierAchievedDates[.silver] {
            XCTAssertTrue(utc.isDate(silverDate, inSameDayAs: day3))
        } else {
            XCTFail("Expected .silver achievement date from lifetime daily history")
        }
        XCTAssertNil(summary.tierAchievedDates[.sapphire])

        let cards = snapshot.cards(now: now, calendar: utc)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].tierAchievedDates[.bronze], summary.tierAchievedDates[.bronze])
        XCTAssertEqual(cards[0].tierAchievedDates[.silver], summary.tierAchievedDates[.silver])
    }

    func testCardTierBinderSummaryMultiDeviceAndSingleDeviceAttribution() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let oct25 = utc.date(from: DateComponents(year: 2025, month: 10, day: 15, hour: 12))!
        let mar26 = utc.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!

        let maxCard = HeadphoneCard(
            id: "max-1",
            nickname: "Desk Max",
            model: "AirPods Max · USB-C",
            symbol: "airpodsmax",
            lifetimeMinutes: 500 * 60, // Platinum (400h+)
            sessions: 120,
            longestMinutes: 180,
            averageDecibels: 64,
            firstMet: "2025.01.01",
            lastUsed: "Today",
            serial: 1,
            grid: ListeningGrid(minutes: [], decibels: []),
            modelKey: .airpodsMax,
            kind: .overEar,
            tierAchievedDates: [.bronze: oct25, .silver: oct25, .sapphire: mar26]
        )
        let proCard = HeadphoneCard(
            id: "pro-1",
            nickname: "Pocket Pro",
            model: "AirPods Pro 2 (ANC)",
            symbol: "airpodspro",
            lifetimeMinutes: 200 * 60, // Sapphire (120h+)
            sessions: 90,
            longestMinutes: 120,
            averageDecibels: 62,
            firstMet: "2024.06.01",
            lastUsed: "Today",
            serial: 2,
            grid: ListeningGrid(minutes: [], decibels: []),
            modelKey: .airpodsPro,
            kind: .earbuds,
            tierAchievedDates: [.bronze: oct25, .silver: mar26, .sapphire: oct25]
        )
        let cards = [maxCard, proCard]

        // All Pairs scope: Sapphire unlocked by both, earliest achiever is proCard (oct25 < mar26).
        let allSapphire = CardTierBinderSummary(cards: cards, selectedCardID: nil, tier: .sapphire)
        XCTAssertTrue(allSapphire.isUnlocked)
        XCTAssertTrue(allSapphire.isCurrent) // proCard currently sits at Sapphire
        XCTAssertEqual(allSapphire.firstAchiever?.id, "pro-1")
        XCTAssertEqual(allSapphire.unlockedCards.count, 2)
        let expectedOct = DateText.shortMonthYear(oct25, calendar: utc, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(
            allSapphire.compactAttribution(calendar: utc, isSingleDevice: false, locale: Locale(identifier: "en_US")),
            "AirPods Pro 2 +1 · \(expectedOct)"
        )

        // Single-device scope: Pocket Pro hasn't unlocked Platinum, and Sapphire shows compact date only.
        let singleSapphire = CardTierBinderSummary(cards: cards, selectedCardID: "pro-1", tier: .sapphire)
        XCTAssertTrue(singleSapphire.isUnlocked)
        XCTAssertEqual(
            singleSapphire.compactAttribution(calendar: utc, isSingleDevice: true, locale: Locale(identifier: "en_US")),
            expectedOct
        )
        let singlePlatinum = CardTierBinderSummary(cards: cards, selectedCardID: "pro-1", tier: .platinum)
        XCTAssertFalse(singlePlatinum.isUnlocked)
        XCTAssertNil(singlePlatinum.firstAchiever)
        XCTAssertNil(singlePlatinum.compactAttribution(calendar: utc, isSingleDevice: true, locale: Locale(identifier: "en_US")))
    }

    @MainActor
    func testModelRigApplyDepthDimModulatesAndRestoresLightIntensity() {
        let rig = ModelRig()
        let keyLight = DirectionalLight()
        keyLight.light.intensity = 3600

        rig.configureLights(key: keyLight, fill: nil, rim: nil)
        rig.applyDepthDim(0.5)
        XCTAssertLessThan(keyLight.light.intensity, 3600)

        // Extreme negative / huge values clamp cleanly and dim <= max clamp.
        rig.applyDepthDim(2.0)
        let maxDimmed = keyLight.light.intensity
        XCTAssertGreaterThan(maxDimmed, 0)
        XCTAssertLessThan(maxDimmed, 3600)

        rig.applyDepthDim(0)
        XCTAssertEqual(keyLight.light.intensity, 3600, accuracy: 1)
    }

    @MainActor
    func testPreviewFirstLaunchResetsInMemoryStateAndTriggersOnboarding() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FirstLaunchPreview.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let cache = AggregateCache(url: dir.appendingPathComponent("agg.json"))
        let library = HeadphoneLibrary(cache: cache)
        await library.previewFirstLaunch(afterDelayMilliseconds: 0)

        XCTAssertNil(library.snapshot)
        XCTAssertEqual(library.state, .idle)
        XCTAssertTrue(library.needsHealthOnboarding)
    }

    func testAppLanguageSystemResolutionFollowsPreferredLanguages() {
        XCTAssertEqual(AppLanguage.systemResolved(preferredLanguages: ["zh-Hans-CN", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.systemResolved(preferredLanguages: ["en-US", "zh-Hans-CN"]), .english)
        XCTAssertEqual(AppLanguage.systemResolved(preferredLanguages: ["ja-JP", "zh-Hant-TW"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.systemResolved(preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.system.locale, AppLanguage.systemResolved().locale)
    }

    func testLibrarySnapshotBuildsRealDeviceDossierFromHealthSessions() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = utc.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 18))!
        let s1 = utc.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10))!
        let s2 = utc.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 14))!

        let pro = DeviceDescriptor(
            name: "Studio Pro",
            manufacturer: "Apple Inc.",
            model: "0x2024",
            hardwareVersion: "1.0",
            firmwareVersion: "7E93",
            localIdentifier: "pro-dossier-id"
        )
        let max = DeviceDescriptor(
            name: "Desk Max",
            manufacturer: "Apple Inc.",
            model: "0x201F",
            localIdentifier: "max-dossier-id"
        )

        var agg = ListeningAggregate()
        agg.ingest([
            // Session 1: two nearby clips (merged within 5 min gap) at 60 dB and 70 dB
            RawListeningSample(start: s1, end: s1.addingTimeInterval(600), decibels: 60, device: pro, source: "com.apple.health.123"),
            RawListeningSample(start: s1.addingTimeInterval(720), end: s1.addingTimeInterval(1320), decibels: 70, device: pro, source: "com.apple.health.123"),
            // Session 2: 4 hours later at 76 dB
            RawListeningSample(start: s2, end: s2.addingTimeInterval(1800), decibels: 76, device: pro, source: "com.apple.health.123"),
            // Competing device on same day so share < 1
            RawListeningSample(start: s2, end: s2.addingTimeInterval(3000), decibels: 64, device: max, source: "com.apple.health.123"),
        ], now: now, calendar: utc)

        let snapshot = LibrarySnapshot(aggregate: agg, now: now, calendar: utc)
        let dossier = try XCTUnwrap(snapshot.dossier(forCardID: pro.identityKey, now: now, calendar: utc))
        XCTAssertEqual(dossier.sessions.count, 2)
        XCTAssertEqual(dossier.lifetimeMinutes, 50, accuracy: 0.01) // 10m + 10m + 30m
        XCTAssertEqual(dossier.hardware.productID, "0x2024")
        XCTAssertEqual(dossier.hardware.firmwareVersion, "7E93")
        XCTAssertEqual(dossier.hardware.sourceName, "Apple Health")
        XCTAssertFalse(dossier.sessions[0].isEstimated)
        XCTAssertEqual(dossier.sessions[0].peakDecibels, 70, accuracy: 0.01)
        XCTAssertEqual(dossier.sessions[1].averageDecibels, 76, accuracy: 0.01)

        let monthStats = dossier.stats(.month)
        XCTAssertLessThan(monthStats.share, 1.0)
        XCTAssertGreaterThan(monthStats.share, 0.4)
    }

    @MainActor
    func testEmptyReleaseSummaryHasZeroMetricsAndRendersEmptyHomeView() {
        let empty = ListeningSummary.empty()
        XCTAssertEqual(empty.lifetimeMinutes, 0)
        XCTAssertEqual(empty.weekMinutes, 0)
        XCTAssertEqual(empty.sessions, 0)
        XCTAssertFalse(empty.has28DayData)
    }

    @MainActor
    func testRenderSeriesFourCardTierPreviewsIfRequested() throws {
        let baseMax = try XCTUnwrap(SampleCards.all.first { $0.modelKey == .airpodsMax })
        let hoursByTier: [Rarity: Double] = [
            .bronze: 12,
            .silver: 68,
            .sapphire: 214,
            .platinum: 642,
            .obsidian: 1380,
            .holo: 2490
        ]
        let tierCards: [(Rarity, HeadphoneCard)] = Rarity.allAscending.enumerated().map { idx, tier in
            var card = baseMax
            card.lifetimeMinutes = (hoursByTier[tier] ?? tier.minimumHours) * 60
            card.serial = idx + 1
            return (tier, card)
        }

        let verticalGrid = VStack(spacing: 14) {
            HStack(spacing: 14) {
                ForEach(tierCards.prefix(3), id: \.0) { _, card in
                    CardFront(card: card)
                        .scaleEffect(0.65)
                        .frame(width: 195, height: 286)
                }
            }
            HStack(spacing: 14) {
                ForEach(tierCards.dropFirst(3), id: \.0) { _, card in
                    CardFront(card: card)
                        .scaleEffect(0.65)
                        .frame(width: 195, height: 286)
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))

        let horizontalStack = VStack(spacing: 14) {
            ForEach(tierCards, id: \.0) { _, card in
                CardHorizontalFront(card: card)
            }
        }
        .padding(16)
        .frame(width: 410)
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))

        let holoCard = tierCards.last!.1
        let retirement = DeviceRetirement(
            retiredDay: DeviceRetirement.CalendarDay(year: 2026, month: 11, day: 20),
            timeZoneIdentifier: "UTC",
            reason: .upgraded,
            farewellNote: ""
        )
        let vaultedHolo = CardFront(card: holoCard, tilt: CGSize(width: 0.25, height: -0.15), retirement: retirement)
            .padding(16)
            .background(Color(red: 0.05, green: 0.06, blue: 0.09))

        let lightHolo = CardFront(card: holoCard, tilt: CGSize(width: -0.25, height: 0.15))
            .padding(16)
            .background(Color(red: 0.96, green: 0.96, blue: 0.98))

        let binder375 = CardTiersView(ownedCards: [holoCard])
            .frame(width: 375, height: 812)

        let switcherAndPills = VStack(spacing: 14) {
            PeriodSwitcher(period: .constant(.month), rarity: .holo, rangeText: "Oct 29 – Nov 27")
            HStack(spacing: 6) {
                ForEach(Rarity.allAscending) { r in
                    Text(r.shortName.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(r.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(r.foil, in: Capsule())
                }
            }
        }
        .padding(16)
        .frame(width: 480)
        .background(Color(red: 0.96, green: 0.96, blue: 0.98))

        let verticalImage = try renderHostingImage(verticalGrid, size: CGSize(width: 646, height: 618), style: .dark)
        let horizontalImage = try renderHostingImage(horizontalStack, size: CGSize(width: 410, height: 1230), style: .dark)
        let darkHoloImage = try renderHostingImage(vaultedHolo, size: CGSize(width: 348, height: 492), style: .dark)
        let lightHoloImage = try renderHostingImage(lightHolo, size: CGSize(width: 348, height: 492), style: .light)
        let binder375Image = try renderHostingImage(binder375, size: CGSize(width: 375, height: 812), style: .dark)
        let pillsLightImage = try renderHostingImage(switcherAndPills, size: CGSize(width: 480, height: 190), style: .light)

        for img in [verticalImage, horizontalImage, darkHoloImage, lightHoloImage, binder375Image, pillsLightImage] {
            try assertImageHasVisibleContent(img)
        }

        // Verify all 4 paid ProFoilStyle surfaces render non-blank, distinct finishes with active micro-texture strips.
        var proStrips: [[UInt8]] = []
        for style in ProFoilStyle.allCases {
            let proSurface = FoilSurface(rarity: .obsidian, proFoil: style)
                .frame(width: 120, height: 120)
            let proImage = try renderHostingImage(proSurface, size: CGSize(width: 120, height: 120), style: .dark)
            try assertImageHasVisibleContent(proImage)
            proStrips.append(try sampleBitmapBytes(proImage, width: 64, height: 64))
        }
        for i in 0..<(proStrips.count - 1) {
            let maxDelta = zip(proStrips[i], proStrips[i + 1]).map { abs(Int($0) - Int($1)) }.max() ?? 0
            XCTAssertGreaterThan(maxDelta, 20, "Pro foil finishes \(i) and \(i + 1) rendered too similarly")
        }

        if let dir = ProcessInfo.processInfo.environment["EARPRINT_TIER_PREVIEW_DIR"], !dir.isEmpty {
            let folder = URL(fileURLWithPath: dir, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try XCTUnwrap(verticalImage.pngData()).write(to: folder.appendingPathComponent("tiers-vertical-grid.png"))
            try XCTUnwrap(horizontalImage.pngData()).write(to: folder.appendingPathComponent("tiers-horizontal-stack.png"))
            try XCTUnwrap(darkHoloImage.pngData()).write(to: folder.appendingPathComponent("tier-holo-vaulted.png"))
            try XCTUnwrap(lightHoloImage.pngData()).write(to: folder.appendingPathComponent("tier-holo-light.png"))
            try XCTUnwrap(binder375Image.pngData()).write(to: folder.appendingPathComponent("tier-binder-375.png"))
            try XCTUnwrap(pillsLightImage.pngData()).write(to: folder.appendingPathComponent("tier-pills-contrast.png"))
        }
    }

    @MainActor
    private func renderHostingImage<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) throws -> UIImage {
        let themed = view
            .ignoresSafeArea()
            .environment(\.colorScheme, style == .light ? .light : .dark)
        let host = UIHostingController(rootView: themed)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        var drew = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            drew = host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        XCTAssertTrue(drew, "Expected drawHierarchy to succeed for \(size)")
        return image
    }

    private func sampleBitmapBytes(_ image: UIImage, width: Int, height: Int, file: StaticString = #filePath, line: UInt = #line) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage, "Expected CGImage", file: file, line: line)
        XCTAssertGreaterThan(cgImage.width, 0, file: file, line: line)
        XCTAssertGreaterThan(cgImage.height, 0, file: file, line: line)
        let sampleWidth = min(cgImage.width, width)
        let sampleHeight = min(cgImage.height, height)
        var bytes = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        try bytes.withUnsafeMutableBytes { rawBuffer in
            let ptr = try XCTUnwrap(rawBuffer.baseAddress, "Expected buffer address", file: file, line: line)
            let ctx = try XCTUnwrap(
                CGContext(
                    data: ptr,
                    width: sampleWidth,
                    height: sampleHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: sampleWidth * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ),
                "Expected bitmap context",
                file: file,
                line: line
            )
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        }
        return bytes
    }

    private func assertImageHasVisibleContent(_ image: UIImage, file: StaticString = #filePath, line: UInt = #line) throws {
        let bytes = try sampleBitmapBytes(image, width: 64, height: 64, file: file, line: line)
        var distinctColors = Set<UInt32>()
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let quantized = (UInt32(bytes[i] >> 4) << 8) | (UInt32(bytes[i + 1] >> 4) << 4) | UInt32(bytes[i + 2] >> 4)
            distinctColors.insert(quantized)
            if distinctColors.count >= 12 { break }
        }
        XCTAssertGreaterThanOrEqual(distinctColors.count, 12, "Rendered image looks flat/blank", file: file, line: line)
    }
}
