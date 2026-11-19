import SwiftUI

@main
struct EarprintApp: App {
    @StateObject private var library = HeadphoneLibrary()
    @State private var selectedTab: Tab = Self.initialTab

    enum Tab: String {
        case collection, rings, probe
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                CollectionView(
                    cards: library.cards,
                    isSampleData: library.isShowingSampleData,
                    sampleBadgeText: library.sampleBadgeText,
                    statusMessage: library.statusMessage,
                    isLoading: library.isLoading,
                    onConnectHealth: { Task { await library.connectAndSync() } }
                )
                .tabItem { Label("Collection", systemImage: "rectangle.stack") }
                .tag(Tab.collection)

                HomeView(
                    summary: library.homeSummary,
                    isSampleData: library.isShowingSampleData,
                    sampleBadgeText: library.sampleBadgeText,
                    statusMessage: library.statusMessage,
                    isLoading: library.isLoading,
                    onConnectHealth: { Task { await library.connectAndSync() } }
                )
                .tabItem { Label("Rings", systemImage: "circle.hexagongrid") }
                .tag(Tab.rings)

                ProbeView(library: library)
                    .tabItem { Label("Data probe", systemImage: "waveform") }
                    .tag(Tab.probe)
            }
            .preferredColorScheme(.dark)
            .task { await library.start() }
        }
    }

    private static var initialTab: Tab {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-tab"), idx + 1 < args.count,
           let tab = Tab(rawValue: args[idx + 1].lowercased()) {
            return tab
        }
        if args.contains("-showShare") { return .rings }
        return .collection
    }
}
