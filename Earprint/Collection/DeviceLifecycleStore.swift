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

    /// Gregorian calendar anchored to a specific time zone so non-Gregorian user settings stay consistent.
    static func gregorianCalendar(timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    /// Year/month/day triple preserving the archival date independent of later time-zone travel.
    struct CalendarDay: Codable, Equatable, Hashable, Sendable, Comparable {
        var year: Int
        var month: Int
        var day: Int

        init(year: Int, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }

        init(date: Date, calendar: Calendar = .current) {
            let cal = DeviceRetirement.gregorianCalendar(timeZone: calendar.timeZone)
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            self.year = comps.year ?? 1970
            self.month = comps.month ?? 1
            self.day = comps.day ?? 1
        }

        var dottedText: String {
            String(format: "%04d.%02d.%02d", year, month, day)
        }

        static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
            if lhs.year != rhs.year { return lhs.year < rhs.year }
            if lhs.month != rhs.month { return lhs.month < rhs.month }
            return lhs.day < rhs.day
        }
    }

    private enum CodingKeys: String, CodingKey {
        case retiredDay
        case timeZoneIdentifier
        case retiredAt
        case reason
        case farewellNote
        case acknowledgedActivityAt
    }

    var retiredDay: CalendarDay
    var timeZoneIdentifier: String
    /// Local start-of-day timestamp in `retiredCalendar`, kept aligned with `retiredDay` for sorting and compatibility.
    var retiredAt: Date
    var reason: RetirementReason
    var farewellNote: String = ""
    /// Last post-retirement HealthKit wear timestamp the user explicitly chose to keep vaulted.
    var acknowledgedActivityAt: Date? = nil

    init(
        retiredDay: CalendarDay,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        reason: RetirementReason,
        farewellNote: String = "",
        acknowledgedActivityAt: Date? = nil
    ) {
        self.retiredDay = retiredDay
        self.timeZoneIdentifier = timeZoneIdentifier
        self.retiredAt = Self.dayInterval(for: retiredDay, timeZoneIdentifier: timeZoneIdentifier).start
        self.reason = reason
        self.farewellNote = farewellNote
        self.acknowledgedActivityAt = acknowledgedActivityAt
    }

    init(
        retiredAt: Date,
        reason: RetirementReason,
        farewellNote: String = "",
        acknowledgedActivityAt: Date? = nil,
        calendar: Calendar = .current
    ) {
        let day = CalendarDay(date: retiredAt, calendar: calendar)
        self.init(
            retiredDay: day,
            timeZoneIdentifier: calendar.timeZone.identifier,
            reason: reason,
            farewellNote: farewellNote,
            acknowledgedActivityAt: acknowledgedActivityAt
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedDate = try container.decode(Date.self, forKey: .retiredAt)
        let tzID = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier) ?? TimeZone.current.identifier
        let cal = Self.gregorianCalendar(timeZone: TimeZone(identifier: tzID) ?? .current)
        let day = try container.decodeIfPresent(CalendarDay.self, forKey: .retiredDay)
            ?? CalendarDay(date: decodedDate, calendar: cal)
        self.retiredDay = day
        self.timeZoneIdentifier = tzID
        self.retiredAt = Self.dayInterval(for: day, timeZoneIdentifier: tzID).start
        self.reason = try container.decode(RetirementReason.self, forKey: .reason)
        self.farewellNote = try container.decodeIfPresent(String.self, forKey: .farewellNote) ?? ""
        self.acknowledgedActivityAt = try container.decodeIfPresent(Date.self, forKey: .acknowledgedActivityAt)
    }

    var retiredCalendar: Calendar {
        Self.gregorianCalendar(timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current)
    }

    /// Date-only archival stamp in the time zone where the pair was retired (`yyyy.MM.dd`).
    var formattedRetiredDate: String {
        retiredDay.dottedText
    }

    /// Local day start on `retiredDay` in `retiredCalendar`.
    var startOfRetiredDay: Date {
        Self.dayInterval(for: retiredDay, timeZoneIdentifier: timeZoneIdentifier).start
    }

    /// Exclusive upper bound (the exact end of `retiredDay`'s calendar-day interval in `retiredCalendar`, DST-safe).
    /// Sessions starting strictly before this cutoff belong to the vaulted career (clamped to `careerEndMoment`);
    /// wear recorded at or after this cutoff triggers post-retirement activity detection.
    var careerCutoffEnd: Date {
        Self.dayInterval(for: retiredDay, timeZoneIdentifier: timeZoneIdentifier).end
    }

    /// Inclusive final second of `retiredDay` in `retiredCalendar` used to freeze `DeviceDossier.now` and milestones.
    var careerEndMoment: Date {
        careerCutoffEnd.addingTimeInterval(-1)
    }

    var sanitized: Self {
        Self(
            retiredDay: retiredDay,
            timeZoneIdentifier: timeZoneIdentifier,
            reason: reason,
            farewellNote: Self.clean(farewellNote, limit: Self.maxFarewellLength),
            acknowledgedActivityAt: acknowledgedActivityAt
        )
    }

    /// Collapses newlines and caps live typing at `maxFarewellLength` without stripping trailing spaces mid-entry.
    static func clampEditingNote(_ value: String) -> String {
        let singleLine = value.components(separatedBy: .newlines).joined(separator: " ")
        return String(singleLine.prefix(maxFarewellLength))
    }

    private static func dayInterval(for day: CalendarDay, timeZoneIdentifier: String) -> DateInterval {
        let cal = gregorianCalendar(timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current)
        if let noon = cal.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)),
           let interval = cal.dateInterval(of: .day, for: noon) {
            return interval
        }
        let start = cal.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
            ?? Date(timeIntervalSince1970: 0)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    private static func clean(_ value: String, limit: Int) -> String {
        let singleLine = value.components(separatedBy: .newlines).joined(separator: " ")
        return String(singleLine.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Identifies a retired headphone card and its known HealthKit device aliases so session cutoffs apply only to that pair.
struct RetirementCutoffScope: Codable, Equatable, Hashable, Sendable {
    var cardID: String
    var aliasIDs: [String]
    var modelName: String?
    var nickname: String?
    var cutoff: Date
    var timeZoneIdentifier: String = TimeZone.current.identifier

    private enum CodingKeys: String, CodingKey {
        case cardID, aliasIDs, modelName, nickname, cutoff, timeZoneIdentifier
    }

    init(
        cardID: String,
        aliasIDs: [String],
        modelName: String?,
        nickname: String?,
        cutoff: Date,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.cardID = cardID
        self.aliasIDs = aliasIDs
        self.modelName = modelName
        self.nickname = nickname
        self.cutoff = cutoff
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardID = try container.decode(String.self, forKey: .cardID)
        aliasIDs = try container.decodeIfPresent([String].self, forKey: .aliasIDs) ?? []
        modelName = try container.decodeIfPresent(String.self, forKey: .modelName)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        cutoff = try container.decode(Date.self, forKey: .cutoff)
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier) ?? TimeZone.current.identifier
    }

    var retiredCalendar: Calendar {
        DeviceRetirement.gregorianCalendar(timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current)
    }

    var bucketKey: String {
        Self.bucketKey(cutoff: cutoff, timeZoneIdentifier: timeZoneIdentifier)
    }

    static func bucketKey(cutoff: Date, timeZoneIdentifier: String) -> String {
        "\(Int(cutoff.timeIntervalSince1970))|\(timeZoneIdentifier)"
    }

    func matches(deviceKey: String, descriptor: DeviceDescriptor?) -> Bool {
        if deviceKey == cardID || aliasIDs.contains(deviceKey) {
            return true
        }
        guard let modelName, let nickname, let descriptor else { return false }
        let resolved = HeadphoneModelCatalog.resolve(descriptor)
        guard let productID = resolved.productID,
              let product = HeadphoneModelCatalog.byProductID[productID],
              product.key.collectibleArtwork != nil,
              let rawName = DeviceDescriptor.clean(descriptor.name) else {
            return false
        }
        return product.marketingName == modelName
            && Self.normalizedNickname(rawName) == Self.normalizedNickname(nickname)
    }

    static func normalizedNickname(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
    }
}

/// Persists which headphone cards are retired into the Vault, keyed by `card.id` and matched across `aliasIDs`.
@MainActor
@Observable
final class DeviceLifecycleStore {
    static let shared = DeviceLifecycleStore()
    static let inactiveNudgeThresholdDays = 90

    private nonisolated static let storageKey = "earprint.deviceRetirements.v1"
    private nonisolated static let scopesStorageKey = "earprint.deviceRetirementScopes.v1"
    private let defaults: UserDefaults
    private(set) var retirements: [String: DeviceRetirement]
    private var cutoffScopesByID: [String: RetirementCutoffScope]

    var cutoffScopes: [RetirementCutoffScope] {
        cutoffScopesByID.values.sorted { ($0.cardID, $0.cutoff) < ($1.cardID, $1.cutoff) }
    }

    nonisolated static func persistedCutoffScopes(defaults: UserDefaults = .standard) -> [RetirementCutoffScope] {
        var byID: [String: RetirementCutoffScope] = [:]
        if let scopeData = defaults.data(forKey: scopesStorageKey),
           let storedScopes = try? JSONDecoder().decode([String: RetirementCutoffScope].self, from: scopeData) {
            byID = storedScopes
        }
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode([String: DeviceRetirement].self, from: data) {
            for (key, retirement) in stored where byID[key] == nil {
                let sanitized = retirement.sanitized
                byID[key] = RetirementCutoffScope(
                    cardID: key,
                    aliasIDs: [],
                    modelName: nil,
                    nickname: nil,
                    cutoff: sanitized.careerCutoffEnd,
                    timeZoneIdentifier: sanitized.timeZoneIdentifier
                )
            }
            byID = byID.filter { stored[$0.key] != nil }
        }
        return byID.values.sorted { ($0.cardID, $0.cutoff) < ($1.cardID, $1.cutoff) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loadedRetirements: [String: DeviceRetirement]
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([String: DeviceRetirement].self, from: data) {
            loadedRetirements = stored.mapValues(\.sanitized)
        } else {
            loadedRetirements = [:]
        }
        var loadedScopes: [String: RetirementCutoffScope] = [:]
        if let scopeData = defaults.data(forKey: Self.scopesStorageKey),
           let storedScopes = try? JSONDecoder().decode([String: RetirementCutoffScope].self, from: scopeData) {
            loadedScopes = storedScopes
        }
        for (key, retirement) in loadedRetirements where loadedScopes[key] == nil {
            loadedScopes[key] = RetirementCutoffScope(
                cardID: key,
                aliasIDs: [],
                modelName: nil,
                nickname: nil,
                cutoff: retirement.careerCutoffEnd,
                timeZoneIdentifier: retirement.timeZoneIdentifier
            )
        }
        loadedScopes = loadedScopes.filter { loadedRetirements[$0.key] != nil }
        self.retirements = loadedRetirements
        self.cutoffScopesByID = loadedScopes
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

    func saveRetirement(_ retirement: DeviceRetirement, for card: HeadphoneCard) {
        var normalized = retirement.sanitized
        if let existing = self.retirement(for: card) {
            if existing.retiredDay == normalized.retiredDay,
               existing.timeZoneIdentifier == normalized.timeZoneIdentifier {
                normalized.acknowledgedActivityAt = normalized.acknowledgedActivityAt ?? existing.acknowledgedActivityAt
            } else {
                normalized.acknowledgedActivityAt = nil
            }
        }
        for alias in card.aliasIDs {
            retirements.removeValue(forKey: alias)
            cutoffScopesByID.removeValue(forKey: alias)
        }
        cutoffScopesByID[card.id] = RetirementCutoffScope(
            cardID: card.id,
            aliasIDs: card.aliasIDs,
            modelName: card.model,
            nickname: card.nickname,
            cutoff: normalized.careerCutoffEnd,
            timeZoneIdentifier: normalized.timeZoneIdentifier
        )
        retirements[card.id] = normalized
        persist()
    }

    func retire(
        _ card: HeadphoneCard,
        at date: Date,
        reason: RetirementReason,
        farewellNote: String,
        calendar: Calendar = .current
    ) {
        let value = DeviceRetirement(
            retiredAt: date,
            reason: reason,
            farewellNote: farewellNote,
            calendar: calendar
        )
        saveRetirement(value, for: card)
    }

    func unretire(_ card: HeadphoneCard) {
        var changed = retirements.removeValue(forKey: card.id) != nil
        if cutoffScopesByID.removeValue(forKey: card.id) != nil {
            changed = true
        }
        for alias in card.aliasIDs {
            if retirements.removeValue(forKey: alias) != nil {
                changed = true
            }
            if cutoffScopesByID.removeValue(forKey: alias) != nil {
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
        let normalized = current.sanitized
        for alias in card.aliasIDs {
            retirements.removeValue(forKey: alias)
            cutoffScopesByID.removeValue(forKey: alias)
        }
        cutoffScopesByID[card.id] = RetirementCutoffScope(
            cardID: card.id,
            aliasIDs: card.aliasIDs,
            modelName: card.model,
            nickname: card.nickname,
            cutoff: normalized.careerCutoffEnd,
            timeZoneIdentifier: normalized.timeZoneIdentifier
        )
        retirements[card.id] = normalized
        persist()
    }

    /// True when HealthKit shows an underlying wear sample on or after `careerCutoffEnd` (DST-safe day end in `retiredCalendar`) that hasn't been acknowledged yet.
    func hasUnacknowledgedPostRetirementActivity(
        for card: HeadphoneCard,
        lastWearEnd: Date?,
        lastWearStart: Date? = nil
    ) -> Bool {
        guard let retirement = retirement(for: card) else { return false }
        let cutoff = retirement.careerCutoffEnd
        let hasPostCutoffWear: Bool = {
            if let lastWearStart, lastWearStart >= cutoff { return true }
            if let lastWearEnd, lastWearEnd > cutoff { return true }
            return false
        }()
        guard hasPostCutoffWear else { return false }
        let activityMoment = max(lastWearEnd ?? .distantPast, lastWearStart ?? .distantPast)
        if let acknowledged = retirement.acknowledgedActivityAt {
            return activityMoment > acknowledged.addingTimeInterval(60)
        }
        return true
    }

    func hasUnacknowledgedPostRetirementActivity(for card: HeadphoneCard, lastWear: Date?) -> Bool {
        hasUnacknowledgedPostRetirementActivity(for: card, lastWearEnd: lastWear, lastWearStart: lastWear)
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
        if let scopeData = try? JSONEncoder().encode(cutoffScopesByID) {
            defaults.set(scopeData, forKey: Self.scopesStorageKey)
        }
    }
}
