import SwiftUI

/// Visual illustration of Earprint's 10-tier card achievement system (0h Bronze → 2,000h Holo Legendary).
struct CardTiersView: View {
    var ownedCards: [HeadphoneCard] = []
    var showsDoneButton = false
    @Environment(\.dismiss) private var dismiss

    private var topCard: HeadphoneCard? {
        ownedCards.max(by: { $0.lifetimeMinutes < $1.lifetimeMinutes })
    }

    private var highestHours: Double {
        (topCard?.lifetimeMinutes ?? 0) / 60
    }

    private var unlockedTierCount: Int {
        guard !ownedCards.isEmpty else { return 0 }
        return Rarity.allAscending.filter { highestHours >= $0.minimumHours }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerBanner

                VStack(spacing: 8) {
                    ForEach(Array(Rarity.allAscending.enumerated()), id: \.element.id) { index, tier in
                        tierRow(tier, rank: index + 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 16)
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea())
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
    }

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Rarity.holo.accent)
                Text("Cards upgrade automatically with lifetime listening hours")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text("\(unlockedTierCount)/\(Rarity.allAscending.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.10), in: Capsule())
                    .foregroundStyle(Rarity.holo.accent)
            }

            if let topCard {
                let tier = topCard.rarity
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(topCard.model)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(topCard.lifetimeMinutes.minutesText)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(tier.accent)
                    }
                    if let next = tier.nextTier {
                        let remaining = max(1, Int(ceil(next.minimumHours - highestHours)))
                        ProgressView(value: tier.progressToNextTier(minutes: topCard.lifetimeMinutes))
                            .tint(tier.accent)
                        Text("\(remaining)h to \(Text(LocalizedStringKey(next.title)))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.55))
                    } else {
                        Text("Max tier reached ✦")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Rarity.holo.accent)
                    }
                }
                .padding(.top, 2)
            } else {
                Text("10 tiers from Bronze on your first listen all the way to Holo Legendary at 2,000 hours.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
    }

    private func tierRow(_ tier: Rarity, rank: Int) -> some View {
        let reached = !ownedCards.isEmpty && highestHours >= tier.minimumHours
        let isTopCurrent = topCard?.rarity == tier

        return HStack(spacing: 12) {
            // Compact live foil card swatch showing the exact card surface material
            ZStack(alignment: .bottomLeading) {
                FoilSurface(rarity: tier, tilt: CGSize(width: 0.25, height: -0.15))
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(format: "%02d", rank))
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(tier.ink.opacity(0.65))
                    Spacer()
                    Text(hoursLabel(tier.minimumHours))
                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(tier.ink)
                }
                .padding(6)
            }
            .frame(width: 54, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(reached ? 0.55 : 0.22), lineWidth: 1.1)
            )
            .shadow(color: tier.glow.opacity(reached ? 0.35 : 0.14), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(tier.title))
                        .font(.caption.weight(.heavy))
                        .tracking(0.9)
                        .foregroundStyle(tier.accent)
                    if isTopCurrent {
                        Text("CURRENT")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.14), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }

                Text(requirementText(tier))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)

                Text(LocalizedStringKey(tier.tagline))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if reached {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color(red: 0.32, green: 0.86, blue: 0.56))
                    .accessibilityLabel("Unlocked")
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.24))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isTopCurrent ? Color.white.opacity(0.09) : Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isTopCurrent ? tier.accent.opacity(0.55) : Color.white.opacity(0.08), lineWidth: isTopCurrent ? 1.25 : 1)
        )
    }

    private func hoursLabel(_ hours: Double) -> String {
        hours == 0 ? "0h+" : "\(Int(hours))h"
    }

    private func requirementText(_ tier: Rarity) -> LocalizedStringKey {
        if tier.minimumHours == 0 {
            return "First listen (0h+)"
        }
        return "\(Int(tier.minimumHours))+ listening hours"
    }
}
