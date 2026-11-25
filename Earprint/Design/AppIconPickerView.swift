import SwiftUI
import UIKit

/// Background style for the Earprint Home Screen icon (independent of headphone finish).
enum IconBackground: String, CaseIterable, Identifiable, Equatable {
    case auto
    case light
    case dark
    case holo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        case .holo: return "Holo"
        }
    }

    var assetSuffix: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        case .holo: return "Holo"
        }
    }
}

/// All 10 official Apple AirPods Max retail finishes (2024 USB-C & 2020 Lightning).
enum IconFinish: String, CaseIterable, Identifiable, Equatable {
    // 2024 USB-C
    case midnight
    case starlight
    case blue
    case purple
    case orange
    // 2020 Lightning
    case spaceGray
    case silver
    case skyBlue
    case green
    case pink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight: return "Midnight"
        case .starlight: return "Starlight"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .spaceGray: return "Space Gray"
        case .silver: return "Silver"
        case .skyBlue: return "Sky Blue"
        case .green: return "Green"
        case .pink: return "Pink"
        }
    }

    var assetSuffix: String {
        switch self {
        case .midnight: return "Midnight"
        case .starlight: return "Starlight"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .spaceGray: return "SpaceGray"
        case .silver: return "Silver"
        case .skyBlue: return "SkyBlue"
        case .green: return "Green"
        case .pink: return "Pink"
        }
    }

    var cutoutAssetName: String { "IconCutout\(assetSuffix)" }

    /// Two-tone metallic hardware swatch colors matching Apple's anodized earcups + cushions.
    var swatchColors: (top: Color, bottom: Color) {
        switch self {
        case .midnight:  return (Color(red: 0.16, green: 0.19, blue: 0.25), Color(red: 0.08, green: 0.10, blue: 0.14))
        case .starlight: return (Color(red: 0.90, green: 0.86, blue: 0.78), Color(red: 0.78, green: 0.74, blue: 0.65))
        case .blue:      return (Color(red: 0.34, green: 0.47, blue: 0.62), Color(red: 0.22, green: 0.32, blue: 0.45))
        case .purple:    return (Color(red: 0.76, green: 0.66, blue: 0.80), Color(red: 0.56, green: 0.46, blue: 0.60))
        case .orange:    return (Color(red: 0.94, green: 0.54, blue: 0.36), Color(red: 0.82, green: 0.38, blue: 0.22))
        case .spaceGray: return (Color(red: 0.46, green: 0.47, blue: 0.50), Color(red: 0.27, green: 0.28, blue: 0.30))
        case .silver:    return (Color(red: 0.92, green: 0.93, blue: 0.95), Color(red: 0.75, green: 0.77, blue: 0.80))
        case .skyBlue:   return (Color(red: 0.66, green: 0.79, blue: 0.88), Color(red: 0.48, green: 0.62, blue: 0.74))
        case .green:     return (Color(red: 0.73, green: 0.82, blue: 0.70), Color(red: 0.55, green: 0.65, blue: 0.53))
        case .pink:      return (Color(red: 0.92, green: 0.51, blue: 0.48), Color(red: 0.78, green: 0.36, blue: 0.34))
        }
    }

    static let usbcFinishes: [IconFinish] = [.midnight, .starlight, .blue, .purple, .orange]
    static let lightningFinishes: [IconFinish] = [.spaceGray, .silver, .skyBlue, .green, .pink]
}

/// Complete Home Screen icon choice: either the default trademark-safe Earprint Rings emblem
/// or one of the 40 alternate headphone finish/background icons.
enum AppIconChoice: Equatable, Hashable {
    case ringsEmblem
    case headphone(finish: IconFinish, background: IconBackground)

    static let `default`: Self = .ringsEmblem

    var finish: IconFinish {
        if case .headphone(let finish, _) = self { return finish }
        return .midnight
    }

    var background: IconBackground {
        if case .headphone(_, let background) = self { return background }
        return .auto
    }

    /// `.appiconset` name passed to `UIApplication.setAlternateIconName(_:)`.
    /// `nil` selects the primary `AppIcon` (Earprint Rings emblem).
    var alternateIconName: String? {
        switch self {
        case .ringsEmblem:
            return nil
        case .headphone(let finish, let background):
            return "AppIcon\(finish.assetSuffix)\(background.assetSuffix)"
        }
    }

    static var allChoices: [AppIconChoice] {
        [.ringsEmblem] + IconFinish.allCases.flatMap { finish in
            IconBackground.allCases.map { bg in
                .headphone(finish: finish, background: bg)
            }
        }
    }

    static func from(alternateIconName: String?) -> AppIconChoice {
        guard let name = alternateIconName else { return .default }
        return allChoices.first { $0.alternateIconName == name } ?? .default
    }
}

@MainActor
@Observable
final class AppIconManager {
    private(set) var current: AppIconChoice
    private(set) var isUpdating = false
    var errorMessage: String?

    init() {
        self.current = AppIconChoice.from(alternateIconName: UIApplication.shared.alternateIconName)
    }

    func refresh() {
        current = AppIconChoice.from(alternateIconName: UIApplication.shared.alternateIconName)
    }

    func apply(_ choice: AppIconChoice) async -> Bool {
        guard !isUpdating else { return false }
        errorMessage = nil
        guard choice != current else { return true }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "Alternate app icons are unavailable on this device."
            return false
        }

        isUpdating = true
        defer { isUpdating = false }

        do {
            try await UIApplication.shared.setAlternateIconName(choice.alternateIconName)
            current = choice
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// Live composited squircle preview of any `(IconFinish, IconBackground)` pair.
struct AppIconThumbnail: View {
    let finish: IconFinish
    let background: IconBackground
    var size: CGFloat = 64

    init(choice: AppIconChoice, size: CGFloat = 64) {
        self.finish = choice.finish
        self.background = choice.background
        self.size = size
    }

    init(finish: IconFinish, background: IconBackground, size: CGFloat = 64) {
        self.finish = finish
        self.background = background
        self.size = size
    }

    private var cornerRadius: CGFloat { size * 0.2237 }

    var body: some View {
        ZStack {
            backgroundFill
            Image(finish.cutoutAssetName)
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(background == .dark ? 0.45 : 0.22), radius: size * 0.04, y: size * 0.03)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(background == .light ? Color.black.opacity(0.14) : .white.opacity(0.14), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var backgroundFill: some View {
        switch background {
        case .light:
            Color(red: 0.96, green: 0.96, blue: 0.97)
        case .dark:
            RadialGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.14), Color(red: 0.04, green: 0.04, blue: 0.06)],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.72
            )
        case .holo:
            LinearGradient(
                colors: [
                    Color(red: 0.71, green: 0.70, blue: 0.97),
                    Color(red: 0.60, green: 0.88, blue: 0.96),
                    Color(red: 0.69, green: 0.94, blue: 0.87),
                    Color(red: 0.97, green: 0.91, blue: 0.73),
                    Color(red: 0.96, green: 0.73, blue: 0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .auto:
            ZStack {
                Color(red: 0.96, green: 0.96, blue: 0.97)
                Color(red: 0.06, green: 0.07, blue: 0.09)
                    .mask(DiagonalBottomRightTriangle())
            }
        }
    }
}

private struct DiagonalBottomRightTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let storageKey = "appLanguage"

    /// Resolves the highest-priority supported language from a preferred language list.
    static func systemResolved(preferredLanguages: [String] = Locale.preferredLanguages) -> Self {
        for id in preferredLanguages {
            let lower = id.lowercased()
            if lower.hasPrefix("zh") { return .simplifiedChinese }
            if lower.hasPrefix("en") { return .english }
        }
        return .english
    }

    static var systemDefault: Self { .system }

    static var stored: Self {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    /// Effective concrete language (`.english` or `.simplifiedChinese`), never `.system`.
    static var current: Self {
        #if DEBUG || EARPRINT_REPEAT_CARD_HINT
        if HeadphoneLibrary.isFirstLaunchSimulation {
            return systemResolved()
        }
        #endif
        return stored.resolved
    }

    var resolved: Self {
        self == .system ? Self.systemResolved() : self
    }

    private static let cachedBundles: [AppLanguage: Bundle] = {
        var result: [AppLanguage: Bundle] = [:]
        for lang in [AppLanguage.english, .simplifiedChinese] {
            if let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                result[lang] = bundle
            }
        }
        return result
    }()

    private static let cachedLocales: [AppLanguage: Locale] = [
        .english: Locale(identifier: AppLanguage.english.rawValue),
        .simplifiedChinese: Locale(identifier: AppLanguage.simplifiedChinese.rawValue)
    ]

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        let target = resolved
        let template = Self.cachedBundles[target]?.localizedString(forKey: key, value: nil, table: nil) ?? key
        return arguments.isEmpty ? template : String(format: template, locale: target.locale, arguments: arguments)
    }

    var id: String { rawValue }
    var locale: Locale {
        let target = resolved
        return Self.cachedLocales[target] ?? Locale(identifier: target.rawValue)
    }
    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
    var name: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

struct SettingsView: View {
    private enum Destination: Hashable {
        case appIcon
        case modelGallery
        case cardTiers
        case tipJar
        case privacy
        case credits
    }

    private struct PaywallRequest: Identifiable {
        let id = UUID()
        let feature: ProFeature?
    }

    let ownedCards: [HeadphoneCard]
    var onConnectHealth: (() -> Void)? = nil
    var onPreviewFirstLaunch: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.proAccess) private var proAccess
    @Environment(ProEntitlementStore.self) private var proStore: ProEntitlementStore?
    @Environment(ActiveAudioRouteMonitor.self) private var routeMonitor: ActiveAudioRouteMonitor?
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system
    @State private var iconManager = AppIconManager()
    @State private var liveController = LiveActivityController.shared
    @State private var path: [Destination]
    @State private var paywallRequest: PaywallRequest?
    @State private var archiveFile: ArchiveExportFile?
    @State private var archiveTempDirectory: URL?
    @State private var archiveExportTask: Task<Void, Never>?
    @State private var archiveError: LocalizedStringKey?
    @State private var isExportingArchive = false

    init(
        ownedCards: [HeadphoneCard] = [],
        openIconPicker: Bool = false,
        onConnectHealth: (() -> Void)? = nil,
        onPreviewFirstLaunch: (() -> Void)? = nil
    ) {
        self.ownedCards = ownedCards
        self.onConnectHealth = onConnectHealth
        self.onPreviewFirstLaunch = onPreviewFirstLaunch
        _path = State(initialValue: openIconPicker ? [.appIcon] : [])
    }

    private var unlockedCount: Int {
        ModelGalleryCatalog.unlockedCount(for: ownedCards)
    }

    private var totalCatalogModels: Int {
        ModelGalleryCatalog.allAppleAndBeatsCount
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    Picker(selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.secondaryText)

                    NavigationLink(value: Destination.appIcon) {
                        HStack(spacing: 12) {
                            Label("App Icon", systemImage: "app")
                            Spacer()
                            Group {
                                if iconManager.current == .ringsEmblem {
                                    Image("AppIconDefaultPreview")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 26, height: 26)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
                                } else {
                                    AppIconThumbnail(choice: iconManager.current, size: 26)
                                }
                            }
                            .accessibilityHidden(true)
                        }
                    }

                    Picker(selection: $language) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                    .pickerStyle(.navigationLink)
                }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink(value: Destination.modelGallery) {
                        HStack {
                            Label("Model Gallery", systemImage: "cube.transparent")
                            Spacer()
                            Text("\(unlockedCount)/\(totalCatalogModels)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    NavigationLink(value: Destination.cardTiers) {
                        Label("Card Tiers", systemImage: "trophy")
                    }
                }
                .listRowBackground(Theme.card)

                Section(EarprintReleasePolicy.monetizationEnabled ? "Earprint Pro" : "Session & Archive") {
                    if EarprintReleasePolicy.monetizationEnabled, proStore != nil {
                        Button {
                            paywallRequest = PaywallRequest(feature: nil)
                        } label: {
                            HStack {
                                Label("Earprint Pro", systemImage: "sparkles")
                                Spacer()
                                Text(proAccess.hasPro ? "Unlocked" : "Collector Edition")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }

                        NavigationLink(value: Destination.tipJar) {
                            Label("Tip Jar", systemImage: "heart")
                        }
                    }

                    Picker(selection: $liveController.restIntervalMinutes) {
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    } label: {
                        Label("Rest Reminder", systemImage: "timer")
                    }
                    .tint(Theme.secondaryText)

                    Button {
                        toggleLiveSession()
                    } label: {
                        HStack {
                            Label(
                                liveController.isRunning ? "Stop Listening Session" : "Live Listening Session",
                                systemImage: liveController.isRunning ? "stop.circle" : "dot.radiowaves.left.and.right"
                            )
                            Spacer()
                            if liveController.isRunning {
                                Circle()
                                    .fill(Theme.quietColor)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .foregroundStyle(Theme.primaryText)
                    }

                    Menu {
                        Button("Export CSV") { exportArchive(.csv) }
                        Button("Export JSON") { exportArchive(.json) }
                    } label: {
                        HStack {
                            Label("Export Archive", systemImage: "archivebox")
                            Spacer()
                            if isExportingArchive {
                                ProgressView()
                                    .tint(Theme.primaryText)
                            }
                        }
                        .foregroundStyle(Theme.primaryText)
                    }
                    .disabled(isExportingArchive)

                    if let archiveError {
                        Text(archiveError)
                            .font(.caption)
                            .foregroundStyle(Theme.loudColor)
                    }
                    if let liveError = liveController.lastError {
                        Text(liveError)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink(value: Destination.privacy) {
                        Label("Apple Health Privacy", systemImage: "hand.raised.fill")
                    }
                    NavigationLink(value: Destination.credits) {
                        Label("Credits & Attributions", systemImage: "doc.text")
                    }
                    if let onConnectHealth {
                        Button {
                            dismiss()
                            onConnectHealth()
                        } label: {
                            Label("Sync Apple Health", systemImage: "arrow.trianglehead.2.clockwise")
                                .foregroundStyle(Theme.primaryText)
                        }
                    }
                    if let onPreviewFirstLaunch {
                        Button {
                            dismiss()
                            onPreviewFirstLaunch()
                        } label: {
                            Label("Preview First Launch", systemImage: "sparkles.rectangle.stack")
                                .foregroundStyle(Theme.primaryText)
                        }
                    }
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .foregroundStyle(Theme.primaryText)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .appIcon:
                    AppIconPickerView(manager: iconManager)
                case .modelGallery:
                    ModelGalleryView(ownedCards: ownedCards)
                case .cardTiers:
                    CardTiersView(ownedCards: ownedCards)
                case .tipJar:
                    if let proStore {
                        TipJarView(store: proStore)
                    }
                case .privacy:
                    PrivacyPolicyView()
                case .credits:
                    CreditsView()
                }
            }
        }
        .interactiveDismissDisabled(iconManager.isUpdating)
        .onDisappear {
            archiveExportTask?.cancel()
            archiveExportTask = nil
            if archiveFile == nil {
                clearArchiveFile()
            }
        }
        .sheet(item: $paywallRequest) { request in
            if let proStore {
                PaywallView(store: proStore, highlightedFeature: request.feature)
                    .environment(\.locale, locale)
                    .preferredColorScheme(colorScheme)
            }
        }
        .sheet(item: $archiveFile, onDismiss: clearArchiveFile) { file in
            SettingsArchiveActivitySheet(url: file.url)
        }
    }

    private func toggleLiveSession() {
        if liveController.isRunning {
            liveController.stop(manual: true)
            return
        }
        guard proAccess.isUnlocked(.liveActivity) else {
            paywallRequest = PaywallRequest(feature: .liveActivity)
            return
        }
        if let active = routeMonitor?.activeMatchedCard(in: ownedCards) ?? ownedCards.first {
            let db = active.averageDecibels > 0 ? active.averageDecibels : 0
            liveController.start(card: active, decibels: db, manual: true)
        } else {
            liveController.start(deviceName: String(localized: "Headphones"), symbol: "headphones", cardID: "headphones", decibels: 0, manual: true)
        }
    }

    private func exportArchive(_ format: ArchiveExporter.Format) {
        guard proAccess.isUnlocked(.archiveExport) else {
            paywallRequest = PaywallRequest(feature: .archiveExport)
            return
        }
        guard !isExportingArchive else { return }
        archiveExportTask?.cancel()
        archiveError = nil
        isExportingArchive = true
        let cards = ownedCards
        archiveExportTask = Task {
            defer {
                isExportingArchive = false
                archiveExportTask = nil
            }
            let cached = await Task.detached(priority: .userInitiated) {
                AggregateCache().load()?.aggregate
            }.value
            guard !Task.isCancelled else { return }
            guard let aggregate = cached, !aggregate.isEmpty else {
                archiveError = "No Apple Health listening history cached yet."
                return
            }
            do {
                let file = try await Task.detached(priority: .userInitiated) {
                    try ArchiveExporter.export(format, aggregate: aggregate, cards: cards)
                }.value
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent())
                    return
                }
                clearArchiveFile()
                archiveTempDirectory = file.url.deletingLastPathComponent()
                archiveFile = file
            } catch {
                if !Task.isCancelled {
                    archiveError = "Export failed"
                }
            }
        }
    }

    private func clearArchiveFile() {
        if let dir = archiveTempDirectory {
            try? FileManager.default.removeItem(at: dir)
            archiveTempDirectory = nil
        }
        archiveFile = nil
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                privacyRow(
                    icon: "heart.text.square.fill",
                    tint: Theme.loudColor,
                    title: "Read-only Apple Health access",
                    detail: "Earprint reads your Headphone Audio Exposure samples solely to build your cards, tiers, and listening rings."
                )
                privacyRow(
                    icon: "iphone",
                    tint: Theme.quietColor,
                    title: "Stays on your iPhone",
                    detail: "All aggregation happens locally. There is no account, no cloud upload, no ads, and no analytics tracking."
                )
                privacyRow(
                    icon: "square.and.arrow.up",
                    tint: Theme.moderateColor,
                    title: "You control sharing",
                    detail: "Only exported posters, Wrapped reels, and listening archives leave the app when you tap Share. Manage Health permission anytime in iOS Settings › Health."
                )
            }
            .padding(16)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("Apple Health Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyRow(icon: String, tint: Color, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}

struct CreditsView: View {
    private struct ModelCredit: Identifiable {
        let id: String
        let title: String
        let author: String
        let authorURL: URL
        let modelURL: URL
        let note: LocalizedStringKey
    }

    private static let licenseURL = URL(string: "https://creativecommons.org/licenses/by/4.0/")!

    private static let models: [ModelCredit] = [
        ModelCredit(
            id: "airpods4",
            title: "AirPods 4",
            author: "Falah3D (3dFalah)",
            authorURL: URL(string: "https://sketchfab.com/3dFalah")!,
            modelURL: URL(string: "https://sketchfab.com/3d-models/airpods-4-e44730974131402eb496352cab19c82e")!,
            note: "Modified: cropped front render; simplified geometry to ~45k tris, normalized, converted to USDZ, compressed textures (source FBX provenance via Andrea Balbo)."
        ),
        ModelCredit(
            id: "airpodsMax",
            title: "Airpods max sky blue",
            author: "polyman Studio (Polyman_3D)",
            authorURL: URL(string: "https://sketchfab.com/Polyman_3D")!,
            modelURL: URL(string: "https://sketchfab.com/3d-models/airpods-max-sky-blue-3d0643db08fc4ef89bda55a74077ece4")!,
            note: "Modified: simplified to ~42k tris, joined meshes, normalized, baked PBR factors, compressed textures, converted to USDZ."
        ),
        ModelCredit(
            id: "airpodsPro",
            title: "Airpods Pro With Magsafe Charging Case Ios15",
            author: "polyman Studio (Polyman_3D)",
            authorURL: URL(string: "https://sketchfab.com/Polyman_3D")!,
            modelURL: URL(string: "https://sketchfab.com/3d-models/airpods-pro-with-magsafe-charging-case-ios15-52e5f28b37f94f05b6c0768773137689")!,
            note: "Modified: removed internal occlusion shell, simplified to ~48k tris, joined meshes, normalized, compressed textures, converted to USDZ."
        ),
        ModelCredit(
            id: "studioHeadphones",
            title: "Studio Headphones",
            author: "crow (crow.bite)",
            authorURL: URL(string: "https://sketchfab.com/crow.bite")!,
            modelURL: URL(string: "https://sketchfab.com/3d-models/studio-headphones-2f04830fbf884632a89445db0d170ba8")!,
            note: "Modified: simplified to ~52k tris, joined meshes, normalized, baked roughness map, compressed textures, converted to USDZ."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Independent App Notice")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Not affiliated with Apple Inc.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text("Earprint is an independent app and is not affiliated with, sponsored by, or endorsed by Apple Inc. Apple, Apple Health, AirPods, AirPods Pro, AirPods Max, and Beats are trademarks of Apple Inc.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Listening rings, WHO weekly budgets, and Ear Grade scores are for personal informational purposes only and are not a medical device.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                sectionHeader("3D Models & Artwork (CC-BY 4.0)")
                    .padding(.top, 4)

                ForEach(Self.models) { model in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(model.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            Spacer(minLength: 8)
                            Link("CC-BY 4.0", destination: Self.licenseURL)
                                .font(.caption2.weight(.semibold))
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 14) {
                                Link(destination: model.authorURL) {
                                    HStack(spacing: 3) {
                                        Text(model.author)
                                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                                    }
                                }
                                Link(destination: model.modelURL) {
                                    HStack(spacing: 3) {
                                        Text("Source on Sketchfab")
                                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                                    }
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Link(destination: model.authorURL) {
                                    HStack(spacing: 3) {
                                        Text(model.author)
                                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                                    }
                                }
                                Link(destination: model.modelURL) {
                                    HStack(spacing: 3) {
                                        Text("Source on Sketchfab")
                                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                                    }
                                }
                            }
                        }
                        .font(.caption.weight(.medium))

                        Text(model.note)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
            }
            .padding(16)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("Credits & Attributions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.secondaryText)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

/// One-screen pre-permission introduction explaining why Earprint reads Apple Health headphone audio exposure.
struct HealthOnboardingView: View {
    let onConnect: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 10)

                    VStack(spacing: 14) {
                        ZStack {
                            EarprintGlyph(grid: SampleData.summary.grid, showHourLabels: false)
                                .equatable()
                                .frame(width: 112, height: 112)
                                .opacity(0.65)
                            Circle()
                                .fill(Theme.card)
                                .frame(width: 58, height: 58)
                                .shadow(color: Theme.cardShadow, radius: 8, y: 3)
                            HeadphoneArtwork(card: SampleCards.all[0], showsChargingCase: false, showsShadow: false)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityHidden(true)

                        Text("Your Headphone Archive")
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.primaryText)
                            .multilineTextAlignment(.center)

                        Text("Turn your listening history into collector cards and 28-day Earprint rings.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    VStack(spacing: 12) {
                        bullet(icon: "waveform.path.ecg", tint: Theme.quietColor,
                               title: "Read-only Health data",
                               subtitle: "Uses Apple Health headphone audio exposure minutes and dB levels.")
                        bullet(icon: "lock.shield.fill", tint: Theme.moderateColor,
                               title: "Private by design",
                               subtitle: "Processed on your iPhone with no account, cloud servers, or tracking.")
                        bullet(icon: "sparkles", tint: Theme.loudColor,
                               title: "6 metallic card tiers",
                               subtitle: "Every pair levels up from Bronze Slate (0h) to Liquid Holo (2,000h).")
                    }
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
                    .shadow(color: Theme.cardShadow, radius: 12, y: 4)

                    Spacer(minLength: 8)

                    VStack(spacing: 8) {
                        Button(action: onConnect) {
                            Label("Connect Apple Health", systemImage: "heart.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Theme.invertedFill, in: Capsule())
                                .foregroundStyle(Theme.invertedText)
                        }
                        .buttonStyle(.plain)

                        Button(action: onSkip) {
                            Text("Not Now")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(22)
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func bullet(icon: String, tint: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

struct AppIconPickerView: View {
    @Bindable var manager: AppIconManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft: AppIconChoice
    @State private var selectedFinish: IconFinish
    @State private var selectedBackground: IconBackground

    init(manager: AppIconManager) {
        self.manager = manager
        let initial = manager.current
        _draft = State(initialValue: initial)
        _selectedFinish = State(initialValue: initial.finish)
        _selectedBackground = State(initialValue: initial.background)
    }

    private let fiveColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                heroPreview
                defaultSection
                backgroundSection
                finishSection
                if let error = manager.errorMessage {
                    Text(LocalizedStringKey(error))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(Theme.canvasElevated.ignoresSafeArea())
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(manager.isUpdating)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    Task {
                        if await manager.apply(draft) { dismiss() }
                    }
                }
                .disabled(manager.isUpdating || draft == manager.current)
            }
        }
        .disabled(manager.isUpdating)
        .onAppear {
            manager.refresh()
            manager.errorMessage = nil
            draft = manager.current
            selectedFinish = manager.current.finish
            selectedBackground = manager.current.background
        }
    }

    private var heroPreview: some View {
        VStack(spacing: 10) {
            Group {
                if draft == .ringsEmblem {
                    Image("AppIconDefaultPreview")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 92 * 0.2237, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 92 * 0.2237, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                } else {
                    AppIconThumbnail(choice: draft, size: 92)
                }
            }
            .shadow(color: Theme.cardShadow, radius: 14, y: 6)

            Text("Earprint")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardStroke, lineWidth: 1))
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }

    private var defaultSection: some View {
        let isSelected = draft == .ringsEmblem
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Default Icon")
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                draft = .ringsEmblem
            } label: {
                HStack(spacing: 14) {
                    Image("AppIconDefaultPreview")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12.5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12.5, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Earprint Studio")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("Brushed titanium · Default")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Theme.quietColor : Theme.tertiaryText)
                }
                .padding(12)
                .background(isSelected ? Theme.surfaceFillStrong : Theme.surfaceFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Theme.primaryText.opacity(0.56) : Theme.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Background")
            HStack(spacing: 8) {
                ForEach(IconBackground.allCases) { background in
                    let isSelected = draft == .headphone(finish: selectedFinish, background: background)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedBackground = background
                        draft = .headphone(finish: selectedFinish, background: background)
                    } label: {
                        VStack(spacing: 8) {
                            AppIconThumbnail(finish: selectedFinish, background: background, size: 42)
                            Text(LocalizedStringKey(background.title))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Theme.surfaceFillStrong : Theme.surfaceFill, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Theme.primaryText.opacity(0.56) : Theme.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Setting 2: Headphone Finish

    private var finishSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("AirPods Max Color", detail: "USB-C")
            LazyVGrid(columns: fiveColumns, spacing: 12) {
                ForEach(IconFinish.usbcFinishes) { finish in
                    finishSwatch(finish)
                }
            }

            sectionTitle("Classic Finishes", detail: "Lightning")
                .padding(.top, 2)
            LazyVGrid(columns: fiveColumns, spacing: 12) {
                ForEach(IconFinish.lightningFinishes) { finish in
                    finishSwatch(finish)
                }
            }
        }
    }

    private func finishSwatch(_ finish: IconFinish) -> some View {
        let isSelected: Bool = {
            if case .headphone(let f, _) = draft { return f == finish }
            return false
        }()
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedFinish = finish
            draft = .headphone(finish: finish, background: selectedBackground)
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    if isSelected {
                        Circle()
                            .strokeBorder(Theme.primaryText, lineWidth: 2)
                            .frame(width: 48, height: 48)
                    }
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [finish.swatchColors.top, finish.swatchColors.bottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                        .shadow(color: Theme.cardShadow, radius: 4, y: 2)
                }
                .frame(width: 50, height: 50)

                Text(LocalizedStringKey(finish.title))
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Theme.primaryText : Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(finish.title)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sectionTitle(_ title: LocalizedStringKey, detail: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

private struct SettingsArchiveActivitySheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
