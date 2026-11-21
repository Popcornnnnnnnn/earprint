import Foundation

/// Deterministic sample dossiers that match the collection cards, until the HealthKit pipeline fills real data.
enum DossierSample {
    /// Fixed "now" so screenshots and tests are reproducible: 2026-11-18 23:40 local time.
    static var referenceNow: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 23, minute: 40))!
    }

    static func hardware(for card: HeadphoneCard) -> DossierHardware {
        let source = (name: "iPhone 17 Pro", bundle: "com.apple.health.81A3F9C2-6D0B-4E7A-9C1F-2B7E5D4A8C30")
        switch card.model {
        case let m where m.contains("Max"):
            return DossierHardware(deviceName: card.nickname, manufacturer: "Apple Inc.", productID: "0x200A",
                                   modelName: "AirPods Max", hardwareVersion: "A2096", firmwareVersion: "6F8",
                                   sourceName: source.name, sourceBundleID: source.bundle)
        case let m where m.contains("Beats"):
            return DossierHardware(deviceName: card.nickname, manufacturer: "Apple Inc.", productID: "0x2012",
                                   modelName: "Beats Fit Pro", hardwareVersion: "A2577", firmwareVersion: "6F6",
                                   sourceName: source.name, sourceBundleID: source.bundle)
        default:
            return DossierHardware(deviceName: card.nickname, manufacturer: "Apple Inc.", productID: "0x2024",
                                   modelName: "AirPods Pro 2 (USB-C)", hardwareVersion: "A3047", firmwareVersion: "7E93",
                                   sourceName: source.name, sourceBundleID: source.bundle)
        }
    }
}

extension DeviceDossier {
    /// Realistic, deterministic sample data that agrees with the card's lifetime numbers.
    static func sample(for card: HeadphoneCard, now: Date = DossierSample.referenceNow) -> DeviceDossier {
        let calendar = Calendar.current
        var rng = SplitMix64(seed: card.id.utf8.reduce(5381) { ($0 &* 33) &+ UInt64($1) })

        let baseToday = calendar.startOfDay(for: now)
        let first = parse(card.firstMet, format: "yyyy.MM.dd", calendar: calendar) ?? calendar.date(byAdding: .day, value: -30, to: baseToday)!
        let effectiveNow = max(now, first)
        let today = calendar.startOfDay(for: effectiveNow)
        let last = lastDay(card.lastUsed, now: effectiveNow, calendar: calendar)
        let firstDay = calendar.startOfDay(for: first)
        let lastDay = max(firstDay, min(today, calendar.startOfDay(for: last)))
        let dayCount = max(1, (calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0) + 1)

        // 1. Which days are active, and how heavy each is.
        let sessionTarget = max(card.sessions, 1)
        let activeChance = min(1, Double(sessionTarget) / Double(dayCount) / 1.6)
        var weights = [Double](repeating: 0, count: dayCount)
        for d in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: d, to: firstDay)!
            let weekend = calendar.isDateInWeekend(date)
            let active = d == 0 || d == dayCount - 1 || rng.unit() < activeChance
            weights[d] = active ? rng.in(0.45...1.45) * (weekend ? 0.8 : 1) : 0
        }
        let activeDays = weights.indices.filter { weights[$0] > 0 }

        // 2. Sessions per active day (largest remainder).
        var perDay = [Int](repeating: 0, count: dayCount)
        let weightSum = activeDays.reduce(0) { $0 + weights[$1] }
        var remainders: [(Int, Double)] = []
        for d in activeDays {
            let exact = Double(sessionTarget) * weights[d] / weightSum
            perDay[d] = Int(exact)
            remainders.append((d, exact - Double(Int(exact))))
        }
        var missing = sessionTarget - perDay.reduce(0, +)
        for (d, _) in remainders.sorted(by: { $0.1 > $1.1 }) where missing > 0 { perDay[d] += 1; missing -= 1 }
        for d in [activeDays.first, activeDays.last].compactMap({ $0 }) where perDay[d] == 0 {
            if let donor = perDay.indices.max(by: { perDay[$0] < perDay[$1] }), perDay[donor] > 1 { perDay[donor] -= 1; perDay[d] = 1 }
        }

        // 3. Session lengths that add up to the lifetime and respect the longest wear.
        var slots: [(day: Int, raw: Double)] = []
        for d in 0..<dayCount { for _ in 0..<perDay[d] { slots.append((d, exp(rng.in(-1.0...1.0)) * weights[d])) } }
        let longest = max(card.longestMinutes, 5)
        let lifetime = max(card.lifetimeMinutes, longest)
        let longestIndex = slots.indices.isEmpty ? 0 : slots.indices.min { abs(slots[$0].day - dayCount * 2 / 5) < abs(slots[$1].day - dayCount * 2 / 5) }!
        var lengths = slots.map(\.raw)
        if !lengths.isEmpty {
            for _ in 0..<4 {
                let others = lengths.indices.filter { $0 != longestIndex }.reduce(0) { $0 + lengths[$1] }
                let scale = others > 0 ? (lifetime - longest) / others : 0
                for i in lengths.indices where i != longestIndex { lengths[i] = min(max(lengths[i] * scale, 3), longest * 0.86) }
            }
            lengths[longestIndex] = longest
        }

        // 4. Place sessions inside each day without overlaps (bucketed in O(sessions) instead of O(days × sessions)).
        var slotIndicesByDay = Array(repeating: [Int](), count: dayCount)
        for i in slots.indices {
            slotIndicesByDay[slots[i].day].append(i)
        }
        var sessions: [WearSession] = []
        sessions.reserveCapacity(slots.count)
        let anchors: [Double] = [8 * 60 + 5, 12 * 60 + 30, 18 * 60 + 10, 21 * 60 + 20, 15 * 60]
        for d in 0..<dayCount where perDay[d] > 0 {
            let dayStart = calendar.date(byAdding: .day, value: d, to: firstDay)!
            var dayLengths = slotIndicesByDay[d].map { (lengths[$0], $0 == longestIndex) }
            // Keep the marathon session for the evening.
            dayLengths.sort { !$0.1 && $1.1 }
            let windowStart = 7 * 60 + rng.in(0...35)
            var windowEnd = 25.5 * 60
            if dayStart == today { windowEnd = now.timeIntervalSince(dayStart) / 60 - 8 }
            var starts: [Double] = []
            if dayLengths.count <= 3 {
                var pool = anchors
                for i in stride(from: pool.count - 1, to: 0, by: -1) { pool.swapAt(i, Int(rng.unit() * Double(i + 1))) }
                let picks = pool.prefix(dayLengths.count).sorted()
                var cursor = 0.0
                for (i, anchor) in picks.enumerated() {
                    let s = max(anchor + rng.in(-25...25), cursor)
                    starts.append(s)
                    cursor = s + dayLengths[i].0 + 10
                }
            } else {
                let total = dayLengths.reduce(0) { $0 + $1.0 }
                let free = max(0, windowEnd - windowStart - total)
                let gaps = (0...dayLengths.count).map { _ in rng.in(0.3...1.7) }
                let gapSum = gaps.reduce(0, +)
                var cursor = windowStart
                for (i, item) in dayLengths.enumerated() {
                    cursor += free * gaps[i] / gapSum
                    starts.append(cursor)
                    cursor += item.0
                }
            }
            for (i, item) in dayLengths.enumerated() {
                let start = dayStart.addingTimeInterval(starts[i] * 60)
                let hour = calendar.component(.hour, from: start)
                var db = card.averageDecibels + rng.in(-4...4)
                if hour >= 22 || hour < 3 { db += 3.5 }
                if hour == 8 || hour == 18 { db += 2.5 }
                if hour >= 12 && hour <= 14 { db -= 3 }
                if rng.unit() < 0.03 { db += 11 }
                sessions.append(WearSession(start: start, minutes: item.0, averageDecibels: db, peakDecibels: 0,
                                            isEstimated: item.1 || item.0 > 150))
            }
        }

        // 5. Shift loudness so the energy average matches the card, then add peaks.
        let shift = card.averageDecibels - energyAverage(sessions)
        sessions = sessions.map { s in
            var s = s
            s.averageDecibels = min(95, s.averageDecibels + shift)
            s.peakDecibels = min(102, s.averageDecibels + rng.in(6...13))
            return s
        }

        // 6. Other headphones, so wear share is not always 100%.
        var others: [Date: Double] = [:]
        var dayMinutes = [Double](repeating: 0, count: dayCount)
        for s in sessions {
            let d = calendar.dateComponents([.day], from: firstDay, to: calendar.startOfDay(for: s.start)).day ?? 0
            if dayMinutes.indices.contains(d) { dayMinutes[d] += s.minutes }
        }
        let otherRatio = card.lifetimeMinutes > 100 * 60 ? 0.16 : 0.6
        for d in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: d, to: firstDay)!
            if rng.unit() < 0.55 { others[date] = max(dayMinutes[d], 40) * rng.in(0...(otherRatio * 2)) }
        }

        let total = sessions.reduce(0) { $0 + $1.minutes }
        return DeviceDossier(id: card.id, nickname: card.nickname, symbol: card.symbol, serial: card.serial,
                             hardware: DossierSample.hardware(for: card), sessions: sessions,
                             otherDevicesDailyMinutes: others, sampleCount: Int(total * 1.08),
                             lastSynced: effectiveNow.addingTimeInterval(-120), now: effectiveNow, calendar: calendar)
    }

    private static func parse(_ text: String, format: String, calendar: Calendar) -> Date? {
        DateText.parse(text, dateFormat: format, calendar: calendar)
    }

    /// "Today", "Yesterday" or "Sep 2" (assumed within the last year).
    private static func lastDay(_ text: String, now: Date, calendar: Calendar) -> Date {
        switch text.lowercased() {
        case "today": return now
        case "yesterday": return calendar.date(byAdding: .day, value: -1, to: now)!
        default:
            guard let md = parse(text, format: "MMM d", calendar: calendar) else { return now }
            var comps = calendar.dateComponents([.month, .day], from: md)
            comps.year = calendar.component(.year, from: now)
            var date = calendar.date(from: comps) ?? now
            if date > now { date = calendar.date(byAdding: .year, value: -1, to: date)! }
            return date
        }
    }
}
