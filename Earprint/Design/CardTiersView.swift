import SwiftUI

/// Visual illustration of Earprint's 6-tier card achievement system (0h Bronze → 2,000h Holo Legendary).
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerBanner

                VStack(spacing: 12) {
                    ForEach(Rarity.allAscending) { tier in
                        tierRow(tier)
                    }
                }
            }
            .padding(20)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Rarity.holo.accent)
                Text("Cards upgrade automatically with lifetime listening hours")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let topCard {
                let tier = topCard.rarity
                VStack(alignment: .leading, spacing: 6) {
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
                .padding(.top, 4)
            } else {
                Text("Every pair starts at Bronze on its first listen and climbs all the way to Holo Legendary at 2,000 hours.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
    }

    private func tierRow(_ tier: Rarity) -> some View {
        let reached = !ownedCards.isEmpty && highestHours >= tier.minimumHours
        let isTopCurrent = topCard?.rarity == tier

        return HStack(spacing: 14) {
            // Live mini foil card swatch showing the exact card surface material
            ZStack(alignment: .bottomLeading) {
                FoilSurface(rarity: tier, tilt: CGSize(width: 0.25, height: -0.15))
                VStack(alignment: .leading, spacing: 2) {
                    Spacer()
                    Text(hoursLabel(tier.minimumHours))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tier.ink)
                }
                .padding(8)
            }
            .frame(width: 68, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(reached ? 0.55 : 0.22), lineWidth: 1.2)
            )
            .shadow(color: tier.glow.opacity(reached ? 0.35 : 0.14), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(tier.title))
                        .font(.caption.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(tier.accent)
                    if isTopCurrent {
                        Text("CURRENT")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.14), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }

                Text(requirementText(tier))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Text(LocalizedStringKey(tier.tagline))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if reached {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.32, green: 0.86, blue: 0.56))
                    .accessibilityLabel("Unlocked")
            } else {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.24))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isTopCurrent ? Color.white.opacity(0.09) : Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
