import SwiftUI
import UIKit

/// Selectable Home Screen app icons bundled in `Assets.xcassets`.
/// Covers Auto Light/Dark, all 10 official Apple AirPods Max retail colors (USB-C & Lightning), and Holo Foil.
enum AppIconOption: String, CaseIterable, Identifiable, Equatable {
    case auto
    // 2024 USB-C finishes
    case midnight
    case starlight
    case blue
    case purple
    case orange
    // 2020 Lightning finishes
    case spaceGray
    case silver
    case skyBlue
    case green
    case pink
    // Collector edition
    case holoFoil

    var id: String { rawValue }

    /// Asset catalog `.appiconset` name passed to `UIApplication.setAlternateIconName(_:)`.
    /// `nil` selects the primary `AppIcon` (Midnight on White in Light Mode, Sky Blue on Black in Dark Mode).
    var alternateIconName: String? {
        switch self {
        case .auto: return nil
        case .midnight: return "AppIconMidnight"
        case .spaceGray: return "AppIconSpaceGray"
        case .blue: return "AppIconBlue"
        case .silver: return "AppIconSilver"
        case .starlight: return "AppIconStarlight"
        case .skyBlue: return "AppIconSkyBlue"
        case .purple: return "AppIconPurple"
        case .green: return "AppIconGreen"
        case .orange: return "AppIconOrange"
        case .pink: return "AppIconPink"
        case .holoFoil: return "AppIconHoloFoil"
        }
    }

    var title: String {
        switch self {
        case .auto: return "Auto"
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
        case .holoFoil: return "Holo Foil"
        }
    }

    var subtitle: String {
        switch self {
        case .auto: return "Midnight (Light) · Sky Blue (Dark)"
        case .midnight, .starlight, .blue, .purple, .orange: return "USB-C"
        case .spaceGray, .silver, .skyBlue, .green, .pink: return "Lightning"
        case .holoFoil: return "Collector Edition"
        }
    }

    var previewAssetName: String {
        switch self {
        case .auto: return "IconPreviewMidnight"
        case .midnight: return "IconPreviewMidnight"
        case .spaceGray: return "IconPreviewSpaceGray"
        case .blue: return "IconPreviewBlue"
        case .silver: return "IconPreviewSilver"
        case .starlight: return "IconPreviewStarlight"
        case .skyBlue: return "IconPreviewSkyBlue"
        case .purple: return "IconPreviewPurple"
        case .green: return "IconPreviewGreen"
        case .orange: return "IconPreviewOrange"
        case .pink: return "IconPreviewPink"
        case .holoFoil: return "IconPreviewHoloFoil"
        }
    }

    static let usbcFinishes: [AppIconOption] = [.midnight, .starlight, .blue, .purple, .orange]
    static let lightningFinishes: [AppIconOption] = [.spaceGray, .silver, .skyBlue, .green, .pink]

    static func from(alternateIconName: String?) -> AppIconOption {
        guard let name = alternateIconName else { return .auto }
        return allCases.first { $0.alternateIconName == name } ?? .auto
    }
}

@MainActor
@Observable
final class AppIconManager {
    private(set) var current: AppIconOption
    private(set) var isUpdating = false
    var errorMessage: String?

    init() {
        self.current = AppIconOption.from(alternateIconName: UIApplication.shared.alternateIconName)
    }

    func refresh() {
        current = AppIconOption.from(alternateIconName: UIApplication.shared.alternateIconName)
    }

    func select(_ option: AppIconOption) async {
        guard option != current, !isUpdating else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "Alternate app icons are not supported on this device."
            return
        }

        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        do {
            try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
            current = option
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Squircle thumbnail for an `AppIconOption`. `.auto` renders a diagonal Light/Dark split.
struct AppIconThumbnail: View {
    let option: AppIconOption
    var size: CGFloat = 64

    private var cornerRadius: CGFloat { size * 0.2237 }

    var body: some View {
        ZStack {
            if option == .auto {
                Image("IconPreviewMidnight")
                    .resizable()
                    .scaledToFill()
                Image("IconPreviewSkyBlue")
                    .resizable()
                    .scaledToFill()
                    .mask(DiagonalBottomRightTriangle())
                Path { path in
                    path.move(to: CGPoint(x: size, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: size))
                }
                .stroke(.white.opacity(0.45), lineWidth: max(1, size * 0.018))
            } else {
                Image(option.previewAssetName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
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

struct AppIconPickerSheet: View {
    @Bindable var manager: AppIconManager
    @Environment(\.dismiss) private var dismiss

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        autoHeroRow

                        sectionHeader("AirPods Max · USB-C", detail: "5 colors")
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            ForEach(AppIconOption.usbcFinishes) { option in
                                iconTile(option)
                            }
                        }

                        sectionHeader("AirPods Max · Lightning", detail: "5 colors")
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            ForEach(AppIconOption.lightningFinishes) { option in
                                iconTile(option)
                            }
                        }

                        sectionHeader("Collector Edition", detail: nil)
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            iconTile(.holoFoil)
                        }

                        if let error = manager.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(Color(red: 0.05, green: 0.05, blue: 0.07), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { manager.refresh() }
    }

    private var autoHeroRow: some View {
        let isSelected = manager.current == .auto
        return Button {
            Task { await manager.select(.auto) }
        } label: {
            HStack(spacing: 14) {
                AppIconThumbnail(option: .auto, size: 60)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("Auto")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("LIGHT & DARK")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(Color(red: 0.62, green: 0.94, blue: 0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                    Text("Midnight on white in Light · Sky Blue on black in Dark")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                selectionIndicator(isSelected)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color(red: 0.50, green: 0.92, blue: 0.80).opacity(0.55) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.25 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(manager.isUpdating)
    }

    private func iconTile(_ option: AppIconOption) -> some View {
        let isSelected = manager.current == option
        return Button {
            Task { await manager.select(option) }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    AppIconThumbnail(option: option, size: 74)
                        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(red: 0.50, green: 0.92, blue: 0.80), Color(red: 0.07, green: 0.07, blue: 0.10))
                            .offset(x: 6, y: -6)
                    }
                }

                Text(option.title)
                    .font(.caption.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.11) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color(red: 0.50, green: 0.92, blue: 0.80).opacity(0.6) : Color.white.opacity(0.07),
                        lineWidth: isSelected ? 1.3 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(manager.isUpdating)
        .accessibilityLabel("\(option.title), \(option.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sectionHeader(_ title: String, detail: String?) -> some View {
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
        .padding(.top, 2)
    }

    @ViewBuilder
    private func selectionIndicator(_ isSelected: Bool) -> some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.50, green: 0.92, blue: 0.80))
        } else {
            Circle()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1.5)
                .frame(width: 22, height: 22)
        }
    }
}
