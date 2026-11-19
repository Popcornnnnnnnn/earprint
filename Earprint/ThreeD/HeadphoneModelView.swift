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
        let image = render(tint: tint)
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

/// Owns the RealityKit scene graph and the spin physics, outside SwiftUI state.
@MainActor
final class ModelRig {
    let root = Entity()
    let tiltPivot = Entity()
    let spinPivot = Entity()
    let zoomPivot = Entity()

    var yaw: Float = -0.5
    var pitch: Float = 0.12
    var velocity = SIMD2<Float>(0, 0)
    var dragging = false
    var zoom: Float = 1
    var idleSpin: Float = 0.45
    var loadedModel: Entity?
    var appliedFinishID: String?
    var iblReceiver: ImageBasedLightReceiverComponent?
    private var subscription: EventSubscription?
    private var lastTranslation: CGSize = .zero

    init() {
        root.addChild(tiltPivot)
        tiltPivot.addChild(zoomPivot)
        zoomPivot.addChild(spinPivot)
    }

    func attach(to content: RealityViewCameraContent) {
        step(0)
        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.step(Float(event.deltaTime)) }
        }
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

    /// A playful 360° spin, e.g. after a long press.
    func twirl() {
        velocity.x += 14
    }
}

/// Interactive 3D headphone: drag to spin with momentum, pinch to zoom, tilt the phone for parallax.
struct HeadphoneModelView: View {
    let kind: HeadphoneKind
    let finish: HeadphoneFinish
    var finishID: String = "default"
    var modelKey: HeadphoneModelKey = .overEarGeneric
    var assetName: String? = nil
    var modelSize: Float = 0.145
    var tint: [UIColor] = []
    var tilt: CGSize = .zero
    var onManipulationChanged: (Bool) -> Void = { _ in }
    var onModelReady: () -> Void = {}

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

            async let environment = try? StudioEnvironment.make(tint: tint)
            let model = await HeadphoneModelLoader.load(kind, finish: finish, assetName: assetName, modelKey: modelKey, size: modelSize)
            let studioLighting = await environment
            guard !Task.isCancelled else { return }

            content.add(rig.root)
            rig.loadedModel = model
            rig.appliedFinishID = finishID
            rig.spinPivot.addChild(model)

            if let studioLighting {
                let light = Entity()
                light.components.set(ImageBasedLightComponent(source: .single(studioLighting), intensityExponent: 1.3))
                content.add(light)
                let receiver = ImageBasedLightReceiverComponent(imageBasedLight: light)
                rig.iblReceiver = receiver
                applyReceiver(receiver, to: model)
            }
            rig.attach(to: content)
            onModelReady()
        } update: { _ in
            rig.idleSpin = reduceMotion ? 0 : 0.45
            rig.applyTilt(tilt)
            if let currentModel = rig.loadedModel, rig.appliedFinishID != finishID {
                rig.appliedFinishID = finishID
                if (assetName ?? kind.assetName).isEmpty {
                    // Procedural model (e.g. Beats Fit Pro): swap smoothly in place keeping spin orientation.
                    let replacement = HeadphoneModelLoader.normalized(
                        ProceduralHeadphones.make(kind, finish: finish),
                        size: modelSize
                    )
                    if let receiver = rig.iblReceiver {
                        applyReceiver(receiver, to: replacement)
                    }
                    currentModel.removeFromParent()
                    rig.spinPivot.addChild(replacement)
                    rig.loadedModel = replacement
                } else {
                    HeadphoneModelLoader.applyFinish(finish, to: currentModel, modelKey: modelKey)
                }
            }
        }
        // Keep the transparent margins available for swiping the card.
        .contentShape(.interaction, Rectangle().scale(x: 0.67, y: 0.87))
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
        .onChange(of: isManipulating) { _, active in onManipulationChanged(active) }
        .onDisappear {
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

    private func applyReceiver(_ receiver: ImageBasedLightReceiverComponent, to entity: Entity) {
        entity.components.set(receiver)
        for child in entity.children { applyReceiver(receiver, to: child) }
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

    var foilTint: [UIColor] { rarity.baseColors.map { UIColor($0) } }

    /// The bundled model for this product family, when available.
    var modelAssetName: String? { modelKey.collectibleModel }
}
