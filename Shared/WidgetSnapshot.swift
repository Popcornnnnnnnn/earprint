import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Snapshot contract
//
// `WidgetSnapshot` is the ONLY data the widgets and the Live Activity read from the app.
// The app builds one (today from sample data, later from HealthKit) and calls
// `WidgetSnapshotStore.save(_:)`. The store writes JSON into the App Group container and asks
// WidgetKit to reload timelines when the content changed.
//
// Rules for producers (e.g. the HealthKit pipeline):
// - All durations are minutes (Double). All loudness values are dB(A) energy averages (Leq).
// - `heatmap` holds the last N days (normally 28) x 24 hours, oldest day first. The last row is `day`.
// - `cards` are sorted by `lifetimeMinutes`, highest first. `Card.id` must match `HeadphoneCard.id`
//   so `earprint://card/<id>` opens the right card in the app.
// - Bump `currentVersion` when you make a breaking change; widgets ignore snapshots with another version.
// - Keep it small (well under 100 KB). Widgets have a ~30 MB memory limit and a tight reload budget.

struct WidgetSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = WidgetSnapshot.currentVersion
    /// When the producer built this snapshot.
    var generatedAt: Date
    /// True while the numbers come from `SampleData` instead of Apple Health.
    var isSample: Bool
    /// Start of the local calendar day that `today` and the last heatmap row belong to.
    var day: Date
    var today: Today
    var week: Week
    var cards: [Card]
    var heatmap: Heatmap
    /// Combined lifetime listening across all pairs (active + vaulted), kept intact when `cards` filters vaulted pairs out.
    var totalLifetimeMinutes: Double? = nil
    /// Weekly listening breakdown across all active and vaulted headphones so weekly widget rankings stay accurate.
    var weeklyBreakdown: [Card]? = nil
    /// Full-precision UNIX timestamp for sub-millisecond freshness checks; falls back to `generatedAt` on legacy snapshots.
    var generatedAtEpoch: TimeInterval? = nil

    struct Today: Codable, Equatable {
        var minutes: Double
        /// Leq for today, nil when nothing was played.
        var decibels: Double?
        /// Headphone used most today (display name), nil when nothing was played.
        var deviceName: String?
        /// SF Symbol for that headphone, e.g. "airpodspro".
        var deviceSymbol: String
    }

    struct Week: Codable, Equatable {
        /// Listening minutes in the last 7 days (today included).
        var minutes: Double
        /// Share of the WHO weekly budget (80 dB(A) for 40 h, +3 dB halves the time). 1.0 = 100 %.
        var budgetUsed: Double
        /// Leq for the last 7 days, nil when nothing was played.
        var decibels: Double?
        /// Human label, e.g. "Nov 12 – 18".
        var label: String
    }

    struct Card: Codable, Equatable, Identifiable {
        /// Same id as `HeadphoneCard.id` in the app.
        var id: String
        var nickname: String
        var model: String
        var symbol: String
        var lifetimeMinutes: Double
        var weekMinutes: Double
        var sessions: Int
        var serial: Int
        /// Nil on legacy v1 snapshots, which always originated from collectible Collection cards.
        var hasCollectionCard: Bool? = nil

        var rarity: Rarity { Rarity(minutes: lifetimeMinutes) }
        var deepLink: URL { (hasCollectionCard ?? true) ? EarprintLink.card(id) : EarprintLink.rings }
    }

    struct Heatmap: Codable, Equatable {
        /// minutes[day][hour], oldest day first.
        var minutes: [[Double]]
        /// decibels[day][hour], 0 when there was no listening.
        var decibels: [[Double]]

        var grid: ListeningGrid { ListeningGrid(minutes: minutes, decibels: decibels) }
        /// Minutes per day, oldest first.
        var dailyMinutes: [Double] { minutes.map { $0.reduce(0, +) } }
    }
}

extension WidgetSnapshot {
    /// `today` adjusted for the date being rendered: if the snapshot is from an earlier day, today is empty.
    func today(at date: Date, calendar: Calendar = .current) -> Today {
        if calendar.isDate(day, inSameDayAs: date) { return today }
        return Today(minutes: 0, decibels: nil, deviceName: nil, deviceSymbol: today.deviceSymbol)
    }

    var topCard: Card? { cards.first }

    /// Full lifetime minutes across active and vaulted pairs, falling back cleanly for legacy v1 snapshots.
    var resolvedLifetimeMinutes: Double {
        totalLifetimeMinutes ?? cards.reduce(0) { $0 + $1.lifetimeMinutes }
    }

    /// Weekly listening breakdown across all headphones, falling back to `cards` for legacy v1 snapshots.
    var resolvedWeeklyBreakdown: [Card] {
        weeklyBreakdown ?? cards
    }

    var resolvedGeneratedAtEpoch: TimeInterval {
        generatedAtEpoch ?? generatedAt.timeIntervalSince1970
    }
}

// MARK: - Loudness band

/// Simple 3-level reading of a dB(A) value for dots and labels.
enum LevelBand: String {
    case safe, moderate, loud

    init(decibels: Double) {
        switch decibels {
        case ..<70: self = .safe
        case 70..<80: self = .moderate
        default: self = .loud
        }
    }

    var title: String {
        switch self {
        case .safe: "Safe level"
        case .moderate: "Moderate"
        case .loud: "Loud"
        }
    }
}

// MARK: - Deep links

/// URLs shared by widgets and the app: `earprint://card/<id>`, `earprint://rings`, `earprint://collection`.
enum EarprintLink {
    static let scheme = "earprint"

    enum Route: Equatable {
        case card(String)
        case collection
        case rings
        case wrapped
        case probe
    }

    static func card(_ id: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "card"
        components.queryItems = [URLQueryItem(name: "id", value: id)]
        return components.url ?? collection
    }
    static let collection = URL(string: "\(scheme)://collection")!
    static let rings = URL(string: "\(scheme)://rings")!
    static let wrapped = URL(string: "\(scheme)://wrapped")!
    static let probe = URL(string: "\(scheme)://probe")!

    static func route(for url: URL) -> Route? {
        guard url.scheme == scheme else { return nil }
        switch url.host {
        case "card":
            if let queryID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value,
               !queryID.isEmpty {
                return .card(queryID)
            }
            let pathID = url.pathComponents.dropFirst().first ?? ""
            return pathID.isEmpty ? .collection : .card(pathID)
        case "collection": return .collection
        case "rings": return .rings
        case "wrapped": return .wrapped
        case "probe": return .probe
        default: return nil
        }
    }
}

// MARK: - Widget kinds

enum WidgetKind {
    static let today = "EarprintToday"
    static let shelf = "EarprintCardShelf"
    static let ring = "EarprintRing"
    static let budget = "EarprintBudget"
}

// MARK: - App Group store

enum WidgetSnapshotStore {
    static let appGroup = "group.com.popcornnn.earprint"
    static let fileName = "widget-snapshot.json"

    /// Shared settings, e.g. which card the small widget features.
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: text) {
                return date
            }
            let wholeSecond = ISO8601DateFormatter()
            wholeSecond.formatOptions = [.withInternetDateTime]
            if let date = wholeSecond.date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(text)")
        }
        return d
    }

    private static let saveLock = NSLock()

    /// Reads the latest snapshot. Nil when the app never wrote one, or the version does not match.
    static func load() -> WidgetSnapshot? {
        guard let url = fileURL else { return nil }
        return load(from: url)
    }

    static func load(from url: URL) -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data),
              snapshot.version == WidgetSnapshot.currentVersion else { return nil }
        return snapshot
    }

    /// Writes the snapshot and reloads widget timelines when the content changed.
    /// Returns true when something was written.
    @discardableResult
    static func save(_ snapshot: WidgetSnapshot) throws -> Bool {
        guard let url = fileURL else { throw StoreError.noAppGroup }
        return try save(snapshot, to: url, reload: reloadWidgets)
    }

    @discardableResult
    static func save(_ snapshot: WidgetSnapshot, to url: URL, reload: () -> Void = {}) throws -> Bool {
        var toSave = snapshot
        toSave.generatedAtEpoch = toSave.resolvedGeneratedAtEpoch
        return try saveLock.withLock {
            // Reject snapshots older than the persisted one so out-of-order publishes never resurrect retired cards.
            if var old = load(from: url) {
                if toSave.resolvedGeneratedAtEpoch < old.resolvedGeneratedAtEpoch { return false }
                // Compare without `generatedAt` so re-publishing identical data does not burn the reload budget.
                old.generatedAt = toSave.generatedAt
                old.generatedAtEpoch = toSave.generatedAtEpoch
                if old == toSave { return false }
            }
            try encoder.encode(toSave).write(to: url, options: .atomic)
            reload()
            return true
        }
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    enum StoreError: Error { case noAppGroup }
}

// MARK: - Featured card (small widget, interactive)

enum FeaturedCard {
    private static let key = "featuredCardIndex"

    static var index: Int {
        get { WidgetSnapshotStore.defaults.integer(forKey: key) }
        set { WidgetSnapshotStore.defaults.set(newValue, forKey: key) }
    }

    static func card(in snapshot: WidgetSnapshot) -> WidgetSnapshot.Card? {
        guard !snapshot.cards.isEmpty else { return nil }
        return snapshot.cards[((index % snapshot.cards.count) + snapshot.cards.count) % snapshot.cards.count]
    }
}

// MARK: - Formatting

enum WidgetFormat {
    /// 72 -> "1h 12m", 45 -> "45m"
    static func duration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total >= 60 { return total % 60 == 0 ? "\(total / 60)h" : "\(total / 60)h \(total % 60)m" }
        return "\(total)m"
    }

    /// 11302 -> "188h", 45 -> "45m"
    static func hours(_ minutes: Double) -> String {
        minutes >= 60 ? "\(Int(minutes / 60))h" : "\(Int(minutes.rounded()))m"
    }

    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}
