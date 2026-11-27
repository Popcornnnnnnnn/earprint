#if DEBUG
import SwiftUI

/// Debug controls on the Data probe tab: Live Activity start/stop and widget snapshot publishing.
struct WidgetDebugSection: View {
    @ObservedObject var library: HeadphoneLibrary
    @Environment(DeviceLifecycleStore.self) private var lifecycleStore: DeviceLifecycleStore?
    @State private var live = LiveActivityController.shared
    @State private var published: Date?

    var body: some View {
        Section {
            if live.isRunning {
                Button {
                    live.update(decibels: Double.random(in: 55...86).rounded())
                } label: {
                    Label("Simulate new dB reading", systemImage: "waveform.badge.plus")
                }
                Button {
                    live.resetRest()
                } label: {
                    Label("Took a break (reset rest timer)", systemImage: "cup.and.saucer")
                }
                Button(role: .destructive) {
                    live.stop()
                } label: {
                    Label("Stop Live Activity", systemImage: "stop.circle")
                }
            } else {
                Button {
                    if let card = library.cards.first {
                        live.start(deviceName: card.nickname, symbol: card.symbol, cardID: card.id,
                                   startedAt: Date().addingTimeInterval(-18 * 60))
                    }
                } label: {
                    Label("Start \"Listening now\" Live Activity", systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(library.cards.isEmpty)
            }
            Button {
                let combinedSummary = library.summary(forCardID: nil)
                let snapshot: WidgetSnapshot = if let lifecycleStore {
                    WidgetSnapshot.forApp(
                        summary: combinedSummary,
                        allCards: library.cards,
                        lifecycleStore: lifecycleStore,
                        isSample: library.isShowingSampleData,
                        listening: library.snapshot
                    )
                } else {
                    WidgetSnapshot(
                        summary: combinedSummary,
                        cards: library.cards,
                        allCards: library.cards,
                        isSample: library.isShowingSampleData,
                        listening: library.snapshot
                    )
                }
                WidgetPublisher.enqueue(snapshot)
                published = Date()
            } label: {
                Label(published == nil ? "Publish widget snapshot" : "Snapshot published", systemImage: "square.grid.2x2")
            }
        } header: {
            Text("Widgets · debug")
        } footer: {
            if let error = live.lastError {
                Text(error).foregroundStyle(.red)
            } else {
                Text("Debug-only controls for testing Lock Screen / Dynamic Island sessions and App Group snapshots using current library data.")
            }
        }
    }
}
#endif
