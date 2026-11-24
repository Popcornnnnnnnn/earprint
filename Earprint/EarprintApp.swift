import SwiftUI

@main
struct EarprintApp: App {
    private struct PaywallPrompt: Identifiable {
        let id = UUID()
        let feature: ProFeature?
    }

    @StateObject private var library = HeadphoneLibrary()
    @State private var router = DeepLinkRouter()
    @State private var colorStore = DeviceColorStore()
    @State private var routeMonitor = ActiveAudioRouteMonitor()
    @State private var proStore = ProEntitlementStore()
    @State private var customizationStore = SlabCustomizationStore()
    @State private var paywallPrompt: PaywallPrompt?
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @Environment(\.scenePhase) private var scenePhase

    private var resolvedLocale: Locale {
        #if DEBUG || EARPRINT_REPEAT_CARD_HINT
        if HeadphoneLibrary.isFirstLaunchSimulation {
            return AppLanguage.systemResolved().locale
        }
        #endif
        return language.locale
    }

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
            #if DEBUG || EARPRINT_REPEAT_CARD_HINT
            let previewFirstLaunch: (() -> Void)? = { Task { await library.previewFirstLaunch() } }
            #else
            let previewFirstLaunch: (() -> Void)? = nil
            #endif

            TabView(selection: $router.tab) {
                CollectionView(
                    cards: library.cards,
                    isSampleData: library.isShowingSampleData,
                    sampleBadgeText: library.sampleBadgeText,
                    statusMessage: library.statusMessage,
                    isLoading: library.isLoading,
                    isActiveTab: router.tab == .collection,
                    onConnectHealth: { Task { await library.connectAndSync() } },
                    onPreviewFirstLaunch: previewFirstLaunch,
                    dossierForCard: { library.dossier(for: $0) }
                )
                .tabItem { Label("Collection", systemImage: "rectangle.stack") }
                .tag(DeepLinkRouter.Tab.collection)

                HomeView(
                    summary: library.summary(forCardID: nil),
                    primaryCard: library.cards.count == 1 ? library.cards.first : nil,
                    cards: library.cards,
                    summaryForCardID: { library.summary(forCardID: $0) },
                    isSampleData: library.isShowingSampleData,
                    isEmptyState: library.isShowingEmptyState,
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
            .environment(proStore)
            .environment(customizationStore)
            .environment(\.proAccess, proStore.accessSnapshot)
            .environment(\.locale, resolvedLocale)
            .preferredColorScheme(resolvedColorScheme)
            .sheet(isPresented: $library.needsHealthOnboarding) {
                HealthOnboardingView(
                    onConnect: { Task { await library.completeOnboarding(connect: true) } },
                    onSkip: { Task { await library.completeOnboarding(connect: false) } }
                )
                .environment(\.locale, resolvedLocale)
                .preferredColorScheme(resolvedColorScheme)
            }
            .sheet(item: $paywallPrompt) { prompt in
                PaywallView(store: proStore, highlightedFeature: prompt.feature)
                    .environment(\.locale, resolvedLocale)
                    .preferredColorScheme(resolvedColorScheme)
            }
            #if DEBUG
            .sheet(item: $router.developerScreen) { screen in
                DeveloperToolsView(library: library, openProbe: screen == .probe)
                    .environment(\.locale, resolvedLocale)
                    .preferredColorScheme(resolvedColorScheme)
            }
            #endif
            // Widgets and the Live Activity open earprint://card/<id>, earprint://rings, earprint://wrapped, ...
            .onOpenURL { router.handle($0) }
            .onReceive(NotificationCenter.default.publisher(for: .earprintRequestPaywall)) { note in
                let feature = note.object as? ProFeature ?? note.userInfo?["feature"] as? ProFeature
                paywallPrompt = PaywallPrompt(feature: feature)
            }
            .task {
                applyLaunchTab()
                routeMonitor.onRouteChange = { _ in
                    syncLiveActivity()
                }
                routeMonitor.refresh()
                let beforeStart = library.snapshot?.generatedAt
                await library.start()
                // Publish once if `onChange(of: library.snapshot?.generatedAt)` did not already trigger.
                if library.snapshot?.generatedAt == beforeStart {
                    publishWidgets()
                }
                syncLiveActivity()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-startLiveActivity"),
                   let card = library.cards.first {
                    LiveActivityController.shared.start(
                        deviceName: card.nickname,
                        symbol: card.symbol,
                        cardID: card.id,
                        startedAt: Date().addingTimeInterval(-18 * 60)
                    )
                }
                #endif
            }
            .onChange(of: language) { _, _ in
                library.refreshDerivedCacheIfNeeded(force: true)
            }
            .onChange(of: library.snapshot?.generatedAt) { _, _ in
                publishWidgets()
            }
            .onChange(of: library.cards.map(\.id)) { _, _ in
                syncLiveActivity()
            }
            .onChange(of: proStore.hasPro) { _, _ in
                syncLiveActivity()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    routeMonitor.refresh()
                    library.refreshDerivedCacheIfNeeded()
                    syncLiveActivity()
                }
                if phase == .background { publishWidgets() }
            }
        }
    }

    private func syncLiveActivity() {
        let weekDB = library.homeSummary.weekDecibels
        LiveActivityController.shared.syncWithActiveRoute(
            cards: library.cards,
            routeMonitor: routeMonitor,
            decibels: weekDB > 0 ? weekDB : 63,
            proUnlocked: proStore.isUnlocked(.liveActivity)
        )
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
        if args.contains("-wrapped") {
            router.tab = .rings
            router.pendingWrapped = true
        } else if args.contains("-rings") || args.contains("-showShare") {
            router.tab = .rings
        }
        if args.contains("-paywall") {
            paywallPrompt = PaywallPrompt(feature: nil)
        }
    }
}
