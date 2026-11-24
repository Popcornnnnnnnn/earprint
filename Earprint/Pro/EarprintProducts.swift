import SwiftUI

enum EarprintProductID: String, CaseIterable, Sendable {
    case proLifetime = "com.popcornnn.earprint.pro.lifetime"
    case tipSmall = "com.popcornnn.earprint.tip.small"
    case tipMedium = "com.popcornnn.earprint.tip.medium"
    case tipLarge = "com.popcornnn.earprint.tip.large"

    static let tipIDs = [tipSmall.rawValue, tipMedium.rawValue, tipLarge.rawValue]

    static func isTip(_ id: String) -> Bool {
        tipIDs.contains(id)
    }

    var fallbackLabel: LocalizedStringKey {
        switch self {
        case .proLifetime: "Earprint Pro"
        case .tipSmall: "Coffee"
        case .tipMedium: "Collector Booster"
        case .tipLarge: "Studio Patron"
        }
    }

    var systemImage: String {
        switch self {
        case .proLifetime: "sparkles"
        case .tipSmall: "cup.and.saucer.fill"
        case .tipMedium: "sparkles.rectangle.stack.fill"
        case .tipLarge: "heart.circle.fill"
        }
    }
}
