import SwiftUI

private enum DossierShareFormat: String, CaseIterable, Identifiable {
    case simple, long

    var id: Self { self }
    var title: LocalizedStringKey { self == .simple ? "Simple" : "Long" }
}

struct DossierShareSheet<LongImage: View>: View {
    let card: HeadphoneCard
    let color: DeviceColorOption?
    let isSampleData: Bool
    @ViewBuilder var longImage: LongImage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var format: DossierShareFormat = .simple
    @State private var image: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("Image format", selection: $format) {
                    ForEach(DossierShareFormat.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)

                ScrollView {
                    if let image {
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .frame(maxWidth: 420)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Dossier image preview")
                    } else {
                        Text("Image unavailable")
                            .foregroundStyle(.secondary)
                    }
                }

                if let image {
                    ShareLink(item: image, preview: SharePreview(card.model, image: image)) {
                        Label("Share image", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.black)
                            .background(.white, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .background(DossierPalette.ink.ignoresSafeArea())
            .navigationTitle("Share dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: format, initial: true) { _, _ in
            image = makeImage()
        }
    }

    @MainActor private func makeImage() -> Image? {
        let renderer = ImageRenderer(content:
            shareGraphic
                .environment(\.locale, locale)
                .environment(\.colorScheme, .dark)
                .dynamicTypeSize(.medium)
        )
        renderer.scale = format == .simple ? 3 : 2
        renderer.isOpaque = true
        return renderer.uiImage.map { Image(uiImage: $0) }
    }

    private var shareGraphic: some View {
        VStack(spacing: 12) {
            switch format {
            case .simple:
                CardHorizontalFront(card: card, colorOption: color)
                    .padding(.horizontal, 14)
                if isSampleData {
                    Text("Sample data")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            case .long:
                longImage
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 16)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            DossierPalette.ink
            RadialGradient(colors: [card.rarity.accent.opacity(0.19), .clear], center: .topTrailing,
                           startRadius: 12, endRadius: 350)
        }
    }
}
