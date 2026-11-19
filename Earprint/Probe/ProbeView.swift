import SwiftUI

struct ProbeView: View {
    @ObservedObject var library: HeadphoneLibrary
    @StateObject private var probe = HealthProbe()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                pipelineSection

                #if DEBUG
                seederSection
                #endif

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
                } header: {
                    Text("Raw Health probe")
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

    private var pipelineSection: some View {
        Section {
            row("Source", library.isShowingSampleData ? "Sample data (fallback)" : "Apple Health")
            if let snap = library.snapshot {
                row("Devices", "\(snap.devices.count)")
                row("Samples", "\(snap.totalSamples) (\(snap.hostSamples) host, \(snap.invalidSamples) invalid)")
            }
            if let synced = library.lastSyncDate {
                row("Last sync", synced.formatted(date: .omitted, time: .standard))
            }

            Button {
                Task { await library.connectAndSync() }
            } label: {
                Label(library.isLoading ? "Syncing…" : "Sync Apple Health", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(library.isLoading)

            Button(role: .destructive) {
                Task { await library.resetCacheAndResync() }
            } label: {
                Label("Reset cache & resync", systemImage: "trash")
            }
            .disabled(library.isLoading)
        } header: {
            Text("Library pipeline")
        } footer: {
            if let message = library.statusMessage {
                Text(message)
            }
        }
    }

    #if DEBUG
    private var seederSection: some View {
        Section {
            Button {
                Task { await library.seedSimulatorHealth() }
            } label: {
                Label(library.isSeeding ? "Seeding HealthKit…" : "Seed simulator Health data", systemImage: "wand.and.stars")
            }
            .disabled(library.isSeeding || library.isLoading)

            Button(role: .destructive) {
                Task { await library.clearSeededHealth() }
            } label: {
                Label("Clear seeded Health data", systemImage: "xmark.circle")
            }
            .disabled(library.isSeeding || library.isLoading)
        } header: {
            Text("Simulator seeder (Debug)")
        } footer: {
            Text(library.seedStatus ?? "Writes 3 realistic headphones (AirPods Pro 2 USB-C, AirPods Max USB-C, Beats Fit Pro) into HealthKit so the real anchored-query pipeline runs end to end. Also triggered by launch arg -seedHealth.")
        }
    }
    #endif

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
