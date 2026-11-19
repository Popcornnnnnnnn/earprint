import XCTest
@testable import Earprint

final class AppIconOptionTests: XCTestCase {
    func testAlternateIconChoiceRoundTripsAllFortyCombinations() {
        XCTAssertEqual(AppIconChoice.from(alternateIconName: nil), .default)
        XCTAssertEqual(AppIconChoice.from(alternateIconName: "UnknownIcon"), .default)

        let all = AppIconChoice.allChoices
        XCTAssertEqual(all.count, 40)

        for choice in all {
            XCTAssertEqual(AppIconChoice.from(alternateIconName: choice.alternateIconName), choice)
        }
    }

    func testAlternateIconNamesAreUniqueForNonDefaultChoices() {
        XCTAssertEqual(IconFinish.usbcFinishes.count, 5)
        XCTAssertEqual(IconFinish.lightningFinishes.count, 5)
        XCTAssertEqual(IconBackground.allCases.count, 4)

        let nonNilNames = AppIconChoice.allChoices.compactMap(\.alternateIconName)
        XCTAssertEqual(nonNilNames.count, 39)
        XCTAssertEqual(Set(nonNilNames).count, 39)
    }
}
