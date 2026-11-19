import SwiftUI

@main
struct EarprintApp: App {
    @State private var tab = ProcessInfo.processInfo.arguments.contains("-showShare")
        || ProcessInfo.processInfo.arguments.contains("-rings") ? 1 : 0

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                CollectionView(cards: SampleCards.all)
                    .tabItem { Label("Collection", systemImage: "rectangle.stack") }
                    .tag(0)
                HomeView(summary: SampleData.summary)
                    .tabItem { Label("Rings", systemImage: "circle.hexagongrid") }
                    .tag(1)
                ProbeView()
                    .tabItem { Label("Data probe", systemImage: "waveform") }
                    .tag(2)
            }
            .preferredColorScheme(.dark)
        }
    }
}
