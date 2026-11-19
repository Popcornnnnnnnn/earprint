import SwiftUI

@main
struct EarprintApp: App {
    @StateObject private var library = HeadphoneLibrary()
    @State private var router = DeepLinkRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView(selection: $router.tab) {
                CollectionView(
                    cards: library.cards,
                    isSampleData: library.isShowingSampleData,
                    sampleBadgeText: library.sampleBadgeText,
                    statusMessage: library.statusMessage,
                    isLoading: library.isLoading,
                    onConnectHealth: { Task { await library.connectAndSync() } }
                )
                .tabItem { Label("Collection", systemImage: "rectangle.stack") }
                .tag(DeepLinkRouter.Tab.collection)

                HomeView(
                    summary: library.homeSummary,
                    isSampleData: library.isShowingSampleData,
                    sampleBadgeText: library.sampleBadgeText,
                    statusMessage: library.statusMessage,
                    isLoading: library.isLoading,
                    onConnectHealth: { Task { await library.connectAndSync() } }
                )
                .tabItem { Label("Rings", systemImage: "circle.hexagongrid") }
                .tag(DeepLinkRouter.Tab.rings)

                ProbeView(library: library)
                    .tabItem { Label("Data probe", systemImage: "waveform") }
                    .tag(DeepLinkRouter.Tab.probe)
            }
            .environment(router)
            .preferredColorScheme(.dark)
            // Widgets and the Live Activity open earprint://card/<id>, earprint://rings, ...
            .onOpenURL { router.handle($0) }
            .task {
                applyLaunchTab()
                publishWidgets()
                await library.start()
                publishWidgets()
                if ProcessInfo.processInfo.arguments.contains("-startLiveActivity"),
                   let card = library.cards.first {
                    LiveActivityController.shared.start(
                        deviceName: card.nickname,
                        symbol: card.symbol,
                        cardID: card.id,
                        startedAt: Date().addingTimeInterval(-18 * 60)
                    )
                }
            }
            .onChange(of: library.cards) { _, _ in
                publishWidgets()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { publishWidgets() }
            }
        }
    }

    private func publishWidgets() {
        let snapshot = WidgetSnapshot(
            summary: library.homeSummary,
            cards: library.cards,
            isSample: library.isShowingSampleData
        )
        WidgetPublisher.publish(snapshot)
    }

    private func applyLaunchTab() {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-tab"), idx + 1 < args.count {
            switch args[idx + 1].lowercased() {
            case "collection": router.tab = .collection
            case "rings": router.tab = .rings
            case "probe": router.tab = .probe
            default: break
            }
            return
        }
        if args.contains("-rings") || args.contains("-showShare") {
            router.tab = .rings
        }
    }
}
