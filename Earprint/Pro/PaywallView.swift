import SwiftUI

struct PaywallView: View {
    let store: ProEntitlementStore
    var highlightedFeature: ProFeature? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    hero

                    VStack(spacing: 2) {
                        ForEach(ProFeature.allCases) { feature in
                            featureRow(feature)
                        }
                    }
                    .card()

                    ProStoreFeedback(store: store)
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    primaryAction
                    secondaryActions
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.35)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Collector Edition", systemImage: EarprintProductID.proLifetime.systemImage)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.moderateColor.opacity(0.19), in: Capsule())

            Text(EarprintProductID.proLifetime.fallbackLabel)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .accessibilityAddTraits(.isHeader)

            Text("One-time purchase · No subscription · Core stays free")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.surfaceFillStrong, in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.primaryText)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26)
                .fill(Theme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(.linearGradient(
                            colors: [Theme.moderateColor.opacity(0.22), Theme.quietColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Theme.moderateColor.opacity(0.35))
                }
        }
    }

    private func featureRow(_ feature: ProFeature) -> some View {
        let isHighlighted = feature == highlightedFeature
        // Keep the feature list tied to the access contract while using generic storefront copy.
        let title: LocalizedStringKey = feature == .liveActivity ? "Live Listening Session" : feature.titleKey
        let subtitle: LocalizedStringKey = feature == .liveActivity
            ? "See live loudness and rest countdowns at a glance."
            : feature.subtitleKey

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 36, height: 36)
                .background(Theme.surfaceFill, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.moderateColor.opacity(isHighlighted ? 0.14 : 0), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isHighlighted ? Theme.moderateColor.opacity(0.45) : .clear)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var primaryAction: some View {
        if store.hasPro {
            let title: LocalizedStringKey = store.isGrandfathered && !store.hasProPurchased
                ? "Grandfathered Early Collector"
                : "Earprint Pro Unlocked"
            Label(title, systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Theme.quietColor.opacity(0.17), in: RoundedRectangle(cornerRadius: 20))
        } else if !store.hasResolvedEntitlements {
            ProgressView("Checking eligibility…")
                .frame(maxWidth: .infinity)
                .padding(12)
        } else if let product = store.proProduct {
            Button {
                Task { await store.purchasePro() }
            } label: {
                HStack(spacing: 8) {
                    if store.isPurchasing {
                        ProgressView().tint(Theme.invertedText)
                    }
                    Text("Unlock Earprint Pro · \(product.displayPrice)")
                        .font(.headline)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(14)
                .foregroundStyle(Theme.invertedText)
                .background(Theme.invertedFill, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(store.isPurchasing)
        } else if store.isLoadingProducts {
            ProgressView("Loading store…")
                .padding(12)
        } else {
            Button("Retry loading store") {
                Task { await store.loadProducts() }
            }
            .buttonStyle(.bordered)
            .disabled(store.isPurchasing)
        }
    }

    private var secondaryActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) { storeLinks }
            VStack(spacing: 8) { storeLinks }
        }
        .font(.subheadline.weight(.semibold))
        .tint(Theme.primaryText)
    }

    @ViewBuilder
    private var storeLinks: some View {
        Button("Restore Purchases") {
            Task { await store.restorePurchases() }
        }
        .disabled(store.isPurchasing)

        NavigationLink {
            TipJarView(store: store)
        } label: {
            Label("Tip Jar", systemImage: "heart")
        }
    }
}

struct ProStoreFeedback: View {
    let store: ProEntitlementStore

    var body: some View {
        if let error = store.errorMessage {
            banner(error, symbol: "exclamationmark.circle.fill", tint: Theme.loudColor)
        } else if let status = store.statusMessage {
            banner(status, symbol: "info.circle.fill", tint: Theme.quietColor)
        }
    }

    private func banner(_ message: String, symbol: String, tint: Color) -> some View {
        Label(LocalizedStringKey(message), systemImage: symbol)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }
}
