import SwiftUI

/// Collector Trophy Binder + Interactive Spotlight illustration for Earprint's 10-tier system (0h → 2,000h).
struct CardTiersView: View {
    var ownedCards: [HeadphoneCard] = []
    var showsDoneButton = false

    @Environment(\.dismiss) private var dismiss
    @State private var inspectedTier: Rarity?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        let topCard = ownedCards.max(by: { $0.lifetimeMinutes < $1.lifetimeMinutes })
        let highestHours = (topCard?.lifetimeMinutes ?? 0) / 60
        let hasCards = !ownedCards.isEmpty
        let unlockedTierCount = hasCards ? Rarity.allAscending.filter { highestHours >= $0.minimumHours }.count : 0
        let selectedTier = inspectedTier ?? topCard?.rarity ?? .bronze

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LiveTiltView(isActive: true) { tilt in
                    spotlightHero(selectedTier, tilt: tilt, topCard: topCard, highestHours: highestHours, hasCards: hasCards)
                }

                HStack {
                    Text("COLLECTOR BINDER")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("\(unlockedTierCount)/\(Rarity.allAscending.count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.08), in: Capsule())
                        .foregroundStyle(selectedTier.accent)
                }
                .padding(.horizontal, 2)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(Rarity.allAscending.enumerated()), id: \.element.id) { index, tier in
                        binderCard(
                            tier,
                            rank: index + 1,
                            topCard: topCard,
                            highestHours: highestHours,
                            hasCards: hasCards,
                            selectedTier: selectedTier
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 16)
        }
        .pauseMotionWhileScrolling("tiers")
        .background(Color(red: 0.035, green: 0.035, blue: 0.055).ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Card Tiers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if inspectedTier == nil {
                inspectedTier = topCard?.rarity ?? .bronze
            }
        }
    }

    // MARK: - Interactive Spotlight Hero

    private func spotlightHero(
        _ tier: Rarity,
        tilt liveTilt: CGSize,
        topCard: HeadphoneCard?,
        highestHours: Double,
        hasCards: Bool
    ) -> some View {
        let rank = (Rarity.allAscending.firstIndex(of: tier) ?? 0) + 1
        let reached = hasCards && highestHours >= tier.minimumHours
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let ink = tier.ink
        let badgeBg = Color.black.opacity(ink == .white ? 0.34 : 0.16)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(LocalizedStringKey(tier.title))
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeBg, in: Capsule())
                    .foregroundStyle(.white)

                Spacer(minLength: 6)

                HStack(spacing: 4) {
                    Image(systemName: reached ? "checkmark.circle.fill" : "lock.fill")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(reached ? LocalizedStringKey("Unlocked") : LocalizedStringKey(hoursLabel(tier.minimumHours)))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(badgeBg, in: Capsule())
                .foregroundStyle(.white)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(String(format: "%02d", rank)) · \(Text(LocalizedStringKey(tier.finishLabel)))")
                        .font(.caption.weight(.semibold))
                        .opacity(0.76)

                    Text(hoursLabel(tier.minimumHours))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()

                    Text(LocalizedStringKey(tier.tagline))
                        .font(.caption.weight(.medium))
                        .opacity(0.88)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: tier == .holo ? "sparkles" : (topCard?.symbol ?? "headphones"))
                    .font(.system(size: 46, weight: .thin))
                    .opacity(0.82)
                    .offset(x: liveTilt.width * -6, y: liveTilt.height * -4)
                    .accessibilityHidden(true)
            }

            // Live progress strip for the user's top pair (or general guidance when empty)
            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(ink.opacity(0.16))
                    .frame(height: 1)

                if let topCard {
                    let currentTier = topCard.rarity
                    HStack {
                        Text("\(topCard.model) · \(topCard.lifetimeMinutes.minutesText)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .lineLimit(1)
                        Spacer()
                        Text(LocalizedStringKey(currentTier.shortName))
                            .font(.caption2.weight(.heavy))
                            .opacity(0.8)
                    }

                    ProgressView(value: currentTier.progressToNextTier(minutes: topCard.lifetimeMinutes))
                        .tint(ink)

                    if let next = currentTier.nextTier {
                        let remaining = max(1, Int(ceil(next.minimumHours - highestHours)))
                        Text("\(remaining)h to \(Text(LocalizedStringKey(next.title)))")
                            .font(.caption2.weight(.semibold))
                            .opacity(0.82)
                    } else {
                        Text("Max tier reached ✦")
                            .font(.caption2.weight(.bold))
                    }
                } else {
                    Text("Cards upgrade automatically from Bronze Slate (0h+) to Liquid Holo (2,000h+).")
                        .font(.caption2.weight(.medium))
                        .opacity(0.82)
                }
            }
        }
        .foregroundStyle(ink)
        .padding(18)
        .background(FoilSurface(rarity: tier, tilt: liveTilt))
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.45), lineWidth: 1.4))
        .background {
            shape.fill(Color.black)
                .shadow(color: tier.glow.opacity(0.35), radius: 20, y: 12)
        }
        .rotation3DEffect(.degrees(Double(liveTilt.width) * 4), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
        .rotation3DEffect(.degrees(Double(-liveTilt.height) * 3), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 2-Column Trophy Binder Tile

    private func binderCard(
        _ tier: Rarity,
        rank: Int,
        topCard: HeadphoneCard?,
        highestHours: Double,
        hasCards: Bool,
        selectedTier: Rarity
    ) -> some View {
        let unlocked = hasCards && highestHours >= tier.minimumHours
        let isTopCurrent = topCard?.rarity == tier
        let isSelected = selectedTier == tier
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let ink = tier.ink
        let chipBg = Color.black.opacity(ink == .white ? 0.34 : 0.16)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy(duration: 0.24)) {
                inspectedTier = tier
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(tier.shortName.uppercased()))
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(chipBg, in: Capsule())
                        .foregroundStyle(.white)

                    Spacer(minLength: 4)

                    if isTopCurrent {
                        Text("NOW")
                            .font(.system(size: 8.5, weight: .black, design: .rounded))
                            .tracking(0.5)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(.white, in: Capsule())
                            .foregroundStyle(.black)
                    } else if unlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .opacity(0.75)
                    }
                }

                Spacer(minLength: 8)

                Text(hoursLabel(tier.minimumHours))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 4) {
                    Text(String(format: "%02d", rank))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .opacity(0.65)
                    Text("·")
                        .opacity(0.5)
                    Text(LocalizedStringKey(tier.finishLabel))
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .opacity(0.82)
                }
                .padding(.top, 2)
            }
            .foregroundStyle(ink)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .background(FoilSurface(rarity: tier, tilt: .zero))
            .clipShape(shape)
            .saturation(unlocked || isSelected ? 1.0 : 0.72)
            .opacity(unlocked || isSelected ? 1.0 : 0.68)
            .overlay(
                shape.strokeBorder(
                    isSelected ? Color.white.opacity(0.92) : Color.white.opacity(unlocked ? 0.36 : 0.16),
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .background {
                if isSelected {
                    shape.fill(Color.black)
                        .shadow(color: tier.glow.opacity(0.38), radius: 10, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Text(LocalizedStringKey(tier.title))), \(hoursLabel(tier.minimumHours))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func hoursLabel(_ hours: Double) -> String {
        hours == 0 ? "0h+" : "\(Int(hours))h+"
    }
}
