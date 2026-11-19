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

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        let path = Bundle.main.path(forResource: rawValue, ofType: "lproj")
        let template = path.flatMap(Bundle.init(path:))?.localizedString(forKey: key, value: nil, table: nil) ?? key
        return arguments.isEmpty ? template : String(format: template, locale: locale, arguments: arguments)
    }

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var name: String { self == .english ? "English" : "简体中文" }
}

struct SettingsView: View {
    private enum Destination: Hashable { case appIcon }

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.systemDefault
    @State private var iconManager = AppIconManager()
    @State private var path: [Destination]

    init(openIconPicker: Bool = false) {
        _path = State(initialValue: openIconPicker ? [.appIcon] : [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                NavigationLink(value: Destination.appIcon) {
                    Label("App Icon", systemImage: "app")
                }
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.name).tag(option)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: Destination.self) { _ in
                AppIconPickerView(manager: iconManager)
            }
        }
        .interactiveDismissDisabled(iconManager.isUpdating)
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
        .background(Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea())
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
                        .background(.white.opacity(isSelected ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(isSelected ? 0.56 : 0.08)))
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
                            .strokeBorder(.white, lineWidth: 2)
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
                                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                }
                .frame(width: 50, height: 50)

                Text(LocalizedStringKey(finish.title))
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
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
                .foregroundStyle(.white.opacity(0.62))
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
    }
}
