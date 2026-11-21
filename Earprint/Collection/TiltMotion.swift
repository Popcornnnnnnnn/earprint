import CoreMotion
import SwiftUI
import UIKit

/// Single shared CoreMotion engine for the whole app (Apple recommends one `CMMotionManager` per process).
/// Reference-counted so hardware sensors stop immediately when no visible view needs tilt or when the app
/// resigns active. Scroll views pause tilt updates via `setScrolling(_:source:)` without mutating SwiftUI
/// `@State` or resetting the held tilt to `.zero`, preventing scroll-start hitches and visual flat-snaps.
@MainActor
@Observable
final class MotionHub {
    static let shared = MotionHub()

    private(set) var tilt: CGSize = .zero

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?
    @ObservationIgnored private var smoothed: CGSize = .zero
    @ObservationIgnored private var activeClients = 0
    @ObservationIgnored private var activeScrollSources: Set<String> = []
    @ObservationIgnored private var appIsActive = true
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    /// Minimum change on either axis before publishing a new SwiftUI tilt value.
    nonisolated private static let epsilon: CGFloat = 0.008
    /// Exponential smoothing factor (0 = frozen, 1 = raw).
    private static let smoothing: CGFloat = 0.28

    /// True while any registered ScrollView or interactive deck swipe is actively moving.
    var isScrollPaused: Bool { !activeScrollSources.isEmpty }

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.appIsActive = false
                self.stopHardware(resetTilt: true)
            }
        })
        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.appIsActive = true
                if self.activeClients > 0 {
                    self.startHardware()
                }
            }
        })
    }

    func acquire() {
        activeClients += 1
        if activeClients == 1 && appIsActive {
            startHardware()
        }
    }

    func release() {
        guard activeClients > 0 else { return }
        activeClients -= 1
        if activeClients == 0 {
            stopHardware(resetTilt: true)
        }
    }

    /// Suspends tilt publishing while `source` is scrolling without triggering SwiftUI state invalidations
    /// or snapping tilted cards flat. Call with `false` when scrolling ends or the scroll view disappears.
    func setScrolling(_ scrolling: Bool, source: String) {
        if scrolling {
            activeScrollSources.insert(source)
        } else {
            activeScrollSources.remove(source)
        }
    }

    private func startHardware() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        reference = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, self.activeScrollSources.isEmpty,
                  let attitude = motion?.attitude.copy() as? CMAttitude else { return }
            if self.reference == nil { self.reference = attitude }
            if let reference = self.reference { attitude.multiply(byInverseOf: reference) }
            let rawX = max(-1, min(1, CGFloat(attitude.roll / 0.6)))
            let rawY = max(-1, min(1, CGFloat(attitude.pitch / 0.6)))
            self.ingestRawTilt(CGSize(width: rawX, height: rawY))
        }
    }

    /// Applies low-pass smoothing and deadzone filtering; ignored while scroll-paused so held tilt stays smooth.
    func ingestRawTilt(_ raw: CGSize) {
        guard activeScrollSources.isEmpty else { return }
        let nextX = smoothed.width + (raw.width - smoothed.width) * Self.smoothing
        let nextY = smoothed.height + (raw.height - smoothed.height) * Self.smoothing
        smoothed = CGSize(width: nextX, height: nextY)
        if Self.shouldPublish(from: tilt, to: smoothed) {
            tilt = smoothed
        }
    }

    private func stopHardware(resetTilt: Bool) {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
        reference = nil
        if resetTilt {
            smoothed = .zero
            if tilt != .zero {
                tilt = .zero
            }
        }
    }

    /// Test-accessible filter helper verifying deadzone & clamping behavior.
    nonisolated static func shouldPublish(from previous: CGSize, to next: CGSize) -> Bool {
        abs(next.width - previous.width) >= epsilon || abs(next.height - previous.height) >= epsilon
    }
}

/// Pauses `MotionHub` tilt updates while a `ScrollView` is actively moving, with zero SwiftUI `@State`
/// mutations and automatic cleanup on disappear.
private struct ScrollMotionPauseModifier: ViewModifier {
    let source: String

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase in
                MotionHub.shared.setScrolling(phase != .idle, source: source)
            }
            .onDisappear {
                MotionHub.shared.setScrolling(false, source: source)
            }
    }
}

extension View {
    func pauseMotionWhileScrolling(_ source: String) -> some View {
        modifier(ScrollMotionPauseModifier(source: source))
    }
}

/// Leaf view that isolates CoreMotion tilt observation so parent `ScrollView` hierarchies never re-evaluate on tilt.
struct LiveTiltView<Content: View>: View {
    let isActive: Bool
    var overrideTilt: CGSize? = nil
    @ViewBuilder var content: (CGSize) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var acquired = false

    private var wantsMotion: Bool {
        isActive && !reduceMotion && overrideTilt == nil
    }

    var body: some View {
        let effectiveTilt: CGSize = if let overrideTilt {
            overrideTilt
        } else if wantsMotion {
            MotionHub.shared.tilt
        } else {
            .zero
        }
        content(effectiveTilt)
            .onAppear { syncAcquisition() }
            .onChange(of: wantsMotion) { _, _ in syncAcquisition() }
            .onDisappear { releaseIfNeeded() }
    }

    private func syncAcquisition() {
        if wantsMotion && !acquired {
            acquired = true
            MotionHub.shared.acquire()
        } else if !wantsMotion && acquired {
            acquired = false
            MotionHub.shared.release()
        }
    }

    private func releaseIfNeeded() {
        if acquired {
            acquired = false
            MotionHub.shared.release()
        }
    }
}

/// Backwards-compatible event-driven wrapper around `MotionHub` for callers using `ObservableObject`.
/// Uses `withObservationTracking` without polling so idle CPU usage stays at 0%.
@MainActor
final class TiltMotion: ObservableObject {
    @Published var tilt: CGSize = .zero
    private var acquired = false

    func start() {
        guard !acquired else { return }
        acquired = true
        MotionHub.shared.acquire()
        trackNext()
    }

    func stop() {
        if acquired {
            acquired = false
            MotionHub.shared.release()
        }
        if tilt != .zero {
            tilt = .zero
        }
    }

    private func trackNext() {
        guard acquired else { return }
        let current = withObservationTracking {
            MotionHub.shared.tilt
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.trackNext()
            }
        }
        if tilt != current {
            tilt = current
        }
    }
}
