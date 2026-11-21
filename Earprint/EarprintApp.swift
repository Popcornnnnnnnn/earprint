import SwiftUI

@main
struct EarprintApp: App {
    @StateObject private var library = HeadphoneLibrary()
    @State private var router = DeepLinkRouter()
    @State private var colorStore = DeviceColorStore()
    @State private var routeMonitor = ActiveAudioRouteMonitor()
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.systemDefault
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @Environment(\.scenePhase) private var scenePhase

    private var resolvedColorScheme: ColorScheme? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-appearance"), idx + 1 < args.count {
            switch args[idx + 1].lowercased() {
            case "light": return .light
            case "dark": return .dark
            default: break
            }
        }
        #endif
        return appearance.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $router.tab) {
                CollectionView(
                    cards: library.cards,
                    isSampleData: library.isShowingSampleData,
                    sampleBadgeText: library.sampleBadgeText,
                    statusMessage: library.statusMessage,
                    isLoading: library.isLoading,
                    isActiveTab: router.tab == .collection,
                    onConnectHealth: { Task { await library.connectAndSync() } }
                )
                .tabItem { Label("Collection", systemImage: "rectangle.stack") }
                .tag(DeepLinkRouter.Tab.collection)

                HomeView(
                    summary: library.summary(forCardID: nil),
                    primaryCard: library.cards.count == 1 ? library.cards.first : nil,
                    cards: library.cards,
                    summaryForCardID: { library.summary(forCardID: $0) },
                    isSampleData: library.isShowingSampleData,
                    sampleBadgeText: library.sampleBadgeText,
                    statusMessage: library.state == .idle ? nil : library.statusMessage,
                    isLoading: library.isLoading,
                    isActiveTab: router.tab == .rings,
                    onConnectHealth: { Task { await library.connectAndSync() } }
                )
                .tabItem { Label("Rings", systemImage: "circle.hexagongrid") }
                .tag(DeepLinkRouter.Tab.rings)
            }
            .environment(router)
            .environment(colorStore)
            .environment(routeMonitor)
            .environment(\.locale, language.locale)
            .preferredColorScheme(resolvedColorScheme)
            .sheet(isPresented: $library.needsHealthOnboarding) {
                HealthOnboardingView(
                    onConnect: { Task { await library.completeOnboarding(connect: true) } },
                    onSkip: { Task { await library.completeOnboarding(connect: false) } }
                )
            }
            #if DEBUG
            .sheet(item: $router.developerScreen) { screen in
                DeveloperToolsView(library: library, openProbe: screen == .probe)
            }
            #endif
            // Widgets and the Live Activity open earprint://card/<id>, earprint://rings, ...
            .onOpenURL { router.handle($0) }
            .task {
                applyLaunchTab()
                routeMonitor.refresh()
                let beforeStart = library.snapshot?.generatedAt
                await library.start()
                // Publish once if `onChange(of: library.snapshot?.generatedAt)` did not already trigger.
                if library.snapshot?.generatedAt == beforeStart {
                    publishWidgets()
                }
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
            .onChange(of: language) { _, _ in
                library.refreshDerivedCacheIfNeeded(force: true)
            }
            .onChange(of: library.snapshot?.generatedAt) { _, _ in
                publishWidgets()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    routeMonitor.refresh()
                    library.refreshDerivedCacheIfNeeded()
                }
                if phase == .background { publishWidgets() }
            }
        }
    }

    private func publishWidgets() {
        let summary = library.homeSummary
        let cards = library.cards
        let isSample = library.isShowingSampleData
        let listening = library.snapshot
        Task.detached(priority: .utility) {
            let snapshot = WidgetSnapshot(
                summary: summary,
                cards: cards,
                isSample: isSample,
                listening: listening
            )
            WidgetPublisher.publish(snapshot)
        }
    }

    private func applyLaunchTab() {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-tab"), idx + 1 < args.count {
            switch args[idx + 1].lowercased() {
            case "collection": router.tab = .collection
            case "rings": router.tab = .rings
            #if DEBUG
            case "probe": router.developerScreen = .probe
            #endif
            default: break
            }
            return
        }
        if args.contains("-rings") || args.contains("-showShare") {
            router.tab = .rings
        }
    }
}
