import CoreMotion
import SwiftUI

/// Device tilt in -1...1 on both axes, used for the holo shine and 3D tilt.
/// Falls back to zero in the simulator; a drag gesture can override it.
@MainActor
final class TiltMotion: ObservableObject {
    @Published var tilt: CGSize = .zero
    private let manager = CMMotionManager()
    private var reference: CMAttitude?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude.copy() as? CMAttitude else { return }
            if self.reference == nil { self.reference = attitude }
            if let reference = self.reference { attitude.multiply(byInverseOf: reference) }
            let x = max(-1, min(1, attitude.roll / 0.6))
            let y = max(-1, min(1, attitude.pitch / 0.6))
            self.tilt = CGSize(width: x, height: y)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        reference = nil
        tilt = .zero
    }
}
