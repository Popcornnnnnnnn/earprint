import SwiftUI

@main
struct EarprintApp: App {
    @State private var router = DeepLinkRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView(selection: $router.tab) {
                CollectionView(cards: SampleCards.all)
                    .tabItem { Label("Collection", systemImage: "rectangle.stack") }
                    .tag(DeepLinkRouter.Tab.collection)
                HomeView(summary: SampleData.summary)
                    .tabItem { Label("Rings", systemImage: "circle.hexagongrid") }
                    .tag(DeepLinkRouter.Tab.rings)
                ProbeView()
                    .tabItem { Label("Data probe", systemImage: "waveform") }
                    .tag(DeepLinkRouter.Tab.probe)
            }
            .environment(router)
            .preferredColorScheme(.dark)
            // Widgets and the Live Activity open earprint://card/<id>, earprint://rings, ...
            .onOpenURL { router.handle($0) }
            .task {
                WidgetPublisher.publishSample()
                if ProcessInfo.processInfo.arguments.contains("-startLiveActivity") {
                    let card = SampleCards.all[0]
                    LiveActivityController.shared.start(deviceName: card.nickname, symbol: card.symbol, cardID: card.id,
                                                        startedAt: Date().addingTimeInterval(-18 * 60))
                }
            }
            .onChange(of: scenePhase) { _, phase in
                // Keep widgets fresh when the user leaves the app.
                if phase == .background { WidgetPublisher.publishSample() }
            }
        }
    }
}
