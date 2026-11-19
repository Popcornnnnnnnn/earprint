import Foundation

/// One headphone audio exposure sample, copied out of HealthKit.
struct RawListeningSample: Sendable {
    var start: Date
    var end: Date
    /// dB(A) sound pressure level, as HealthKit stores it.
    var decibels: Double
    /// nil when the sample has no `HKDevice` (older iOS versions, some third-party writers).
    var device: DeviceDescriptor?
    var source: String = ""
}

/// WHO safe-listening math (WHO/ITU H.870 "Safe listening devices and systems", 2019):
/// the reference weekly dose is 80 dB(A) for 40 hours. Equal-energy rule: every +3 dB halves the allowed time.
/// We use exact energy (10·log10 2 ≈ 3.01 dB per doubling), so the dose is the energy sum divided by the
/// energy of 40 h at 80 dB. This matches energy-averaged (Leq) levels exactly.
enum HearingBudget {
    static let referenceDecibels = 80.0
    static let referenceSeconds = 40.0 * 3600

    /// Sound energy of a level held for some seconds, in "80 dB-seconds"-free units: 10^(L/10) · s.
    static func energy(decibels: Double, seconds: Double) -> Double {
        pow(10, decibels / 10) * seconds
    }

    /// Fraction of the weekly budget (1.0 = 100 %).
    static func dose(energy: Double) -> Double {
        energy / (pow(10, referenceDecibels / 10) * referenceSeconds)
    }

    static func dose(decibels: Double, seconds: Double) -> Double {
        dose(energy: energy(decibels: decibels, seconds: seconds))
    }

    /// Energy (Leq) average of a total energy over a duration.
    static func averageDecibels(energy: Double, seconds: Double) -> Double? {
        seconds > 0 && energy > 0 ? 10 * log10(energy / seconds) : nil
    }
}

/// Sorted, merged listening sessions. Two samples belong to one session when the silence between
/// them is at most `gap` seconds. Works for samples arriving in any order (HealthKit sync can be late).
struct SessionSet: Codable, Equatable, Sendable {
    struct Span: Codable, Equatable, Sendable {
        var start: TimeInterval
        var end: TimeInterval
        var duration: TimeInterval { end - start }
    }

    private(set) var spans: [Span] = []

    var count: Int { spans.count }
    var longest: TimeInterval { spans.map(\.duration).max() ?? 0 }
    var totalSpan: TimeInterval { spans.reduce(0) { $0 + $1.duration } }

    mutating func insert(start: TimeInterval, end: TimeInterval, gap: TimeInterval) {
        let end = max(start, end)
        // Fast path: samples usually come in time order.
        if let last = spans.last, start >= last.start {
            if start - last.end <= gap {
                spans[spans.count - 1].end = max(last.end, end)
            } else {
                spans.append(Span(start: start, end: end))
            }
            return
        }
        // First span that starts after this sample.
        var lo = 0, hi = spans.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if spans[mid].start <= start { lo = mid + 1 } else { hi = mid }
        }
        var first = lo
        if first > 0, start - spans[first - 1].end <= gap { first -= 1 }
        var merged = Span(start: start, end: end)
        var last = first
        while last < spans.count, spans[last].start - merged.end <= gap {
            merged.start = min(merged.start, spans[last].start)
            merged.end = max(merged.end, spans[last].end)
            last += 1
        }
        spans.replaceSubrange(first..<last, with: [merged])
    }
}

/// Listening inside one 15-minute wall-clock-independent slot. Absolute 15-minute slots map cleanly
/// to local hours in every real time zone (all UTC offsets are multiples of 15 minutes).
struct SlotTotals: Codable, Equatable, Sendable {
    var seconds: Double = 0
    var energy: Double = 0
}

/// Running totals for one headphone. Codable so the whole aggregate can be cached to disk.
struct DeviceAccumulator: Codable, Sendable {
    var key: String
    /// Latest descriptor seen (by sample time), so the card shows the current nickname.
    var descriptor: DeviceDescriptor?
    var descriptorDate: Date = .distantPast
    var names: [String] = []
    var sources: Set<String> = []

    var sampleCount = 0
    var seconds: Double = 0
    var energy: Double = 0
    var first: Date?
    var last: Date?
    var sessions = SessionSet()
    /// Local calendar day (yyyymmdd, in the time zone at ingest time) -> listening seconds.
    var daily: [Int: Double] = [:]
    /// Absolute 15-minute slot index (epoch seconds / 900) -> totals. Only recent slots are kept.
    var slots: [Int: SlotTotals] = [:]

    var activeDays: Int { daily.values.filter { $0 > 0 }.count }
    var averageDecibels: Double? { HearingBudget.averageDecibels(energy: energy, seconds: seconds) }
}

/// The whole listening history, folded into small per-device totals.
struct ListeningAggregate: Codable, Sendable {
    static let schemaVersion = 1
    /// Gap that still counts as the same session (wearing) — 5 minutes.
    static let sessionGap: TimeInterval = 5 * 60
    /// iOS writes short clips (seconds to ~30 min). Anything longer is clipped so one bad sample cannot
    /// claim a whole day.
    static let maxSampleDuration: TimeInterval = 6 * 3600
    static let slotLength: TimeInterval = 15 * 60
    /// Slots older than this are dropped; the grid only needs 28 days.
    static let slotRetentionDays = 35
    static let unattributedKey = "unattributed"

    var version = ListeningAggregate.schemaVersion
    var devices: [String: DeviceAccumulator] = [:]
    var totalSamples = 0
    /// Samples whose device is the phone / watch itself, not a headphone.
    var hostSamples = 0
    /// Samples with impossible values (negative duration, NaN or out-of-range dB).
    var invalidSamples = 0
    var clippedSamples = 0

    var isEmpty: Bool { devices.isEmpty }

    mutating func ingest(_ samples: [RawListeningSample], now: Date = Date(), calendar: Calendar = .current) {
        let slotCutoff = now.addingTimeInterval(-Double(Self.slotRetentionDays) * 86_400).timeIntervalSince1970
        var dayCache = DayCache(calendar: calendar)

        for sample in samples {
            totalSamples += 1
            guard sample.decibels.isFinite, sample.decibels >= 0, sample.decibels <= 160,
                  sample.end >= sample.start else {
                invalidSamples += 1
                continue
            }
            if let device = sample.device, device.isHostDevice {
                hostSamples += 1
                continue
            }
            var end = sample.end
            if end.timeIntervalSince(sample.start) > Self.maxSampleDuration {
                end = sample.start.addingTimeInterval(Self.maxSampleDuration)
                clippedSamples += 1
            }

            let key = sample.device?.identityKey ?? Self.unattributedKey
            var acc = devices[key] ?? DeviceAccumulator(key: key)
            let seconds = end.timeIntervalSince(sample.start)
            let energy = HearingBudget.energy(decibels: sample.decibels, seconds: seconds)

            acc.sampleCount += 1
            acc.seconds += seconds
            acc.energy += energy
            acc.first = min(acc.first ?? sample.start, sample.start)
            acc.last = max(acc.last ?? end, end)
            if !sample.source.isEmpty { acc.sources.insert(sample.source) }
            if let device = sample.device, end >= acc.descriptorDate {
                acc.descriptor = device
                acc.descriptorDate = end
            }
            if let name = DeviceDescriptor.clean(sample.device?.name), !acc.names.contains(name) {
                acc.names.append(name)
            }
            acc.sessions.insert(start: sample.start.timeIntervalSince1970, end: end.timeIntervalSince1970,
                                gap: Self.sessionGap)

            // Split across local days.
            var cursor = sample.start
            while cursor < end {
                let (dayKey, dayEnd) = dayCache.day(containing: cursor)
                let pieceEnd = min(end, dayEnd)
                acc.daily[dayKey, default: 0] += pieceEnd.timeIntervalSince(cursor)
                cursor = pieceEnd
            }

            // Split across 15-minute slots (recent samples only).
            if end.timeIntervalSince1970 > slotCutoff, seconds > 0 {
                var t = max(sample.start.timeIntervalSince1970, slotCutoff)
                let stop = end.timeIntervalSince1970
                while t < stop {
                    let index = Int((t / Self.slotLength).rounded(.down))
                    let slotEnd = Double(index + 1) * Self.slotLength
                    let piece = min(stop, slotEnd) - t
                    acc.slots[index, default: SlotTotals()].seconds += piece
                    acc.slots[index, default: SlotTotals()].energy += HearingBudget.energy(decibels: sample.decibels, seconds: piece)
                    t += piece
                }
            }
            devices[key] = acc
        }
        prune(now: now)
    }

    /// Drops 15-minute slots that fell out of the retention window.
    mutating func prune(now: Date) {
        let cutoff = Int((now.addingTimeInterval(-Double(Self.slotRetentionDays) * 86_400).timeIntervalSince1970 / Self.slotLength).rounded(.down))
        for key in devices.keys {
            if devices[key]!.slots.keys.contains(where: { $0 < cutoff }) {
                devices[key]!.slots = devices[key]!.slots.filter { $0.key >= cutoff }
            }
        }
    }
}

/// Caches the current local day so sorted samples avoid repeated calendar math.
struct DayCache {
    let calendar: Calendar
    private var start = Date.distantFuture
    private var end = Date.distantPast
    private var key = 0

    init(calendar: Calendar) { self.calendar = calendar }

    mutating func day(containing date: Date) -> (key: Int, end: Date) {
        if date >= start && date < end { return (key, end) }
        guard let interval = calendar.dateInterval(of: .day, for: date) else {
            return (0, date.addingTimeInterval(86_400))
        }
        start = interval.start
        end = interval.end
        let c = calendar.dateComponents([.year, .month, .day], from: interval.start)
        key = (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
        return (key, end)
    }
}
