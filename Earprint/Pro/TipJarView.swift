import SwiftUI

struct TipJarView: View {
    let store: ProEntitlementStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Leave a one-time tip to support Earprint's development.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)

                ProStoreFeedback(store: store)

                ForEach(store.tipProducts, id: \.id) { product in
                    if let tier = EarprintProductID(rawValue: product.id) {
                        tipRow(product, tier: tier)
                    }
                }

                if store.isPurchasing {
                    ProgressView("Processing purchase…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                if store.isLoadingProducts {
                    ProgressView("Loading store…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else if store.tipProducts.count < EarprintProductID.tipIDs.count {
                    Button("Retry loading store") {
                        Task { await store.loadProducts() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isPurchasing)
                }
            }
            .frame(maxWidth: 520)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Tip Jar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.tipProducts.isEmpty { await store.loadProducts() }
        }
    }

    private func tipRow(_ product: StoreProductItem, tier: EarprintProductID) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    tierLabel(tier)
                    Spacer(minLength: 8)
                    priceLabel(product)
                }
                VStack(alignment: .leading, spacing: 10) {
                    tierLabel(tier)
                    priceLabel(product)
                }
            }
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }

    private func tierLabel(_ tier: EarprintProductID) -> some View {
        Label(tier.fallbackLabel, systemImage: tier.systemImage)
            .font(.headline)
            .foregroundStyle(Theme.primaryText)
    }

    private func priceLabel(_ product: StoreProductItem) -> some View {
        Text(verbatim: product.displayPrice)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.surfaceFillStrong, in: Capsule())
    }
}
