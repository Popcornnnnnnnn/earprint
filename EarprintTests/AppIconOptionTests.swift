import XCTest
@testable import Earprint

final class AppIconOptionTests: XCTestCase {
    func testAlternateIconChoiceRoundTripsAllChoices() {
        XCTAssertEqual(AppIconChoice.from(alternateIconName: nil), .default)
        XCTAssertEqual(AppIconChoice.default, .ringsEmblem)
        XCTAssertEqual(AppIconChoice.from(alternateIconName: "UnknownIcon"), .default)

        let all = AppIconChoice.allChoices
        XCTAssertEqual(all.count, 41)

        for choice in all {
            XCTAssertEqual(AppIconChoice.from(alternateIconName: choice.alternateIconName), choice)
        }
    }

    func testAlternateIconNamesAreUniqueForNonDefaultChoices() {
        XCTAssertEqual(IconFinish.usbcFinishes.count, 5)
        XCTAssertEqual(IconFinish.lightningFinishes.count, 5)
        XCTAssertEqual(IconBackground.allCases.count, 4)

        let nonNilNames = AppIconChoice.allChoices.compactMap(\.alternateIconName)
        XCTAssertEqual(nonNilNames.count, 40)
        XCTAssertEqual(Set(nonNilNames).count, 40)
        XCTAssertTrue(nonNilNames.contains("AppIconMidnightAuto"))
    }
}
