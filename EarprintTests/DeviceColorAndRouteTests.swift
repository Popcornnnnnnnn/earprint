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

    func testCardStackPoseForActiveBehindAndDealtCards() {
        let top = CardStackPose.pose(forDelta: 0)
        XCTAssertEqual(top.offsetX, 0)
        XCTAssertEqual(top.offsetY, 0)
        XCTAssertEqual(top.scale, 1.0)
        XCTAssertEqual(top.rotationDegrees, 0)
        XCTAssertEqual(top.opacity, 1.0)

        let behind = CardStackPose.pose(forDelta: 1)
        XCTAssertGreaterThan(behind.offsetX, 0)
        XCTAssertGreaterThan(behind.offsetY, 0)
        XCTAssertLessThan(behind.scale, 1.0)
        XCTAssertGreaterThan(behind.rotationDegrees, 0)
        XCTAssertLessThan(behind.zIndex, top.zIndex)

        let dealt = CardStackPose.pose(forDelta: -1)
        XCTAssertLessThan(dealt.offsetX, -200)
        XCTAssertLessThan(dealt.rotationDegrees, -10)
        XCTAssertLessThan(dealt.opacity, 0.1)
        XCTAssertGreaterThan(dealt.zIndex, top.zIndex)
    }
}
