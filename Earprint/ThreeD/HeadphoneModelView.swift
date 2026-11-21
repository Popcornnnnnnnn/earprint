import RealityKit
import SwiftUI
import UIKit

/// Generates a soft "photo studio" equirectangular image for image-based lighting.
/// Tint colors add colored reflections (e.g. holo pink/cyan) on metal surfaces.
enum StudioEnvironment {
    @MainActor private static var cache: [String: EnvironmentResource] = [:]

    @MainActor
    static func make(tint: [UIColor]) async throws -> EnvironmentResource {
        let key = tint.prefix(4).map { color -> String in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return "\(Int(r * 255))-\(Int(g * 255))-\(Int(b * 255))"
        }.joined(separator: "_")
        if let cached = cache[key] { return cached }
        // Render the 1024×512 equirectangular IBL off the main actor to avoid launch/open hitches.
        let image = await Task.detached(priority: .userInitiated) {
            render(tint: tint)
        }.value
        let resource = try await EnvironmentResource(equirectangular: image, withName: "studio-\(key)")
        cache[key] = resource
        return resource
    }

    static func render(tint: [UIColor], size: CGSize = CGSize(width: 1024, height: 512)) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()

            let sky = CGGradient(colorsSpace: space, colors: [
                UIColor(red: 0.30, green: 0.32, blue: 0.38, alpha: 1).cgColor,
                UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1).cgColor,
                UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1).cgColor,
            ] as CFArray, locations: [0, 0.5, 1])!
            cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            func softbox(_ center: CGPoint, _ radius: CGFloat, _ color: UIColor) {
                let g = CGGradient(colorsSpace: space, colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
                cg.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
            }
            // Big overhead light and two side strips.
            softbox(CGPoint(x: size.width * 0.5, y: size.height * 0.08), size.height * 0.45, .white)
            softbox(CGPoint(x: size.width * 0.25, y: size.height * 0.42), size.height * 0.22, UIColor(red: 1, green: 0.9, blue: 0.8, alpha: 0.95))
            softbox(CGPoint(x: size.width * 0.75, y: size.height * 0.42), size.height * 0.22, UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 0.95))
            // Colored bounce from the card's foil.
            for (i, color) in tint.prefix(4).enumerated() {
                let x = size.width * (0.12 + 0.25 * CGFloat(i))
                softbox(CGPoint(x: x, y: size.height * 0.62), size.height * 0.18, color.withAlphaComponent(0.8))
            }
        }
        return image.cgImage!
    }
}

/// Owns a single persistent RealityKit scene graph and spin physics outside SwiftUI state.
/// Swapping models and IBL environments in-place keeps one `RealityView` / `CAMetalLayer` alive across
/// card switches, eliminating iOS hardware EDR/compositor screen flashes.
@MainActor
final class ModelRig {
    let root = Entity()
    let tiltPivot = Entity()
    let spinPivot = Entity()
    let zoomPivot = Entity()
    let iblLightEntity = Entity()

    var yaw: Float = -0.5
    var pitch: Float = 0.12
    var velocity = SIMD2<Float>(0, 0)
    var dragging = false
    var zoom: Float = 1
    var idleSpin: Float = 0.45
    var loadedModel: Entity?
    var appliedFinishID: String?
    var iblReceiver: ImageBasedLightReceiverComponent?

    private(set) var targetModelID: String?
    private(set) var displayedModelID: String?
    private var appliedAssetName: String?
    private var appliedModelKey: HeadphoneModelKey?
    private var appliedTintKey: String?
    private var latestFinish: HeadphoneFinish?
    private var latestFinishID: String?
    private var loadTask: Task<Void, Never>?
    private var subscription: EventSubscription?
    private var lastTranslation: CGSize = .zero

    private var isVisible = false
    private var reduceMotion = false
    private var visualOpacity: Float = 0
    private var warmupFramesRemaining = 0
    private var pendingReadyModelID: String?
    private var pendingReadyCallback: ((String) -> Void)?
    private var lastProcessedHideToken = 0
    private var hiddenConfirmFramesRemaining = 0
    private var pendingHiddenToken: Int?
    private var pendingHiddenCallback: ((Int) -> Void)?

    init() {
        root.addChild(tiltPivot)
        tiltPivot.addChild(zoomPivot)
        zoomPivot.addChild(spinPivot)
        spinPivot.isEnabled = false
    }

    func attach(to content: RealityViewCameraContent) {
        content.add(root)
        content.add(iblLightEntity)
        iblReceiver = ImageBasedLightReceiverComponent(imageBasedLight: iblLightEntity)
        step(0)
        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated {
                self?.tick(Float(event.deltaTime))
            }
        }
    }

    func syncModel(
        modelID: String,
        kind: HeadphoneKind,
        finish: HeadphoneFinish,
        finishID: String,
        modelKey: HeadphoneModelKey,
        assetName: String?,
        modelSize: Float,
        tint: [UIColor],
        tintKey: String,
        tilt: CGSize,
        isVisible: Bool,
        reduceMotion: Bool,
        hideToken: Int = 0,
        onModelReady: @escaping (String) -> Void,
        onHiddenConfirmed: @escaping (Int) -> Void = { _ in }
    ) {
        self.reduceMotion = reduceMotion
        self.idleSpin = reduceMotion ? 0 : 0.45
        self.latestFinish = finish
        self.latestFinishID = finishID
        self.isVisible = isVisible
        applyTilt(tilt)

        if hideToken != lastProcessedHideToken {
            lastProcessedHideToken = hideToken
            let wasRendered = spinPivot.isEnabled || visualOpacity > 0 || warmupFramesRemaining > 0
            if loadTask != nil || displayedModelID != targetModelID || loadedModel == nil {
                targetModelID = nil
                appliedAssetName = nil
                appliedModelKey = nil
            }
            loadTask?.cancel()
            loadTask = nil
            warmupFramesRemaining = 0
            pendingReadyModelID = nil
            pendingReadyCallback = nil
            hideImmediately()
            pendingHiddenToken = hideToken
            pendingHiddenCallback = onHiddenConfirmed
            hiddenConfirmFramesRemaining = wasRendered ? 2 : 1
            return
        }

        if hiddenConfirmFramesRemaining > 0 {
            pendingHiddenCallback = onHiddenConfirmed
            if spinPivot.isEnabled { hideImmediately() }
            return
        }

        let modelChanged = targetModelID != modelID
            || appliedAssetName != assetName
            || appliedModelKey != modelKey

        if modelChanged {
            loadTask?.cancel()
            loadTask = nil
            targetModelID = modelID
            appliedAssetName = assetName
            appliedModelKey = modelKey
            pendingReadyModelID = nil
            pendingReadyCallback = nil
            warmupFramesRemaining = 0
            hideImmediately()

            guard let assetName else {
                clearLoadedModel()
                return
            }

            let requestedTintKey = tintKey
            loadTask = Task { @MainActor [weak self] in
                guard let self else { return }
                let resolvedFinish = self.latestFinish ?? finish
                let resolvedFinishID = self.latestFinishID ?? finishID

                async let environment = try? StudioEnvironment.make(tint: tint)
                let nextModel = await HeadphoneModelLoader.load(
                    kind,
                    finish: resolvedFinish,
                    assetName: assetName,
                    modelKey: modelKey,
                    size: modelSize
                )
                let studioLighting = await environment
                guard !Task.isCancelled, self.targetModelID == modelID else { return }

                // Apply the latest color in case the user tapped a swatch while the model was loading.
                let finalFinish = self.latestFinish ?? resolvedFinish
                let finalFinishID = self.latestFinishID ?? resolvedFinishID
                let finalModel: Entity
                if finalFinishID != resolvedFinishID {
                    if assetName.isEmpty {
                        finalModel = HeadphoneModelLoader.normalized(
                            ProceduralHeadphones.make(kind, finish: finalFinish),
                            size: modelSize
                        )
                    } else {
                        HeadphoneModelLoader.applyFinish(finalFinish, to: nextModel, modelKey: modelKey)
                        finalModel = nextModel
                    }
                } else {
                    finalModel = nextModel
                }

                self.installModel(
                    finalModel,
                    modelID: modelID,
                    finishID: finalFinishID,
                    studioLighting: studioLighting,
                    tintKey: requestedTintKey,
                    onModelReady: onModelReady
                )
            }
            return
        }

        // Same model: apply live finish updates in place without resetting spin orientation.
        if displayedModelID == modelID, let currentModel = loadedModel, appliedFinishID != finishID {
            appliedFinishID = finishID
            if (assetName ?? kind.assetName).isEmpty {
                let replacement = HeadphoneModelLoader.normalized(
                    ProceduralHeadphones.make(kind, finish: finish),
                    size: modelSize
                )
                if let receiver = iblReceiver {
                    applyReceiver(receiver, to: replacement)
                }
                currentModel.removeFromParent()
                spinPivot.addChild(replacement)
                loadedModel = replacement
            } else {
                HeadphoneModelLoader.applyFinish(finish, to: currentModel, modelKey: modelKey)
            }
        }

        // Hide synchronously on the exact frame a swipe or flip begins so the old model never ghosts.
        if !isVisible && warmupFramesRemaining == 0 {
            hideImmediately()
        }
    }

    func installModel(
        _ model: Entity,
        modelID: String,
        finishID: String,
        studioLighting: EnvironmentResource?,
        tintKey: String,
        onModelReady: @escaping (String) -> Void
    ) {
        loadedModel?.removeFromParent()
        yaw = -0.5
        pitch = 0.12
        velocity = .zero
        zoom = 1
        dragging = false
        zoomPivot.scale = SIMD3(repeating: 1)
        step(0)

        if let studioLighting, appliedTintKey != tintKey {
            iblLightEntity.components.set(ImageBasedLightComponent(source: .single(studioLighting), intensityExponent: 1.3))
            appliedTintKey = tintKey
        }
        if let receiver = iblReceiver {
            applyReceiver(receiver, to: model)
        }

        spinPivot.addChild(model)
        loadedModel = model
        displayedModelID = modelID
        appliedFinishID = finishID

        // Render 2 invisible GPU warmup ticks so shaders & textures upload before revealing.
        visualOpacity = 0
        warmupFramesRemaining = 2
        pendingReadyModelID = modelID
        pendingReadyCallback = onModelReady
        spinPivot.isEnabled = true
        spinPivot.components.set(OpacityComponent(opacity: 0.001))
    }

    func clearLoadedModel() {
        loadedModel?.removeFromParent()
        loadedModel = nil
        displayedModelID = nil
        appliedFinishID = nil
        hideImmediately()
    }

    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func hideImmediately() {
        visualOpacity = 0
        spinPivot.isEnabled = false
        spinPivot.components.remove(OpacityComponent.self)
    }

    private func tick(_ dt: Float) {
        step(dt)

        if hiddenConfirmFramesRemaining > 0 {
            if spinPivot.isEnabled { hideImmediately() }
            hiddenConfirmFramesRemaining -= 1
            if hiddenConfirmFramesRemaining == 0 {
                let token = pendingHiddenToken
                let callback = pendingHiddenCallback
                pendingHiddenToken = nil
                pendingHiddenCallback = nil
                if let token, let callback {
                    callback(token)
                }
            }
            return
        }

        if warmupFramesRemaining > 0 {
            warmupFramesRemaining -= 1
            if warmupFramesRemaining == 0 {
                let readyID = pendingReadyModelID
                let callback = pendingReadyCallback
                pendingReadyModelID = nil
                pendingReadyCallback = nil
                if !isVisible {
                    hideImmediately()
                }
                if let readyID, let callback {
                    callback(readyID)
                }
            }
            return
        }

        if isVisible && loadedModel != nil {
            if !spinPivot.isEnabled {
                spinPivot.isEnabled = true
            }
            if visualOpacity < 1 {
                let clampedDt = min(dt, 1 / 20)
                visualOpacity = reduceMotion ? 1 : min(1, visualOpacity + clampedDt * 6.5)
                if visualOpacity >= 0.999 {
                    visualOpacity = 1
                    // Remove OpacityComponent once opaque so RealityKit uses standard depth-buffered PBR rendering.
                    spinPivot.components.remove(OpacityComponent.self)
                } else {
                    spinPivot.components.set(OpacityComponent(opacity: max(0.001, visualOpacity)))
                }
            }
        } else if spinPivot.isEnabled || visualOpacity > 0 {
            hideImmediately()
        }
    }

    private func applyReceiver(_ receiver: ImageBasedLightReceiverComponent, to entity: Entity) {
        entity.components.set(receiver)
        for child in entity.children { applyReceiver(receiver, to: child) }
    }

    func step(_ dt: Float) {
        let dt = min(dt, 1 / 20)
        let current = zoomPivot.scale.x
        zoomPivot.scale = SIMD3(repeating: current + (zoom - current) * min(1, dt * 10))

        if !dragging {
            yaw += velocity.x * dt
            pitch += velocity.y * dt
            velocity *= pow(0.06, dt)
            let calm = max(0, 1 - simd_length(velocity) / 1.5)
            yaw += idleSpin * dt * calm
            pitch += (0.12 - pitch) * min(1, dt * 2.5) * calm
        }
        pitch = max(-1.1, min(1.1, pitch))
        spinPivot.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
    }

    func applyTilt(_ tilt: CGSize) {
        tiltPivot.orientation = simd_quatf(angle: Float(tilt.width) * 0.45, axis: [0, 1, 0])
            * simd_quatf(angle: Float(tilt.height) * 0.3, axis: [1, 0, 0])
    }

    func dragChanged(_ value: DragGesture.Value) {
        if !dragging { lastTranslation = .zero; dragging = true }
        let dx = Float(value.translation.width - lastTranslation.width)
        let dy = Float(value.translation.height - lastTranslation.height)
        lastTranslation = value.translation
        yaw += dx * 0.012
        pitch += dy * 0.009
    }

    func dragEnded(_ value: DragGesture.Value) {
        dragging = false
        velocity = SIMD2(Float(value.velocity.width) * 0.012, Float(value.velocity.height) * 0.009)
        velocity = simd_clamp(velocity, SIMD2(repeating: -16), SIMD2(repeating: 16))
    }

    /// Resets interaction flags if iOS cancels the 3D drag/pinch gesture without delivering `onEnded`.
    func cancelInteractionIfNeeded() {
        if dragging {
            dragging = false
        }
        if zoom != 1 {
            zoom = 1
        }
    }

    /// A playful 360° spin, e.g. after a long press.
    func twirl() {
        velocity.x += 14
    }

    func stepFrameForTesting(_ dt: Float) {
        tick(dt)
    }
}

/// Interactive persistent 3D headphone stage: drag to spin with momentum, pinch to zoom, tilt the phone for parallax.
/// Keeps a single `RealityView` mounted across card switches to avoid Metal / EDR compositor flashes.
struct HeadphoneModelView: View {
    var modelID: String = "default"
    let kind: HeadphoneKind
    let finish: HeadphoneFinish
    var finishID: String = "default"
    var modelKey: HeadphoneModelKey = .overEarGeneric
    var assetName: String? = nil
    var modelSize: Float = 0.145
    var tint: [UIColor] = []
    var tintKey: String = ""
    var tilt: CGSize = .zero
    var isVisible: Bool = true
    var hideToken: Int = 0
    var onTap: (() -> Void)? = nil
    var onManipulationChanged: (Bool) -> Void = { _ in }
    var onModelReady: (String) -> Void = { _ in }
    var onHiddenConfirmed: (Int) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rig = ModelRig()
    @State private var twirls = 0
    @GestureState private var isManipulating = false

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 26
            camera.position = [0, 0, 0.52]
            content.add(camera)

            let key = DirectionalLight()
            key.light.intensity = 3600
            key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 1, depthBias: 2)
            key.look(at: .zero, from: [0.4, 0.6, 0.5], relativeTo: nil)
            content.add(key)

            let fill = DirectionalLight()
            fill.light.intensity = 1400
            fill.look(at: .zero, from: [-0.3, 0.1, 0.8], relativeTo: nil)
            content.add(fill)

            let rim = DirectionalLight()
            rim.light.intensity = 900
            rim.light.color = UIColor(red: 0.7, green: 0.85, blue: 1, alpha: 1)
            rim.look(at: .zero, from: [-0.5, 0.2, -0.6], relativeTo: nil)
            content.add(rim)

            rig.attach(to: content)
            rig.syncModel(
                modelID: modelID,
                kind: kind,
                finish: finish,
                finishID: finishID,
                modelKey: modelKey,
                assetName: assetName,
                modelSize: modelSize,
                tint: tint,
                tintKey: tintKey,
                tilt: tilt,
                isVisible: isVisible,
                reduceMotion: reduceMotion,
                hideToken: hideToken,
                onModelReady: onModelReady,
                onHiddenConfirmed: onHiddenConfirmed
            )
        } update: { _ in
            rig.syncModel(
                modelID: modelID,
                kind: kind,
                finish: finish,
                finishID: finishID,
                modelKey: modelKey,
                assetName: assetName,
                modelSize: modelSize,
                tint: tint,
                tintKey: tintKey,
                tilt: tilt,
                isVisible: isVisible,
                reduceMotion: reduceMotion,
                hideToken: hideToken,
                onModelReady: onModelReady,
                onHiddenConfirmed: onHiddenConfirmed
            )
        }
        // Keep outer margins free for swiping the card to switch between pairs.
        .contentShape(.interaction, Rectangle().scale(x: 0.56, y: 0.72))
        .onTapGesture {
            onTap?()
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { rig.dragChanged($0) }
                .onEnded { rig.dragEnded($0) }
                .simultaneously(with:
                    MagnifyGesture()
                        .onChanged { rig.zoom = Float(max(0.75, min(1.35, $0.magnification))) }
                        .onEnded { _ in rig.zoom = 1 })
                .updating($isManipulating) { _, active, _ in active = true }
        )
        .onChange(of: isManipulating) { _, active in
            if !active {
                rig.cancelInteractionIfNeeded()
            }
            onManipulationChanged(active)
        }
        .onDisappear {
            rig.cancelLoad()
            if isManipulating { onManipulationChanged(false) }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            rig.twirl()
            twirls += 1
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: twirls)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("3D model. Drag to spin, pinch to zoom, long press to twirl.")
    }
}

extension Rarity {
    /// Cached UIColor tint array for RealityKit IBL so view bodies never allocate per-frame arrays.
    private static let cachedStudioTints: [Rarity: [UIColor]] = Dictionary(
        uniqueKeysWithValues: Rarity.allCases.map { ($0, $0.baseColors.map { UIColor($0) }) }
    )

    var studioTint: [UIColor] {
        Self.cachedStudioTints[self] ?? []
    }
}

extension HeadphoneCard {
    var finish: HeadphoneFinish {
        switch kind {
        case .overEar: rarity == .holo ? .skyBlue : .spaceGray
        case .earbuds: .glossWhite
        case .sportBuds: .matteBlack
        }
    }

    var foilTint: [UIColor] { rarity.studioTint }

    /// The bundled model for this product family, when available.
    var modelAssetName: String? { modelKey.collectibleModel }
}
