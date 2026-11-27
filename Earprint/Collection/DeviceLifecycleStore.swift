import Foundation
import Observation

/// Why a collector retired a pair of headphones from active rotation into the Vault.
enum RetirementReason: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case upgraded
    case battery
    case lost
    case giftedOrSold
    case broken
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upgraded: "Upgraded"
        case .battery: "Battery worn out"
        case .lost: "Lost"
        case .giftedOrSold: "Gifted or sold"
        case .broken: "Broken"
        case .other: "Retired"
        }
    }

    var symbol: String {
        switch self {
        case .upgraded: "arrow.up.circle.fill"
        case .battery: "battery.25"
        case .lost: "location.slash.fill"
        case .giftedOrSold: "gift.fill"
        case .broken: "wrench.and.screwdriver.fill"
        case .other: "archivebox.fill"
        }
    }
}

/// On-device Vault metadata sealing a retired pair's career end date, reason, and farewell engraving.
struct DeviceRetirement: Codable, Equatable, Hashable, Sendable {
    static let maxFarewellLength = 80

    var retiredAt: Date
    var reason: RetirementReason
    var farewellNote: String = ""
    /// Last post-retirement HealthKit wear timestamp the user explicitly chose to keep vaulted.
    var acknowledgedActivityAt: Date? = nil

    var sanitized: Self {
        Self(
            retiredAt: retiredAt,
            reason: reason,
            farewellNote: Self.clean(farewellNote, limit: Self.maxFarewellLength),
            acknowledgedActivityAt: acknowledgedActivityAt
        )
    }

    private static func clean(_ value: String, limit: Int) -> String {
        let singleLine = value.components(separatedBy: .newlines).joined(separator: " ")
        return String(singleLine.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Persists which headphone cards are retired into the Vault, keyed by `card.id` and matched across `aliasIDs`.
@MainActor
@Observable
final class DeviceLifecycleStore {
    static let shared = DeviceLifecycleStore()
    static let inactiveNudgeThresholdDays = 90

    private static let storageKey = "earprint.deviceRetirements.v1"
    private let defaults: UserDefaults
    private(set) var retirements: [String: DeviceRetirement]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([String: DeviceRetirement].self, from: data) {
            retirements = stored.mapValues(\.sanitized)
        } else {
            retirements = [:]
        }
    }

    func retirement(for card: HeadphoneCard) -> DeviceRetirement? {
        retirement(forCardID: card.id, aliasIDs: card.aliasIDs)
    }

    func retirement(forCardID id: String, aliasIDs: [String] = []) -> DeviceRetirement? {
        for candidate in [id] + aliasIDs {
            if let match = retirements[candidate] {
                return match
            }
        }
        return nil
    }

    func isRetired(_ card: HeadphoneCard) -> Bool {
        retirement(for: card) != nil
    }

    func isRetired(cardID: String, aliasIDs: [String] = []) -> Bool {
        retirement(forCardID: cardID, aliasIDs: aliasIDs) != nil
    }

    func retire(
        _ card: HeadphoneCard,
        at date: Date,
        reason: RetirementReason,
        farewellNote: String
    ) {
        let existing = retirement(for: card)
        let keepAck: Date? = if let existing, abs(existing.retiredAt.timeIntervalSince(date)) < 1 {
            existing.acknowledgedActivityAt
        } else {
            nil
        }
        let value = DeviceRetirement(
            retiredAt: date,
            reason: reason,
            farewellNote: farewellNote,
            acknowledgedActivityAt: keepAck
        ).sanitized
        for alias in card.aliasIDs {
            retirements.removeValue(forKey: alias)
        }
        retirements[card.id] = value
        persist()
    }

    func unretire(_ card: HeadphoneCard) {
        var changed = retirements.removeValue(forKey: card.id) != nil
        for alias in card.aliasIDs {
            if retirements.removeValue(forKey: alias) != nil {
                changed = true
            }
        }
        if changed {
            persist()
        }
    }

    func acknowledgePostRetirementActivity(for card: HeadphoneCard, activityDate: Date) {
        guard var current = retirement(for: card) else { return }
        current.acknowledgedActivityAt = activityDate
        for alias in card.aliasIDs {
            retirements.removeValue(forKey: alias)
        }
        retirements[card.id] = current.sanitized
        persist()
    }

    /// True when HealthKit shows listening sessions strictly after `retiredAt` that haven't been acknowledged yet.
    func hasUnacknowledgedPostRetirementActivity(for card: HeadphoneCard, lastWear: Date?) -> Bool {
        guard let retirement = retirement(for: card), let lastWear else { return false }
        guard lastWear > retirement.retiredAt.addingTimeInterval(60) else { return false }
        if let acknowledged = retirement.acknowledgedActivityAt {
            return lastWear > acknowledged.addingTimeInterval(60)
        }
        return true
    }

    /// Gentle prompt condition for active cards unused for 90+ days when the collector still owns other active pairs.
    func shouldSuggestRetirement(
        for card: HeadphoneCard,
        lastWear: Date?,
        totalActiveCardCount: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard !isRetired(card), totalActiveCardCount > 1, let lastWear else { return false }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastWear),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return days >= Self.inactiveNudgeThresholdDays
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(retirements) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
