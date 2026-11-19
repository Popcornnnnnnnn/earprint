import Foundation
import HealthKit

/// One listening sample, copied out of HealthKit so the stats code is testable without HealthKit.
struct ListeningSample {
    let start: Date
    let end: Date
    let decibels: Double
    let deviceKey: String
}

/// Aggregated stats for one headphone device (one HKDevice identity).
struct DeviceStats: Identifiable {
    let id: String
    var name: String
    var manufacturer: String?
    var model: String?
    var hardwareVersion: String?
    var firmwareVersion: String?
    var softwareVersion: String?
    var localIdentifier: String?
    var sources: Set<String> = []

    var sampleCount = 0
    var listeningSeconds: Double = 0
    /// Sum of 10^(dB/10) * seconds, for an energy (Leq) average.
    var energySum: Double = 0
    var first: Date?
    var last: Date?
    var sessionCount = 0
    var longestSession: TimeInterval = 0
    var activeDays = 0

    /// Time-weighted energy average, like a sound level meter's Leq.
    var averageDecibels: Double? {
        listeningSeconds > 0 ? 10 * log10(energySum / listeningSeconds) : nil
    }
    var averageSession: TimeInterval {
        sessionCount > 0 ? listeningSeconds / Double(sessionCount) : 0
    }
}

enum HeadphoneStats {
    /// Gap that still counts as the same wearing session.
    static let sessionGap: TimeInterval = 5 * 60

    static func deviceKey(for device: HKDevice?) -> String {
        guard let device else { return "unknown-device" }
        return [device.name, device.manufacturer, device.model, device.hardwareVersion, device.localIdentifier]
            .map { $0 ?? "-" }
            .joined(separator: "|")
    }

    /// Fills the time-based fields of each device from its samples.
    static func aggregate(samples: [ListeningSample], into devices: inout [String: DeviceStats], calendar: Calendar = .current) {
        let grouped = Dictionary(grouping: samples, by: \.deviceKey)
        for (key, list) in grouped {
            guard var stats = devices[key] else { continue }
            let sorted = list.sorted { $0.start < $1.start }
            var days = Set<Date>()
            var sessions = 0
            var longest: TimeInterval = 0
            var sessionStart: Date?
            var sessionEnd: Date?

            for sample in sorted {
                let seconds = max(0, sample.end.timeIntervalSince(sample.start))
                stats.sampleCount += 1
                stats.listeningSeconds += seconds
                stats.energySum += pow(10, sample.decibels / 10) * seconds
                stats.first = min(stats.first ?? sample.start, sample.start)
                stats.last = max(stats.last ?? sample.end, sample.end)
                days.insert(calendar.startOfDay(for: sample.start))

                if let end = sessionEnd, sample.start.timeIntervalSince(end) <= sessionGap {
                    sessionEnd = max(end, sample.end)
                } else {
                    if let start = sessionStart, let end = sessionEnd {
                        longest = max(longest, end.timeIntervalSince(start))
                    }
                    sessions += 1
                    sessionStart = sample.start
                    sessionEnd = sample.end
                }
            }
            if let start = sessionStart, let end = sessionEnd {
                longest = max(longest, end.timeIntervalSince(start))
            }
            stats.sessionCount = sessions
            stats.longestSession = longest
            stats.activeDays = days.count
            devices[key] = stats
        }
    }
}

extension TimeInterval {
    var hoursMinutes: String {
        let totalMinutes = Int((self / 60).rounded())
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }
}
