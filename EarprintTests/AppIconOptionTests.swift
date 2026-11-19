import XCTest
@testable import Earprint

final class AppIconOptionTests: XCTestCase {
    func testAlternateIconNameRoundTrip() {
        XCTAssertEqual(AppIconOption.from(alternateIconName: nil), .auto)
        XCTAssertEqual(AppIconOption.from(alternateIconName: "UnknownIcon"), .auto)

        for option in AppIconOption.allCases {
            XCTAssertEqual(AppIconOption.from(alternateIconName: option.alternateIconName), option)
        }
    }

    func testAllTenOfficialAirPodsMaxColorsArePresent() {
        XCTAssertEqual(AppIconOption.usbcFinishes.count, 5)
        XCTAssertEqual(AppIconOption.lightningFinishes.count, 5)
        let nonNilNames = AppIconOption.allCases.compactMap(\.alternateIconName)
        XCTAssertEqual(nonNilNames.count, 11)
        XCTAssertEqual(Set(nonNilNames).count, 11)
    }
}
