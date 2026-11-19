import SwiftUI
import UIKit

/// Selectable Home Screen app icons bundled in `Assets.xcassets`.
enum AppIconOption: String, CaseIterable, Identifiable, Equatable {
    case auto
    case spaceBlack
    case midnightBlue
    case skyBlue
    case holoFoil

    var id: String { rawValue }

    /// Asset catalog `.appiconset` name passed to `UIApplication.setAlternateIconName(_:)`.
    /// `nil` selects the primary `AppIcon` (Sky Blue in Light Mode, Space Black in Dark Mode).
    var alternateIconName: String? {
        switch self {
        case .auto: return nil
        case .spaceBlack: return "AppIconSpaceBlack"
        case .midnightBlue: return "AppIconMidnightBlue"
        case .skyBlue: return "AppIconSkyBlue"
        case .holoFoil: return "AppIconHoloFoil"
        }
    }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .spaceBlack: return "Space Black"
        case .midnightBlue: return "Midnight Blue"
        case .skyBlue: return "Sky Blue"
        case .holoFoil: return "Holo Foil"
        }
    }

    var subtitle: String {
        switch self {
        case .auto: return "Sky Blue in Light · Space Black in Dark"
        case .spaceBlack: return "Matte obsidian titanium finish"
        case .midnightBlue: return "Deep anodized sapphire finish"
        case .skyBlue: return "Cool glacier aluminum finish"
        case .holoFoil: return "Full-bleed collector prism"
        }
    }

    var badge: String? {
        switch self {
        case .auto: return "DEFAULT"
        case .holoFoil: return "HOLO"
        default: return nil
        }
    }

    var previewAssetName: String {
        switch self {
        case .auto: return "IconPreviewSpaceBlack"
        case .spaceBlack: return "IconPreviewSpaceBlack"
        case .midnightBlue: return "IconPreviewMidnightBlue"
        case .skyBlue: return "IconPreviewSkyBlue"
        case .holoFoil: return "IconPreviewHoloFoil"
        }
    }

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
    var size: CGFloat = 58

    private var cornerRadius: CGFloat { size * 0.2237 }

    var body: some View {
        ZStack {
            if option == .auto {
                Image("IconPreviewSkyBlue")
                    .resizable()
                    .scaledToFill()
                Image("IconPreviewSpaceBlack")
                    .resizable()
                    .scaledToFill()
                    .mask(DiagonalBottomRightTriangle())
                Path { path in
                    path.move(to: CGPoint(x: size, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: size))
                }
                .stroke(.white.opacity(0.35), lineWidth: max(1, size * 0.018))
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
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Pick the Earprint icon on your Home Screen. Auto switches between Sky Blue in Light Mode and Space Black in Dark Mode.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.bottom, 4)

                        ForEach(AppIconOption.allCases) { option in
                            iconRow(option)
                        }

                        if let error = manager.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red.opacity(0.9))
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
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

    private func iconRow(_ option: AppIconOption) -> some View {
        let isSelected = manager.current == option
        return Button {
            Task { await manager.select(option) }
        } label: {
            HStack(spacing: 14) {
                AppIconThumbnail(option: option, size: 58)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(option.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                        if let badge = option.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.6)
                                .foregroundStyle(option == .holoFoil ? Color(red: 0.96, green: 0.80, blue: 1.0) : Color(red: 0.62, green: 0.94, blue: 0.85))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.1), in: Capsule())
                        }
                    }
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

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
        .accessibilityLabel("\(option.title), \(option.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
