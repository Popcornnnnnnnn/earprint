import SwiftUI

/// Design size of a card. Thumbnails render at this size and scale down, so every card looks identical at any size.
enum CardMetrics {
    static let size = CGSize(width: 300, height: 440)
    static let corner: CGFloat = 26
}

/// Foil surface: base gradient + rainbow sheen + specular highlight that move with tilt.
struct FoilSurface: View {
    let rarity: Rarity
    var tilt: CGSize = .zero

    var body: some View {
        ZStack {
            AngularGradient(colors: rarity.baseColors, center: UnitPoint(x: 0.5 + tilt.width * 0.3, y: 0.4 + tilt.height * 0.3),
                            angle: .degrees(200 + tilt.width * 60))

            // Fine diagonal foil lines.
            Canvas { context, size in
                var path = Path()
                stride(from: -size.height, to: size.width, by: 5).forEach { x in
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                }
                context.stroke(path, with: .color(.white.opacity(rarity == .holo ? 0.10 : 0.06)), lineWidth: 1)
            }

            if rarity == .holo || rarity == .gold {
                LinearGradient(colors: [.clear, .pink.opacity(0.35), .yellow.opacity(0.3), .cyan.opacity(0.35), .purple.opacity(0.3), .clear],
                               startPoint: UnitPoint(x: -0.2 + tilt.width * 0.6, y: 0),
                               endPoint: UnitPoint(x: 1.2 + tilt.width * 0.6, y: 1))
                    .blendMode(.colorDodge)
                    .opacity(rarity == .holo ? 0.9 : 0.4)
            }

            // Specular highlight that slides across as the card tilts.
            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                           startPoint: UnitPoint(x: 0.1 + tilt.width * 0.8, y: 0.0 + tilt.height * 0.5),
                           endPoint: UnitPoint(x: 0.6 + tilt.width * 0.8, y: 0.7 + tilt.height * 0.5))
                .blendMode(.overlay)
        }
    }
}

struct CardFront: View {
    let card: HeadphoneCard
    var tilt: CGSize = .zero

    var body: some View {
        let ink = card.rarity.ink
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.rarity.title)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.6)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.black.opacity(0.28), in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "#%04d", card.serial))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.6))
            }

            Spacer()

            Image(systemName: card.symbol)
                .font(.system(size: 110, weight: .thin))
                .foregroundStyle(ink.opacity(0.85))
                .shadow(color: .white.opacity(0.6), radius: 1, y: 1)
                .offset(x: tilt.width * -8, y: tilt.height * -8)
                .frame(maxWidth: .infinity)

            Spacer()

            Text(card.nickname)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(1)
            Text(card.model)
                .font(.system(size: 13, weight: .medium))
                .opacity(0.65)
            Text(card.lifetimeMinutes.minutesText)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .monospacedDigit()
                .padding(.top, 2)

            HStack {
                Label("\(card.sessions)", systemImage: "ear")
                Spacer()
                Text("since \(card.firstMet)")
            }
            .font(.system(size: 12, weight: .semibold))
            .opacity(0.7)
            .padding(.top, 6)
        }
        .foregroundStyle(ink)
        .padding(22)
        .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
        .background(FoilSurface(rarity: card.rarity, tilt: tilt))
        .clipShape(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
            .strokeBorder(.white.opacity(0.45), lineWidth: 1.5))
    }
}

struct CardBack: View {
    let card: HeadphoneCard
    /// Numbers count up from zero when this becomes true.
    var revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STATS").font(.system(size: 11, weight: .heavy)).tracking(2).opacity(0.6)
                Spacer()
                Text(card.model).font(.system(size: 11, weight: .semibold)).opacity(0.6)
            }

            ZStack {
                EarprintGlyph(grid: card.grid, showHourLabels: false)
                VStack(spacing: 0) {
                    Text("4 weeks").font(.system(size: 10, weight: .semibold)).opacity(0.6)
                    Text("listening").font(.system(size: 10)).opacity(0.5)
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)

            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    stat("Lifetime", revealed ? card.lifetimeMinutes : 0, unit: .minutes)
                    stat("Sessions", revealed ? Double(card.sessions) : 0, unit: .count)
                }
                GridRow {
                    stat("Longest", revealed ? card.longestMinutes : 0, unit: .minutes)
                    stat("Avg level", revealed ? card.averageDecibels : 0, unit: .decibels)
                }
            }

            Spacer(minLength: 0)
            tierProgress
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
        .background(
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10)
                RadialGradient(colors: [card.rarity.glow.opacity(0.35), .clear], center: .top, startRadius: 0, endRadius: 320)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
            .strokeBorder(LinearGradient(colors: card.rarity.baseColors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
    }

    private enum Unit { case minutes, count, decibels }

    private func stat(_ title: String, _ value: Double, unit: Unit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11)).opacity(0.55)
            Group {
                switch unit {
                case .minutes: Text(value.minutesText)
                case .count: Text("\(Int(value))")
                case .decibels: Text("\(Int(value)) dB")
                }
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private var tierProgress: some View {
        let hours = card.lifetimeMinutes / 60
        if let next = card.rarity.nextTierHours {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Int(next - hours))h to next tier").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                ProgressView(value: revealed ? min(hours / next, 1) : 0)
                    .tint(card.rarity.glow)
            }
        } else {
            Text("Max tier reached ✦").font(.system(size: 12, weight: .semibold)).foregroundStyle(card.rarity.glow)
        }
    }
}

/// Renders a design-size card scaled to whatever frame it is given.
struct ScaledCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            content
                .scaleEffect(geo.size.width / CardMetrics.size.width, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio(CardMetrics.size.width / CardMetrics.size.height, contentMode: .fit)
    }
}
