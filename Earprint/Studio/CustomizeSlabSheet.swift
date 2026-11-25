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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let preview = draft.sanitized
                    GradingSlab(card: card, dossier: dossier, animateSeal: false,
                                proFoil: preview.proFoil, engravedSubtitle: preview.engravedTitle,
                                customSerialTag: preview.customSerial, usesSavedCustomization: false)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Foil finish").font(.headline)
                        swatch(nil)
                        ForEach(ProFoilStyle.allCases) { style in
                            swatch(style)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Slab engraving").font(.headline)
                        TextField("Engraved title", text: $draft.engravedTitle)
                            .textFieldStyle(.roundedBorder)
                        TextField("Serial tag", text: $draft.customSerial)
                            .textFieldStyle(.roundedBorder)
                        Text("Up to 24 characters for the title and 16 for the serial tag.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
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
        Button {
            draft.proFoil = style
        } label: {
            HStack(spacing: 12) {
                FoilSurface(rarity: card.rarity, proFoil: style)
                    .frame(width: 54, height: 38)
                    .clipShape(.rect(cornerRadius: 8))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    if let style {
                        Text(LocalizedStringKey(style.shortName)).fontWeight(.semibold)
                        Text(LocalizedStringKey(style.subtitle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Default Tier").fontWeight(.semibold)
                        Text(LocalizedStringKey(card.rarity.title))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if draft.proFoil == style {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                }
            }
            .padding(8)
            .background(DossierPalette.surfaceFill, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(draft.proFoil == style ? .isSelected : [])
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
