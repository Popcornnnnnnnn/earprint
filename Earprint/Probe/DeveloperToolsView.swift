#if DEBUG
import SwiftUI

struct DeveloperToolsView: View {
    private enum Destination: Hashable {
        case probe
    }

    private let library: HeadphoneLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Destination]

    init(library: HeadphoneLibrary, openProbe: Bool) {
        self.library = library
        _path = State(initialValue: openProbe ? [.probe] : [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink(value: Destination.probe) {
                    Label("Data Probe", systemImage: "waveform")
                }
            }
            .navigationTitle("Developer Tools")
            .navigationDestination(for: Destination.self) { _ in
                ProbeView(library: library)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
