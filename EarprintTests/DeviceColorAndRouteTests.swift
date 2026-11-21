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
}
