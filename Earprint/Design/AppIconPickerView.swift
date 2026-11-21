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

/// Complete Home Screen icon choice combining an independent finish and background.
struct AppIconChoice: Equatable, Hashable {
    var finish: IconFinish
    var background: IconBackground

    static let `default` = AppIconChoice(finish: .midnight, background: .auto)

    /// `.appiconset` name passed to `UIApplication.setAlternateIconName(_:)`.
    /// `nil` selects the primary `AppIcon` (Midnight + Auto Light/Dark).
    var alternateIconName: String? {
        if self == .default { return nil }
        return "AppIcon\(finish.assetSuffix)\(background.assetSuffix)"
    }

    static var allChoices: [AppIconChoice] {
        IconFinish.allCases.flatMap { finish in
            IconBackground.allCases.map { bg in
                AppIconChoice(finish: finish, background: bg)
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
                .strokeBorder(.white.opacity(background == .light ? 0.25 : 0.14), lineWidth: 1)
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
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let storageKey = "appLanguage"
    static var systemDefault: Self {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .simplifiedChinese : .english
    }
    static var current: Self {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? systemDefault
    }

    private static let cachedBundles: [AppLanguage: Bundle] = {
        var result: [AppLanguage: Bundle] = [:]
        for lang in AppLanguage.allCases {
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
        let template = Self.cachedBundles[self]?.localizedString(forKey: key, value: nil, table: nil) ?? key
        return arguments.isEmpty ? template : String(format: template, locale: locale, arguments: arguments)
    }

    var id: String { rawValue }
    var locale: Locale { Self.cachedLocales[self] ?? Locale(identifier: rawValue) }
    var name: String { self == .english ? "English" : "简体中文" }
}

struct SettingsView: View {
    private enum Destination: Hashable {
        case appIcon
        case modelGallery
        case cardTiers
        case privacy
    }

    let ownedCards: [HeadphoneCard]
    var onConnectHealth: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.systemDefault
    @State private var iconManager = AppIconManager()
    @State private var path: [Destination]

    init(ownedCards: [HeadphoneCard] = [], openIconPicker: Bool = false, onConnectHealth: (() -> Void)? = nil) {
        self.ownedCards = ownedCards
        self.onConnectHealth = onConnectHealth
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

                    NavigationLink(value: Destination.appIcon) {
                        Label("App Icon", systemImage: "app")
                    }

                    Picker(selection: $language) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.name).tag(option)
                        }
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    NavigationLink(value: Destination.modelGallery) {
                        HStack {
                            Label("Model Gallery", systemImage: "cube.transparent")
                            Spacer()
                            Text("\(unlockedCount)/\(totalCatalogModels)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink(value: Destination.cardTiers) {
                        Label("Card Tiers", systemImage: "trophy")
                    }
                }

                Section {
                    NavigationLink(value: Destination.privacy) {
                        Label("Apple Health Privacy", systemImage: "hand.raised.fill")
                    }
                    if let onConnectHealth {
                        Button {
                            dismiss()
                            onConnectHealth()
                        } label: {
                            Label("Sync Apple Health", systemImage: "arrow.trianglehead.2.clockwise")
                        }
                    }
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
                case .privacy:
                    PrivacyPolicyView()
                }
            }
        }
        .interactiveDismissDisabled(iconManager.isUpdating)
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
                    detail: "Only exported poster images leave the app when you tap Share. Manage Health permission anytime in iOS Settings › Health."
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

/// One-screen pre-permission introduction explaining why Earprint reads Apple Health headphone audio exposure.
struct HealthOnboardingView: View {
    let onConnect: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.quietColor.opacity(0.15))
                        .frame(width: 84, height: 84)
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.quietColor)
                }

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

            VStack(spacing: 10) {
                Button(action: onConnect) {
                    Label("Connect Apple Health", systemImage: "heart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.invertedFill, in: Capsule())
                        .foregroundStyle(Theme.invertedText)
                }
                .buttonStyle(.plain)

                Button("Not Now", action: onSkip)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 8)
            }
        }
        .padding(22)
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
    @State private var draft: AppIconChoice

    init(manager: AppIconManager) {
        self.manager = manager
        _draft = State(initialValue: manager.current)
    }

    private let fiveColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                Button("Done") {
                    Task {
                        if await manager.apply(draft) { dismiss() }
                    }
                }
                .disabled(manager.isUpdating)
            }
        }
        .disabled(manager.isUpdating)
        .onAppear {
            manager.refresh()
            manager.errorMessage = nil
            draft = manager.current
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Background")
            HStack(spacing: 8) {
                ForEach(IconBackground.allCases) { background in
                    let isSelected = draft.background == background
                    Button {
                        draft.background = background
                    } label: {
                        VStack(spacing: 8) {
                            AppIconThumbnail(finish: draft.finish, background: background, size: 42)
                            Text(LocalizedStringKey(background.title))
                                .font(.caption.weight(.semibold))
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
        let isSelected = draft.finish == finish
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            draft.finish = finish
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
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
    }
}
