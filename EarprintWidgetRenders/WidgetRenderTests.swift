import SwiftUI
import XCTest

/// Renders every widget and Live Activity view to PNG in `docs/widgets/`.
///
///     xcodebuild test -project Earprint.xcodeproj -scheme Earprint \
///       -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:EarprintWidgetRenders
///
/// Sizes are iPhone 17 Pro (402 pt wide) widget sizes. Widgets get the system's 16 pt content margin,
/// so the renderer adds the same padding and draws the container background itself.
@MainActor
final class WidgetRenderTests: XCTestCase {
    private let snapshot = WidgetSnapshot.preview
    private let now = Date()

    private enum Size {
        static let small = CGSize(width: 170, height: 170)
        static let medium = CGSize(width: 364, height: 170)
        static let large = CGSize(width: 364, height: 382)
        static let circular = CGSize(width: 76, height: 76)
        static let rectangular = CGSize(width: 172, height: 76)
        static let inline = CGSize(width: 257, height: 26)
        static let corner: CGFloat = 23
    }

    private var outputDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/widgets", isDirectory: true)
    }

    // MARK: Home Screen

    func testSmall() throws {
        try render(homeWidget(size: Size.small, glow: snapshot.cards[0].rarity.glow) {
            SmallTodayView(snapshot: snapshot, featured: snapshot.cards[0], date: now)
        }, name: "small-today")
        try render(homeWidget(size: Size.small, glow: snapshot.cards[1].rarity.glow) {
            SmallTodayView(snapshot: snapshot, featured: snapshot.cards[1], date: now)
        }, name: "small-today-gold")
    }

    func testMedium() throws {
        try render(homeWidget(size: Size.medium, glow: snapshot.cards[0].rarity.glow, second: Theme.quiet.color, center: .trailing) {
            CardShelfView(snapshot: snapshot)
        }, name: "medium-card-shelf")
        var two = snapshot
        two.cards = Array(two.cards.prefix(2))
        try render(homeWidget(size: Size.medium, glow: two.cards[0].rarity.glow, second: Theme.quiet.color, center: .trailing) {
            CardShelfView(snapshot: two)
        }, name: "medium-card-shelf-two-cards")
    }

    func testLarge() throws {
        try render(homeWidget(size: Size.large, glow: Theme.quiet.color, second: Theme.moderate.color, center: .topLeading) {
            EarprintRingView(snapshot: snapshot, date: now)
        }, name: "large-earprint")
    }

    // MARK: Lock Screen

    func testLockScreen() throws {
        try render(lockWidget(size: Size.circular) { BudgetGaugeView(snapshot: snapshot) }, name: "lock-circular-budget")
        try render(lockWidget(size: Size.rectangular) { TodayRectangularView(snapshot: snapshot, date: now) }, name: "lock-rectangular-today")
        try render(lockWidget(size: Size.inline) { TodayInlineView(snapshot: snapshot, date: now).font(.system(size: 15, weight: .semibold)) }, name: "lock-inline")
    }

    // MARK: Live Activity

    func testLiveActivity() throws {
        let attributes = ListeningActivityAttributes.preview
        let state = ListeningActivityAttributes.ContentState.preview(now: now)
        try render(
            LiveActivityLockScreenView(attributes: attributes, state: state, staticProgress: 72.0 / 112.0)
                .padding(16)
                .frame(width: 370)
                .background(Color(red: 0.04, green: 0.04, blue: 0.07).opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(16)
                .background(lockWallpaper),
            name: "live-activity-lock-screen")

        // Dynamic Island mock-ups (the real island is drawn by the system around these views).
        let compact = HStack {
            IslandCompactLeading(attributes: attributes, state: state).padding(.leading, 14)
            Spacer()
            IslandCompactTrailing(state: state).padding(.trailing, 14)
        }
        .frame(width: 250, height: 37)
        .background(.black, in: Capsule())
        .padding(20)
        .background(lockWallpaper)
        try render(compact, name: "island-compact")

        let expanded = VStack(spacing: 8) {
            HStack(alignment: .center) {
                ListeningBadge(symbol: attributes.deviceSymbol, color: Theme.levelColor(db: state.decibels), size: 44)
                Spacer()
                IslandExpandedCenter(attributes: attributes, state: state)
                Spacer()
                DecibelReadout(decibels: state.decibels)
            }
            RestCountdown(state: state, staticProgress: 72.0 / 112.0).padding(.horizontal, 6)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .frame(width: 371)
        .background(.black, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
        .padding(16)
        .background(lockWallpaper)
        try render(expanded, name: "island-expanded")
    }

    // MARK: Overview boards

    func testHomeScreenBoard() throws {
        let board = VStack(spacing: 22) {
            HStack(spacing: 24) {
                homeWidget(size: Size.small, glow: snapshot.cards[0].rarity.glow) {
                    SmallTodayView(snapshot: snapshot, featured: snapshot.cards[0], date: now)
                }
                appIconGrid
            }
            homeWidget(size: Size.medium, glow: snapshot.cards[0].rarity.glow, second: Theme.quiet.color, center: .trailing) {
                CardShelfView(snapshot: snapshot)
            }
            homeWidget(size: Size.large, glow: Theme.quiet.color, second: Theme.moderate.color, center: .topLeading) {
                EarprintRingView(snapshot: snapshot, date: now)
            }
        }
        .padding(.horizontal, 19).padding(.vertical, 60)
        .frame(width: 402)
        .background(homeWallpaper)
        try render(board, name: "board-home-screen")
    }

    func testLockScreenBoard() throws {
        let attributes = ListeningActivityAttributes.preview
        let state = ListeningActivityAttributes.ContentState.preview(now: now)
        let board = VStack(spacing: 0) {
            HStack {
                IslandCompactLeading(attributes: attributes, state: state).padding(.leading, 14)
                Spacer()
                IslandCompactTrailing(state: state).padding(.trailing, 14)
            }
            .frame(width: 250, height: 37)
            .background(.black, in: Capsule())
            .padding(.top, 12)

            TodayInlineView(snapshot: snapshot, date: now)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 34)
            Text("10:28")
                .font(.system(size: 96, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            HStack(spacing: 14) {
                BudgetGaugeView(snapshot: snapshot).frame(width: 76, height: 76).tint(.white)
                TodayRectangularView(snapshot: snapshot, date: now).frame(width: 172, height: 76)
            }
            .foregroundStyle(.white)
            .padding(.top, 4)
            Spacer(minLength: 220)
            LiveActivityLockScreenView(attributes: attributes, state: state, staticProgress: 72.0 / 112.0)
                .padding(16)
                .background(Color(red: 0.04, green: 0.04, blue: 0.07).opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.bottom, 40)
        }
        .frame(width: 402, height: 874)
        .background(lockWallpaper)
        .environment(\.colorScheme, .dark)
        try render(board, name: "board-lock-screen")
    }

    // MARK: Helpers

    private var homeWallpaper: some View {
        LinearGradient(colors: [Color(red: 0.12, green: 0.23, blue: 0.37), Color(red: 0.42, green: 0.30, blue: 0.48), Color(red: 0.79, green: 0.48, blue: 0.39)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var lockWallpaper: some View {
        LinearGradient(colors: [Color(red: 0.06, green: 0.08, blue: 0.14), Color(red: 0.17, green: 0.12, blue: 0.23)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var appIconGrid: some View {
        Grid(horizontalSpacing: 22, verticalSpacing: 26) {
            ForEach(0..<2, id: \.self) { _ in
                GridRow {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.22))
                            .frame(width: 62, height: 62)
                    }
                }
            }
        }
    }

    private func homeWidget<Content: View>(size: CGSize, glow: Color, second: Color? = nil, center: UnitPoint = .topTrailing,
                                           @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(WidgetBackdrop(glow: glow, secondGlow: second, glowCenter: center))
            .clipShape(RoundedRectangle(cornerRadius: Size.corner, style: .continuous))
            .environment(\.colorScheme, .dark)
    }

    private func lockWidget<Content: View>(size: CGSize, @ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(.white)
            .tint(.white)
            .frame(width: size.width, height: size.height)
            .padding(12)
            .background(lockWallpaper)
            .environment(\.colorScheme, .dark)
    }

    private func render<V: View>(_ view: V, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            XCTFail("Could not render \(name)")
            return
        }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let url = outputDir.appendingPathComponent("\(name).png")
        try data.write(to: url)
        print("[render] \(url.path)")
    }
}
