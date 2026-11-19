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

    func testAlternateIconNamesAreUniqueAndNonEmpty() {
        let nonNilNames = AppIconOption.allCases.compactMap(\.alternateIconName)
        XCTAssertEqual(nonNilNames.count, AppIconOption.allCases.count - 1)
        XCTAssertEqual(Set(nonNilNames).count, nonNilNames.count)
        for name in nonNilNames {
            XCTAssertFalse(name.isEmpty)
        }
    }
}
