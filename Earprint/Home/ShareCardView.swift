import SwiftUI

/// 9:16 card sized for Xiaohongshu, TikTok and Instagram stories.
struct ShareCardView: View {
    let summary: ListeningSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MY EARPRINT")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Theme.secondaryText)
                Text(summary.periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 12)

            EarprintGlyph(grid: summary.grid, showHourLabels: false)
                .padding(.horizontal, 8)

            Spacer(minLength: 12)

            Text(summary.weekMinutes.minutesText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("in my headphones this week")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 10) {
                Text(summary.persona.emoji)
                Text(LocalizedStringKey(summary.persona.title)).fontWeight(.semibold)
            }
            .font(.title3)
            .padding(.top, 16)

            HStack(spacing: 0) {
                mini("\(summary.sessions)", "sessions")
                mini(summary.longestSessionMinutes.minutesText, "longest")
                mini("\(Int(summary.weekDecibels.rounded())) dB", "avg level")
            }
            .padding(.top, 18)

            Spacer(minLength: 16)

            HStack {
                Image(systemName: summary.deviceSymbol)
                Text(summary.deviceModel)
                Spacer()
                Text("Earprint").fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
        }
        .padding(28)
        .frame(width: 360, height: 640)
        .background(
            ZStack {
                Theme.background
                RadialGradient(colors: [Theme.quiet.color.opacity(0.18), .clear], center: .init(x: 0.5, y: 0.35),
                               startRadius: 10, endRadius: 320)
            }
        )
        .foregroundStyle(.white)
    }

    private func mini(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.headline, design: .rounded)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShareSheet: View {
    let summary: ListeningSummary
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale

    var body: some View {
        // The share card keeps its 360×640 design size (it is also the exported image);
        // the preview only scales it to fit the sheet, which can be short (landscape) or wide (iPhone Duo).
        GeometryReader { geo in
            let wide = geo.size.width >= 600
            Group {
                if geo.size.width > geo.size.height * 1.1 {
                    HStack(spacing: 28) {
                        preview(maxScale: wide ? 1 : 0.82)
                        shareButton
                            .frame(width: min(280, geo.size.width * 0.4))
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 20) {
                        preview(maxScale: wide ? 1 : 0.82)
                        shareButton
                            .frame(maxWidth: 420)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.1).ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private func preview(maxScale: CGFloat) -> some View {
        FittedDesign(designSize: CGSize(width: 360, height: 640), maxScale: maxScale) {
            ShareCardView(summary: summary)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        }
    }

    @ViewBuilder private var shareButton: some View {
        if let image = renderImage() {
            ShareLink(item: image, preview: SharePreview(Text("My Earprint"), image: image)) {
                Label("Share image", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
    }

    @MainActor private func renderImage() -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(summary: summary).environment(\.locale, locale))
        renderer.scale = max(displayScale, 3)
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}
