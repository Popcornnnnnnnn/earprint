import SwiftUI

struct CustomizeSlabSheet: View {
    let card: HeadphoneCard
    let dossier: DeviceDossier

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.proAccess) private var proAccess
    @Environment(ProEntitlementStore.self) private var proStore: ProEntitlementStore?
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?
    @State private var draft = CardCustomization()
    @State private var original: CardCustomization?
    @State private var paywallFeature: ProFeature?

    private var store: SlabCustomizationStore { customizationStore ?? .shared }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                let preview = draft.sanitized
                VStack(spacing: 6) {
                    GradingSlab(
                        card: card,
                        dossier: dossier,
                        tilt: CGSize(width: 0.24, height: -0.16),
                        animateSeal: false,
                        proFoil: preview.proFoil,
                        engravedSubtitle: preview.engravedTitle,
                        customSerialTag: preview.customSerial,
                        usesSavedCustomization: false
                    )
                    .scaleEffect(0.50)
                    .frame(width: SlabMetrics.width * 0.50, height: SlabMetrics.height * 0.50)
                    .rotation3DEffect(.degrees(4), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .shadow(color: (preview.proFoil?.glow ?? card.rarity.glow).opacity(colorScheme == .light ? 0.14 : 0.26), radius: 14, y: 6)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(DossierPalette.surfaceFill.opacity(0.6))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Foil finish").font(.headline)
                                Spacer()
                                if draft != CardCustomization() {
                                    Button("Reset") {
                                        withAnimation(.snappy(duration: 0.2)) {
                                            draft = CardCustomization()
                                        }
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(card.rarity.accent)
                                }
                            }
                            swatch(nil)
                            ForEach(ProFoilStyle.allCases) { style in
                                swatch(style)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Slab engraving").font(.headline)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Title").font(.caption.weight(.semibold)).foregroundStyle(DossierPalette.dim)
                                    Spacer()
                                    Text("\(min(draft.engravedTitle.count, 24))/24")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(DossierPalette.faint)
                                }
                                TextField("Engraved title", text: $draft.engravedTitle)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Serial tag").font(.caption.weight(.semibold)).foregroundStyle(DossierPalette.dim)
                                    Spacer()
                                    Text("\(min(draft.customSerial.count, 16))/16")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(DossierPalette.faint)
                                }
                                TextField("Serial tag", text: $draft.customSerial)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
                            }

                            Text("Up to 24 characters for the title and 16 for the serial tag.")
                                .font(.footnote)
                                .foregroundStyle(DossierPalette.dim)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .foregroundStyle(DossierPalette.primaryText)
            .background(DossierPalette.ink.ignoresSafeArea())
            .navigationTitle("Customize Slab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear {
                guard original == nil else { return }
                let stored = store.customization(for: card.id)
                original = stored
                draft = stored
            }
            .sheet(item: $paywallFeature) { feature in
                if let proStore {
                    PaywallView(store: proStore, highlightedFeature: feature)
                        .environment(\.locale, locale)
                        .preferredColorScheme(colorScheme)
                }
            }
        }
    }

    private func swatch(_ style: ProFoilStyle?) -> some View {
        let isSelected = draft.proFoil == style
        let borderHighlight = style?.accent ?? card.rarity.accent
        return Button {
            draft.proFoil = style
        } label: {
            HStack(spacing: 12) {
                FoilSurface(rarity: card.rarity, tilt: CGSize(width: 0.2, height: -0.1), proFoil: style)
                    .frame(width: 54, height: 38)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    if let style {
                        Text(LocalizedStringKey(style.shortName)).fontWeight(.semibold)
                        Text(LocalizedStringKey(style.subtitle))
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                    } else {
                        Text("Default Tier").fontWeight(.semibold)
                        Text(LocalizedStringKey(card.rarity.title))
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.quietColor)
                } else {
                    Circle()
                        .strokeBorder(DossierPalette.hairline, lineWidth: 1.4)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? DossierPalette.panel : DossierPalette.surfaceFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? borderHighlight.opacity(0.65) : DossierPalette.hairline, lineWidth: isSelected ? 1.4 : 0.9)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save() {
        let value = draft.sanitized
        let original = original ?? CardCustomization()
        let changesFoil = value.proFoil != nil && value.proFoil != original.proFoil
        let changesEngraving = (!value.engravedTitle.isEmpty && value.engravedTitle != original.engravedTitle)
            || (!value.customSerial.isEmpty && value.customSerial != original.customSerial)
        if (changesFoil && !proAccess.isUnlocked(.foilShaders))
            || (changesEngraving && !proAccess.isUnlocked(.slabEngraving)) {
            let feature: ProFeature = (changesFoil && !proAccess.isUnlocked(.foilShaders)) ? .foilShaders : .slabEngraving
            if proStore != nil {
                paywallFeature = feature
            } else {
                ProPaywallRequester.request(feature: feature)
            }
            return
        }
        store.update(cardID: card.id, customization: value)
        dismiss()
    }
}
