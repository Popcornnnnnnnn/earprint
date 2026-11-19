import SwiftUI

@main
struct EarprintApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView(summary: SampleData.summary)
                    .tabItem { Label("Earprint", systemImage: "circle.hexagongrid") }
                ProbeView()
                    .tabItem { Label("Data probe", systemImage: "waveform") }
            }
            .preferredColorScheme(.dark)
        }
    }
}
