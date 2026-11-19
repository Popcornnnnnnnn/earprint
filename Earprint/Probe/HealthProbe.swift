import Foundation
import HealthKit
import UIKit

/// Stage-1 probe: reads every headphone audio exposure sample and reports what HealthKit actually gives us.
@MainActor
final class HealthProbe: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case done
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var devices: [DeviceStats] = []
    @Published private(set) var totalSamples = 0
    @Published private(set) var rawLines: [String] = []
    @Published private(set) var loadSeconds: Double = 0

    private let store = HKHealthStore()
    private let type = HKQuantityType(.headphoneAudioExposure)
    private let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    func run() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            phase = .failed("Health data is not available on this device.")
            return
        }
        phase = .loading
        let started = Date()
        do {
            try await store.requestAuthorization(toShare: [], read: [type])
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: type)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
            )
            let samples = try await descriptor.result(for: store)
            process(samples)
            loadSeconds = Date().timeIntervalSince(started)
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func process(_ samples: [HKQuantitySample]) {
        let unit = HKUnit.decibelAWeightedSoundPressureLevel()
        var byKey: [String: DeviceStats] = [:]
        var plain: [ListeningSample] = []
        plain.reserveCapacity(samples.count)

        for sample in samples {
            let key = HeadphoneStats.deviceKey(for: sample.device)
            if byKey[key] == nil {
                let d = sample.device
                byKey[key] = DeviceStats(
                    id: key,
                    name: d?.name ?? "Unknown device",
                    manufacturer: d?.manufacturer,
                    model: d?.model,
                    hardwareVersion: d?.hardwareVersion,
                    firmwareVersion: d?.firmwareVersion,
                    softwareVersion: d?.softwareVersion,
                    localIdentifier: d?.localIdentifier
                )
            }
            byKey[key]?.sources.insert(sample.sourceRevision.source.bundleIdentifier)
            plain.append(ListeningSample(
                start: sample.startDate,
                end: sample.endDate,
                decibels: sample.quantity.doubleValue(for: unit),
                deviceKey: key
            ))
        }

        HeadphoneStats.aggregate(samples: plain, into: &byKey)
        devices = byKey.values.sorted { $0.listeningSeconds > $1.listeningSeconds }
        totalSamples = samples.count
        rawLines = (samples.prefix(3) + samples.suffix(3)).map(describe)
    }

    private func describe(_ s: HKQuantitySample) -> String {
        let db = s.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel())
        let seconds = Int(s.endDate.timeIntervalSince(s.startDate))
        let meta = (s.metadata ?? [:]).map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        return "\(dateFormat.string(from: s.startDate)) +\(seconds)s \(String(format: "%.1f", db)) dB(A) | device: \(s.device?.description ?? "nil") | source: \(s.sourceRevision.source.bundleIdentifier) | metadata: [\(meta)]"
    }

    /// Plain-text report for copying to the Mac (Universal Clipboard).
    var report: String {
        var lines = ["Earprint probe report", "Samples: \(totalSamples), devices: \(devices.count), load: \(String(format: "%.1f", loadSeconds))s", ""]
        for d in devices {
            lines.append("== \(d.name)")
            lines.append("manufacturer=\(d.manufacturer ?? "-") model=\(d.model ?? "-") hw=\(d.hardwareVersion ?? "-") fw=\(d.firmwareVersion ?? "-") sw=\(d.softwareVersion ?? "-") localId=\(d.localIdentifier ?? "-")")
            lines.append("sources=\(d.sources.sorted().joined(separator: ","))")
            lines.append("samples=\(d.sampleCount) listening=\(d.listeningSeconds.hoursMinutes) sessions=\(d.sessionCount) avgSession=\(d.averageSession.hoursMinutes) longest=\(d.longestSession.hoursMinutes) activeDays=\(d.activeDays)")
            lines.append("avgLevel=\(d.averageDecibels.map { String(format: "%.1f dB(A)", $0) } ?? "-") first=\(d.first.map(dateFormat.string) ?? "-") last=\(d.last.map(dateFormat.string) ?? "-")")
            lines.append("")
        }
        lines.append("Raw samples (first 3 + last 3):")
        lines.append(contentsOf: rawLines)
        return lines.joined(separator: "\n")
    }

    func copyReport() {
        UIPasteboard.general.string = report
    }
}
