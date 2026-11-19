import SwiftUI

struct ProbeView: View {
    @StateObject private var probe = HealthProbe()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await probe.run() }
                    } label: {
                        Label(probe.phase == .loading ? "Reading…" : "Read Health data", systemImage: "waveform")
                    }
                    .disabled(probe.phase == .loading)

                    if probe.phase == .done {
                        Button {
                            probe.copyReport()
                            copied = true
                        } label: {
                            Label(copied ? "Copied" : "Copy report", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                    }
                } footer: {
                    status
                }

                ForEach(probe.devices) { device in
                    Section(device.name) {
                        row("Listening", device.listeningSeconds.hoursMinutes)
                        row("Sessions", "\(device.sessionCount)")
                        row("Avg session", device.averageSession.hoursMinutes)
                        row("Longest", device.longestSession.hoursMinutes)
                        row("Avg level", device.averageDecibels.map { String(format: "%.0f dB(A)", $0) } ?? "-")
                        row("Active days", "\(device.activeDays)")
                        row("Samples", "\(device.sampleCount)")
                        row("Model", [device.manufacturer, device.model, device.hardwareVersion].compactMap { $0 }.joined(separator: " · "))
                    }
                }

                WidgetDebugSection()

                if !probe.rawLines.isEmpty {
                    Section("Raw samples") {
                        ForEach(probe.rawLines, id: \.self) { line in
                            Text(line).font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Earprint probe")
        }
    }

    @ViewBuilder private var status: some View {
        switch probe.phase {
        case .idle:
            Text("Reads headphone audio levels from Apple Health. Nothing leaves this iPhone.")
        case .loading:
            Text("Reading samples…")
        case .done:
            Text("\(probe.totalSamples) samples from \(probe.devices.count) devices in \(String(format: "%.1f", probe.loadSeconds))s. If this shows 0, allow access in Settings › Health › Data Access.")
        case .failed(let message):
            Text(message).foregroundStyle(.red)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }
}
