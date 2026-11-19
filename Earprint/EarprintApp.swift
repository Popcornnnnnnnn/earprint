import SwiftUI

@main
struct EarprintApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                CollectionView(cards: SampleCards.all)
                    .tabItem { Label("Collection", systemImage: "rectangle.stack") }
                HomeView(summary: SampleData.summary)
                    .tabItem { Label("Rings", systemImage: "circle.hexagongrid") }
                ProbeView()
                    .tabItem { Label("Data probe", systemImage: "waveform") }
            }
            .preferredColorScheme(.dark)
        }
    }
}
