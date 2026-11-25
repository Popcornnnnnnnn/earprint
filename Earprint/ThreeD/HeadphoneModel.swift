import RealityKit
import UIKit

/// Which 3D model a card shows.
enum HeadphoneKind: String, Codable {
    case overEar
    case earbuds
    case sportBuds

    /// Optional USDZ in the app bundle that replaces the procedural model.
    var assetName: String {
        switch self {
        case .overEar: "AirPodsMax"
        case .earbuds: "AirPodsPro"
        case .sportBuds: "HeadphoneGeneric"
        }
    }
}

/// Colors and surface feel of a model.
struct HeadphoneFinish {
    var shell: UIColor
    var accent: UIColor
    var cushion: UIColor
    var metallic: Float = 0.85
    var roughness: Float = 0.32

    static let skyBlue = HeadphoneFinish(shell: UIColor(red: 0.62, green: 0.76, blue: 0.86, alpha: 1),
                                         accent: UIColor(red: 0.80, green: 0.88, blue: 0.93, alpha: 1),
                                         cushion: UIColor(red: 0.55, green: 0.66, blue: 0.75, alpha: 1))
    static let spaceGray = HeadphoneFinish(shell: UIColor(white: 0.36, alpha: 1),
                                           accent: UIColor(white: 0.22, alpha: 1),
                                           cushion: UIColor(white: 0.16, alpha: 1))
    static let glossWhite = HeadphoneFinish(shell: UIColor(white: 0.97, alpha: 1),
                                            accent: UIColor(white: 0.85, alpha: 1),
                                            cushion: UIColor(white: 0.75, alpha: 1),
                                            metallic: 0.0, roughness: 0.18)
    static let matteBlack = HeadphoneFinish(shell: UIColor(white: 0.10, alpha: 1),
                                            accent: UIColor(red: 0.95, green: 0.25, blue: 0.30, alpha: 1),
                                            cushion: UIColor(white: 0.20, alpha: 1),
                                            metallic: 0.1, roughness: 0.55)
}

/// Original, trademark-safe headphone models built from code. Used until (or instead of) USDZ assets.
enum ProceduralHeadphones {
    @MainActor
    static func make(_ kind: HeadphoneKind, finish: HeadphoneFinish) -> Entity {
        switch kind {
        case .overEar: overEar(finish)
        case .earbuds: earbuds(finish, withCase: true)
        case .sportBuds: earbuds(finish, withCase: false)
        }
    }

    // MARK: Over-ear

    @MainActor
    private static func overEar(_ f: HeadphoneFinish) -> Entity {
        let root = Entity()
        let steel = pbr(UIColor(white: 0.86, alpha: 1), metallic: 1, roughness: 0.22)
        let shell = pbr(f.shell, metallic: f.metallic, roughness: f.roughness, clearcoat: 0.3)
        let canopy = pbr(f.accent, metallic: 0, roughness: 0.85)
        let fabric = pbr(f.cushion, metallic: 0, roughness: 1)

        let radius: Float = 0.088
        let lift: Float = 0.03
        let start: Float = .pi * 0.1, end: Float = .pi * 0.9

        if let band = try? arcTube(radius: radius, radial: 0.0042, depth: 0.0042, from: start, to: end) {
            let e = ModelEntity(mesh: band, materials: [steel])
            e.position.y = lift
            root.addChild(e)
        }
        if let mesh = try? arcTube(radius: radius - 0.013, radial: 0.0025, depth: 0.017, from: .pi * 0.15, to: .pi * 0.85) {
            let e = ModelEntity(mesh: mesh, materials: [canopy])
            e.position.y = lift
            root.addChild(e)
        }

        for side: Float in [1, -1] {
            let angle = side > 0 ? start : end
            let ex = radius * cos(angle), ey = radius * sin(angle) + lift
            let cap = ModelEntity(mesh: .generateSphere(radius: 0.0052), materials: [steel])
            cap.position = [ex, ey, 0]
            root.addChild(cap)

            let stemLength: Float = 0.036
            let stem = ModelEntity(mesh: .generateCylinder(height: stemLength, radius: 0.0034), materials: [steel])
            stem.position = [ex, ey - stemLength / 2, 0]
            root.addChild(stem)

            let cupY = ey - stemLength - 0.042
            let cup = ModelEntity(mesh: .generateBox(width: 0.034, height: 0.09, depth: 0.074, cornerRadius: 0.017), materials: [shell])
            cup.position = [ex + side * 0.004, cupY, 0]
            root.addChild(cup)

            let cushion = ModelEntity(mesh: .generateBox(width: 0.022, height: 0.082, depth: 0.066, cornerRadius: 0.013), materials: [fabric])
            cushion.position = [ex - side * 0.021, cupY, 0]
            root.addChild(cushion)

            let mount = ModelEntity(mesh: .generateBox(width: 0.012, height: 0.01, depth: 0.03, cornerRadius: 0.004), materials: [steel])
            mount.position = [ex + side * 0.002, cupY + 0.047, 0]
            root.addChild(mount)

            if side > 0 {
                let crown = ModelEntity(mesh: .generateCylinder(height: 0.008, radius: 0.0055), materials: [steel])
                crown.position = [ex + 0.008, cupY + 0.048, -0.022]
                root.addChild(crown)
                let button = ModelEntity(mesh: .generateBox(width: 0.004, height: 0.004, depth: 0.014, cornerRadius: 0.0018), materials: [steel])
                button.position = [ex + 0.008, cupY + 0.046, 0.016]
                root.addChild(button)
            }
        }
        return root
    }

    // MARK: Earbuds

    @MainActor
    private static func earbuds(_ f: HeadphoneFinish, withCase: Bool) -> Entity {
        let root = Entity()
        let body = pbr(f.shell, metallic: f.metallic, roughness: f.roughness, clearcoat: 0.6)
        let tip = pbr(f.cushion, metallic: 0, roughness: 0.9)
        let grille = pbr(UIColor(white: 0.15, alpha: 1), metallic: 0.6, roughness: 0.5)

        if withCase {
            let base = ModelEntity(mesh: .generateBox(width: 0.062, height: 0.034, depth: 0.024, cornerRadius: 0.011), materials: [body])
            base.position = [0, -0.035, 0]
            root.addChild(base)
            let lid = ModelEntity(mesh: .generateBox(width: 0.062, height: 0.016, depth: 0.024, cornerRadius: 0.008), materials: [body])
            // Hinged at the top back edge, opened about 110 degrees.
            lid.position = [0, -0.0092, -0.0235]
            lid.orientation = simd_quatf(angle: -1.9, axis: [1, 0, 0])
            root.addChild(lid)
            let led = ModelEntity(mesh: .generateSphere(radius: 0.0015), materials: [UnlitMaterial(color: UIColor(red: 0.3, green: 1, blue: 0.5, alpha: 1))])
            led.position = [0, -0.03, 0.0122]
            root.addChild(led)
        }

        for side: Float in [-1, 1] {
            let bud = Entity()
            let head = ModelEntity(mesh: .generateSphere(radius: 0.0115), materials: [body])
            head.scale = [1, 0.9, 1.1]
            bud.addChild(head)
            let earTip = ModelEntity(mesh: .generateSphere(radius: 0.0072), materials: [tip])
            earTip.position = [side * -0.009, 0.002, 0.004]
            bud.addChild(earTip)
            let mesh = ModelEntity(mesh: .generateCylinder(height: 0.0012, radius: 0.0035), materials: [grille])
            mesh.position = [side * 0.006, 0.006, -0.006]
            mesh.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            bud.addChild(mesh)
            let stem = ModelEntity(mesh: .generateBox(width: 0.0062, height: 0.03, depth: 0.0068, cornerRadius: 0.003), materials: [body])
            stem.position = [side * 0.003, -0.02, 0]
            bud.addChild(stem)

            bud.position = withCase ? [side * 0.022, 0.025, 0.006] : [side * 0.024, 0, 0]
            bud.orientation = simd_quatf(angle: side * 0.25, axis: [0, 0, 1]) * simd_quatf(angle: side * 0.5, axis: [0, 1, 0])
            root.addChild(bud)
        }
        return root
    }

    // MARK: Helpers

    @MainActor
    static func pbr(_ color: UIColor, metallic: Float, roughness: Float, clearcoat: Float = 0) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.metallic = .init(floatLiteral: metallic)
        m.roughness = .init(floatLiteral: roughness)
        m.clearcoat = .init(floatLiteral: clearcoat)
        m.faceCulling = .none
        return m
    }

    /// A tube swept along a circular arc in the XY plane, with an elliptical cross-section.
    @MainActor
    static func arcTube(radius: Float, radial: Float, depth: Float, from a0: Float, to a1: Float,
                        segments: Int = 64, sides: Int = 20) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let ring = sides + 1
        for i in 0...segments {
            let a = a0 + (a1 - a0) * Float(i) / Float(segments)
            let center = SIMD3<Float>(radius * cos(a), radius * sin(a), 0)
            let n = SIMD3<Float>(cos(a), sin(a), 0)
            let b = SIMD3<Float>(0, 0, 1)
            for j in 0...sides {
                let t = Float(j) / Float(sides) * 2 * .pi
                positions.append(center + radial * cos(t) * n + depth * sin(t) * b)
                normals.append(simd_normalize(cos(t) / radial * n + sin(t) / depth * b))
            }
        }
        for i in 0..<segments {
            for j in 0..<sides {
                let p = UInt32(i * ring + j), q = UInt32((i + 1) * ring + j)
                indices += [p, q, p + 1, p + 1, q, q + 1]
            }
        }
        var descriptor = MeshDescriptor(name: "arcTube")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

enum HeadphoneModelLoader {
    /// In-memory cache of parsed USDZ templates so switching cards clones in <1ms instead of re-reading MBs from disk.
    @MainActor private static var templateCache: [String: Entity] = [:]
    /// Deduplicates concurrent `prewarm` and `load` calls for the same USDZ asset.
    @MainActor private static var inFlightTemplates: [String: Task<Entity?, Never>] = [:]
    /// Neutral-luminance `TextureResource` cache so canopy & knit cushion recolors stay bright and keep their stitch detail.
    @MainActor private static var neutralTextureCache: [String: TextureResource] = [:]

    /// AirPodsMax.usdz entity/material buckets discovered via `usdcat`.
    /// RealityKit drops read-only `pbr.name` after mutating textured materials, so we match by immutable
    /// `ModelEntity.name` first (with `pbr.name` as fallback) so repeated switches always work.
    private enum AirPodsMaxZone {
        case shell
        case outerCushion
        case accent
        case canopyOuter
        case canopyInner
        case cushion
    }

    private static let airPodsMaxZonesByEntity: [String: AirPodsMaxZone] = [
        "BNOZVCaFckcMAnz": .shell,
        "sYTnpMcquiOFLQg": .shell,
        "LSwgFSweioaiCgt": .outerCushion,
        "YmaGKZDKmTWUQJE": .accent,
        "alKkbNxYSoLInGi": .accent,
        "AExPvRSHRbARooZ": .canopyOuter,
        "AANWpKMFljrFwQj": .canopyInner,
        "QVkyuxLuHiwiZGe": .cushion,
        "PNdaALJHbSHKuWS": .cushion,
        "XiPhiAhstHJZhhW": .cushion,
        "JuHOxdrOCIBfkqg": .cushion,
        "WWtYjswGShSaNES": .cushion,
    ]

    private static let airPodsMaxZonesByMaterial: [String: AirPodsMaxZone] = [
        "oCppDZKIKMUCOIr": .shell,
        "IONYLTjXhCrWCDx": .shell,
        "DiaLtZsVVXWBwMe": .outerCushion,
        "CufifJQVFGKEXjK": .accent,
        "XnHBntWOhvrYYYt": .accent,
        "DeFxnmzQHJkzqmx": .canopyOuter,
        "DpauuenuPBdCvhC": .canopyInner,
        "OeMmmEEWkMBwwgR": .cushion,
        "fZEVSQIaNKfmlij": .cushion,
        "KUwCKTokDcQQstJ": .cushion,
        "ZezcrAosYheapOP": .cushion,
        "FwxSMPpHOYcEPUc": .cushion,
    ]

    @MainActor
    private static func neutralTexture(named assetName: String) -> TextureResource? {
        if let cached = neutralTextureCache[assetName] {
            return cached
        }
        guard let cgImage = UIImage(named: assetName)?.cgImage,
              let resource = try? TextureResource(image: cgImage, options: .init(semantic: .color)) else {
            return nil
        }
        neutralTextureCache[assetName] = resource
        return resource
    }

    @MainActor
    private static func loadTemplate(named assetName: String) async -> Entity? {
        guard !assetName.isEmpty,
              Bundle.main.url(forResource: assetName, withExtension: "usdz") != nil else { return nil }
        if let cached = templateCache[assetName] {
            return cached
        }
        if let existing = inFlightTemplates[assetName] {
            return await existing.value
        }
        let task = Task<Entity?, Never> { @MainActor in
            let entity = try? await Entity(named: assetName, in: .main)
            if let entity {
                templateCache[assetName] = entity
            }
            inFlightTemplates[assetName] = nil
            return entity
        }
        inFlightTemplates[assetName] = task
        return await task.value
    }

    /// Pre-loads a USDZ template into `templateCache` ahead of card switches so settling is hitch-free.
    @MainActor
    static func prewarm(assetName: String) async {
        _ = await loadTemplate(named: assetName)
    }

    /// Loads the bundled USDZ if present (cached & cloned for instant card switching), otherwise the procedural model.
    @MainActor
    static func load(_ kind: HeadphoneKind, finish: HeadphoneFinish, assetName: String? = nil, modelKey: HeadphoneModelKey = .overEarGeneric, size: Float = 0.2) async -> Entity {
        let model: Entity
        let resolvedName = assetName ?? kind.assetName
        let loadedFromUSDZ: Bool
        if let template = await loadTemplate(named: resolvedName) {
            model = template.clone(recursive: true)
            loadedFromUSDZ = true
        } else {
            model = ProceduralHeadphones.make(kind, finish: finish)
            loadedFromUSDZ = false
        }
        let wrapped = normalized(model, size: size)
        if loadedFromUSDZ {
            applyFinish(finish, to: wrapped, modelKey: modelKey)
        }
        return wrapped
    }

    /// Updates materials on an already-loaded 3D entity in place when the user changes device color.
    private enum BeatsZone {
        case shell
        case inner
        case accent
        case wing
        case cushion
        case metal
        case grille

        init?(name: String) {
            if name.contains("Zone_Shell") || name.contains("Mat_Shell") { self = .shell }
            else if name.contains("Zone_Inner") || name.contains("Mat_Inner") { self = .inner }
            else if name.contains("Zone_Accent") || name.contains("Mat_Accent") { self = .accent }
            else if name.contains("Zone_Wing") || name.contains("Mat_Wing") { self = .wing }
            else if name.contains("Zone_Cushion") || name.contains("Mat_Cushion") { self = .cushion }
            else if name.contains("Zone_Metal") || name.contains("Mat_Metal") { self = .metal }
            else if name.contains("Zone_Grille") || name.contains("Mat_Grille") { self = .grille }
            else { return nil }
        }
    }

    @MainActor
    static func applyFinish(_ finish: HeadphoneFinish, to entity: Entity, modelKey: HeadphoneModelKey) {
        switch modelKey {
        case .airpodsMax:
            recolorAirPodsMax(entity, finish: finish)
        case .beatsEarbuds, .beatsEarhook, .beatsOverEar:
            recolorBeatsModel(entity, finish: finish)
        case .overEarGeneric:
            // Preserve HeadphoneGeneric.usdz's baked studio PBR textures.
            break
        default:
            break
        }
    }

    private static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0.5 }
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    @MainActor
    private static func recolorBeatsModel(_ entity: Entity, finish: HeadphoneFinish) {
        let shellLum = relativeLuminance(finish.shell)
        let metalTint: UIColor = shellLum < 0.24
            ? UIColor(white: 0.44, alpha: 1)
            : blendColor(finish.accent, UIColor(white: 0.90, alpha: 1), amount: 0.45)

        func applyRecursive(_ node: Entity) {
            if let modelEntity = node as? ModelEntity, var modelComp = modelEntity.model {
                let candidateName = "\(modelEntity.name)|\(modelEntity.parent?.name ?? "")"
                var changed = false
                modelComp.materials = modelComp.materials.map { material in
                    guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                    let zone = BeatsZone(name: candidateName) ?? BeatsZone(name: pbr.name ?? "")
                    guard let zone else { return material }
                    switch zone {
                    case .shell:
                        pbr.baseColor = .init(tint: finish.shell)
                        pbr.metallic = .init(floatLiteral: finish.metallic)
                        pbr.roughness = .init(floatLiteral: finish.roughness)
                        pbr.clearcoat = .init(floatLiteral: 0.20)
                    case .inner:
                        pbr.baseColor = .init(tint: finish.cushion)
                        pbr.metallic = .init(floatLiteral: 0.08)
                        pbr.roughness = .init(floatLiteral: min(0.62, finish.roughness + 0.14))
                        pbr.clearcoat = .init(floatLiteral: 0.04)
                    case .accent:
                        pbr.baseColor = .init(tint: finish.accent)
                        pbr.metallic = .init(floatLiteral: 0.72)
                        pbr.roughness = .init(floatLiteral: 0.26)
                        pbr.clearcoat = .init(floatLiteral: 0.20)
                    case .wing:
                        pbr.baseColor = .init(tint: finish.cushion)
                        pbr.metallic = .init(floatLiteral: 0.0)
                        pbr.roughness = .init(floatLiteral: 0.60)
                        pbr.clearcoat = .init(floatLiteral: 0.02)
                    case .cushion:
                        pbr.baseColor = .init(tint: finish.cushion)
                        pbr.metallic = .init(floatLiteral: 0.0)
                        pbr.roughness = .init(floatLiteral: 0.56)
                        pbr.clearcoat = .init(floatLiteral: 0.0)
                    case .metal:
                        pbr.baseColor = .init(tint: metalTint)
                        pbr.metallic = .init(floatLiteral: 0.88)
                        pbr.roughness = .init(floatLiteral: 0.22)
                        pbr.clearcoat = .init(floatLiteral: 0.12)
                    case .grille:
                        pbr.baseColor = .init(tint: UIColor(red: 0.05, green: 0.055, blue: 0.065, alpha: 1))
                        pbr.metallic = .init(floatLiteral: 0.35)
                        pbr.roughness = .init(floatLiteral: 0.55)
                        pbr.clearcoat = .init(floatLiteral: 0.0)
                    }
                    changed = true
                    return pbr
                }
                if changed {
                    modelEntity.model = modelComp
                }
            }
            for child in node.children {
                applyRecursive(child)
            }
        }
        applyRecursive(entity)
    }

    private static func blendColor(_ a: UIColor, _ b: UIColor, amount: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        guard a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa),
              b.getRed(&br, green: &bg, blue: &bb, alpha: &ba) else { return a }
        let t = max(0, min(1, amount))
        return UIColor(
            red: ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue: ab + (bb - ab) * t,
            alpha: 1
        )
    }

    @MainActor
    private static func recolorAirPodsMax(_ entity: Entity, finish: HeadphoneFinish) {
        if let modelEntity = entity as? ModelEntity, var modelComp = modelEntity.model {
            let zoneByEntity = airPodsMaxZonesByEntity[modelEntity.name]
            var changed = false
            modelComp.materials = modelComp.materials.map { material in
                guard var pbr = material as? PhysicallyBasedMaterial else {
                    return material
                }
                guard let zone = zoneByEntity ?? pbr.name.flatMap({ airPodsMaxZonesByMaterial[$0] }) else {
                    return material
                }

                switch zone {
                case .shell:
                    pbr.baseColor = .init(tint: finish.shell)
                    pbr.metallic = .init(floatLiteral: finish.metallic)
                    pbr.roughness = .init(floatLiteral: finish.roughness)
                case .outerCushion:
                    if let tex = neutralTexture(named: "AirPodsMaxCushionKnit") {
                        pbr.baseColor = .init(tint: finish.accent, texture: .init(tex))
                    } else {
                        pbr.baseColor = .init(tint: finish.accent)
                    }
                case .accent:
                    pbr.baseColor = .init(tint: finish.accent)
                case .canopyOuter:
                    if let tex = neutralTexture(named: "AirPodsMaxCanopyOuter") {
                        pbr.baseColor = .init(tint: finish.accent, texture: .init(tex))
                    } else {
                        pbr.baseColor.tint = finish.accent
                    }
                case .canopyInner:
                    if let tex = neutralTexture(named: "AirPodsMaxCanopyInner") {
                        pbr.baseColor = .init(tint: finish.accent, texture: .init(tex))
                    } else {
                        pbr.baseColor.tint = finish.accent
                    }
                case .cushion:
                    pbr.baseColor = .init(tint: finish.cushion)
                }

                changed = true
                return pbr
            }
            if changed {
                modelEntity.model = modelComp
            }
        }
        for child in entity.children {
            recolorAirPodsMax(child, finish: finish)
        }
    }

    @MainActor
    static func normalized(_ entity: Entity, size: Float) -> Entity {
        let wrapper = Entity()
        wrapper.addChild(entity)
        let bounds = entity.visualBounds(relativeTo: wrapper)
        let largest = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        guard largest > 0 else { return wrapper }
        let scale = size / largest
        entity.scale *= SIMD3<Float>(repeating: scale)
        entity.position = -bounds.center * scale
        return wrapper
    }
}
