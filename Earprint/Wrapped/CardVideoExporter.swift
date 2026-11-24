import AVFoundation
import CoreImage
import ImageIO
import Metal
import RealityKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
protocol CardVideoFrameRenderer {
    func frame(at progress: Double, size: CGSize) async throws -> CGImage
}

enum CardVideoExportError: Error {
    case invalidDuration, frameUnavailable, writerUnavailable, gifUnavailable, gifTooLarge
}

@MainActor
struct CardVideoExporter {
    enum Format: String {
        case mp4, gif

        var frameRate: Int { self == .mp4 ? 30 : 15 }
        var size: CGSize { self == .mp4 ? CGSize(width: 1080, height: 1920) : CGSize(width: 540, height: 960) }
    }

    let duration: TimeInterval

    init(duration: TimeInterval = 6) {
        self.duration = duration
    }

    func export(
        _ format: Format,
        summary: WrappedSummary,
        locale: Locale = .current,
        directory: URL = FileManager.default.temporaryDirectory,
        progress: (Double) -> Void = { _ in }
    ) async throws -> URL {
        let fallback = SwiftUICardVideoFallbackRenderer(summary: summary, locale: locale)
        let renderer = AutomaticCardVideoRenderer(
            primary: try? RealityCardVideoRenderer(summary: summary, locale: locale),
            fallback: fallback
        )
        return try await export(format, renderer: renderer, year: summary.year, directory: directory, progress: progress)
    }

    func export(
        _ format: Format,
        renderer: any CardVideoFrameRenderer,
        year: Int = 2026,
        directory: URL = FileManager.default.temporaryDirectory,
        progress: (Double) -> Void = { _ in }
    ) async throws -> URL {
        let frameCount = ceil(duration * Double(format.frameRate))
        guard frameCount.isFinite, frameCount > 0, frameCount < Double(Int.max) else {
            throw CardVideoExportError.invalidDuration
        }

        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Earprint-Wrapped-\(year)").appendingPathExtension(format.rawValue)
        do {
            progress(0)
            switch format {
            case .mp4:
                try await writeMovie(to: url, renderer: renderer, count: Int(frameCount), progress: progress)
            case .gif:
                try await writeGIF(to: url, renderer: renderer, count: Int(frameCount), progress: progress)
            }
            try Task.checkCancellation()
            progress(1)
            return url
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    private func writeMovie(
        to url: URL, renderer: any CardVideoFrameRenderer, count: Int, progress: (Double) -> Void
    ) async throws {
        let format = Format.mp4
        let width = Int(format.size.width)
        let height = Int(format.size.height)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000,
                                              AVVideoExpectedSourceFrameRateKey: format.frameRate]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])
        guard writer.canAdd(input) else { throw CardVideoExportError.writerUnavailable }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CardVideoExportError.writerUnavailable }
        defer {
            if writer.status == .writing { writer.cancelWriting() }
        }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw CardVideoExportError.writerUnavailable }
        let context = CIContext(options: [.cacheIntermediates: false])
        let clock = ContinuousClock()

        for index in 0..<count {
            try Task.checkCancellation()
            let deadline = clock.now.advanced(by: .seconds(5))
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing, clock.now < deadline else {
                    throw writer.error ?? CardVideoExportError.writerUnavailable
                }
                try await Task.sleep(for: .milliseconds(4))
            }
            let time = CMTime(value: Int64(index), timescale: Int32(format.frameRate))
            let image = try await renderer.frame(at: time.seconds / duration, size: format.size)
            try autoreleasepool {
                var buffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                      let buffer else { throw CardVideoExportError.frameUnavailable }
                context.render(CIImage(cgImage: image), to: buffer)
                guard adaptor.append(buffer, withPresentationTime: time) else {
                    throw writer.error ?? CardVideoExportError.writerUnavailable
                }
            }
            progress(Double(index + 1) / Double(count))
            await Task.yield()
        }

        writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 6_000))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CardVideoExportError.writerUnavailable }
    }

    private func writeGIF(
        to url: URL, renderer: any CardVideoFrameRenderer, count: Int, progress: (Double) -> Void
    ) async throws {
        for (index, sampling) in [1, 2, 4, 6].enumerated() {
            let candidate = url.deletingLastPathComponent().appendingPathComponent("candidate.gif")
            try await encodeGIF(to: candidate, renderer: renderer, count: count, sampling: sampling) {
                progress((Double(index) + $0) / 4)
            }
            let size = try candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            if size > 0 && size < 6_000_000 {
                try FileManager.default.moveItem(at: candidate, to: url)
                return
            }
            try FileManager.default.removeItem(at: candidate)
        }
        throw CardVideoExportError.gifTooLarge
    }

    private func encodeGIF(
        to url: URL, renderer: any CardVideoFrameRenderer, count: Int, sampling: Int,
        progress: (Double) -> Void
    ) async throws {
        let format = Format.gif
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, count, nil) else {
            throw CardVideoExportError.gifUnavailable
        }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let outputWidth = Int(format.size.width)
        let outputHeight = Int(format.size.height)
        let rate = Double(format.frameRate)

        for index in 0..<count {
            try Task.checkCancellation()
            let time = Double(index) / rate
            let image = try await renderer.frame(at: time / duration, size: format.size)
            try autoreleasepool {
                let frame = try gifFrame(image, width: outputWidth, height: outputHeight, sampling: sampling)
                // GIF stores delays in centiseconds. Rounding cumulative timestamps keeps the full loop at 6s.
                let delay = (min(duration, Double(index + 1) / rate) * 100).rounded() - (time * 100).rounded()
                CGImageDestinationAddImage(destination, frame, [
                    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: max(1, delay) / 100]
                ] as CFDictionary)
            }
            progress(Double(index + 1) / Double(count))
            await Task.yield()
        }

        guard CGImageDestinationFinalize(destination) else { throw CardVideoExportError.gifUnavailable }
    }

    private func gifFrame(_ image: CGImage, width: Int, height: Int, sampling: Int) throws -> CGImage {
        guard sampling > 1 else { return image }
        func context(width: Int, height: Int) -> CGContext? {
            CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        }
        let smallWidth = width / sampling
        let smallHeight = height / sampling
        guard let small = context(width: smallWidth, height: smallHeight),
              let full = context(width: width, height: height) else { throw CardVideoExportError.frameUnavailable }
        small.interpolationQuality = .medium
        small.draw(image, in: CGRect(x: 0, y: 0, width: smallWidth, height: smallHeight))
        guard let reduced = small.makeImage() else { throw CardVideoExportError.frameUnavailable }
        full.interpolationQuality = .none
        full.draw(reduced, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let frame = full.makeImage() else { throw CardVideoExportError.frameUnavailable }
        return frame
    }
}

@MainActor
private final class AutomaticCardVideoRenderer: CardVideoFrameRenderer {
    private var primary: (any CardVideoFrameRenderer)?
    private let fallback: any CardVideoFrameRenderer

    init(primary: (any CardVideoFrameRenderer)?, fallback: any CardVideoFrameRenderer) {
        self.primary = primary
        self.fallback = fallback
    }

    func frame(at progress: Double, size: CGSize) async throws -> CGImage {
        if let primary {
            do {
                return try await primary.frame(at: progress, size: size)
            } catch {
                try Task.checkCancellation()
                self.primary = nil
            }
        }
        return try await fallback.frame(at: progress, size: size)
    }
}

@MainActor
struct SwiftUICardVideoFallbackRenderer: CardVideoFrameRenderer {
    let summary: WrappedSummary
    var locale: Locale = .current

    func frame(at progress: Double, size: CGSize) async throws -> CGImage {
        try renderWrappedPoster(summary: summary, locale: locale, progress: progress, size: size, includesHeadphones: true)
    }
}

@MainActor
private func renderWrappedPoster(
    summary: WrappedSummary, locale: Locale, progress: Double, size: CGSize, includesHeadphones: Bool
) throws -> CGImage {
    try autoreleasepool {
        let view = WrappedReelPoster(summary: summary, progress: progress, includesHeadphones: includesHeadphones)
            .environment(\.locale, locale)
            .environment(\.colorScheme, .dark)
            .dynamicTypeSize(.medium)
        let renderer = ImageRenderer(content: view)
        renderer.scale = size.width / WrappedReelPoster.size.width
        renderer.isOpaque = true
        guard let frame = renderer.cgImage else { throw CardVideoExportError.frameUnavailable }
        return frame
    }
}

@available(iOS 18.0, *)
@MainActor
final class RealityCardVideoRenderer: CardVideoFrameRenderer {
    private let renderer: RealityRenderer
    private let model: Entity
    private let context: CIContext
    private let textureCache: CVMetalTextureCache
    private let summary: WrappedSummary
    private let locale: Locale
    private var pool: CVPixelBufferPool?
    private var poolDimension = 0

    // The GPU completion handler keeps these references alive while the renderer owns the texture.
    private struct RenderBuffers: @unchecked Sendable {
        let pixelBuffer: CVPixelBuffer
        let texture: CVMetalTexture
    }

    init(summary: WrappedSummary, locale: Locale = .current) throws {
        let renderer = try RealityRenderer()
        guard let device = MTLCreateSystemDefaultDevice() else { throw CardVideoExportError.frameUnavailable }
        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess,
              let textureCache else { throw CardVideoExportError.frameUnavailable }

        self.summary = summary
        self.locale = locale
        self.renderer = renderer
        self.textureCache = textureCache
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        model = WrappedHeadphoneScene.makeHeadphones(overEar: summary.topDeviceKey.kind == .overEar)

        renderer.extendedDynamicRangeOutput = false
        renderer.cameraSettings.colorBackground = .color(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        renderer.cameraSettings.isToneMappingEnabled = false
        let camera = WrappedHeadphoneScene.makeCamera()
        renderer.entities.append(camera)
        renderer.activeCamera = camera
        renderer.entities.append(model)
        renderer.entities.append(contentsOf: WrappedHeadphoneScene.makeLights())
    }

    func frame(at progress: Double, size: CGSize) async throws -> CGImage {
        let dimension = Int(size.width * 0.76)
        if poolDimension != dimension {
            var newPool: CVPixelBufferPool?
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: dimension,
                kCVPixelBufferHeightKey as String: dimension,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            guard CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &newPool) == kCVReturnSuccess else {
                throw CardVideoExportError.frameUnavailable
            }
            pool = newPool
            poolDimension = dimension
        }
        var pixelBuffer: CVPixelBuffer?
        guard let pool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer else { throw CardVideoExportError.frameUnavailable }
        var textureRef: CVMetalTexture?
        let textureAttributes = [kCVMetalTextureUsage as String: MTLTextureUsage.renderTarget.union(.shaderRead).rawValue]
        guard CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, textureAttributes as CFDictionary,
                                                       .bgra8Unorm, dimension, dimension, 0, &textureRef) == kCVReturnSuccess,
              let textureRef, let texture = CVMetalTextureGetTexture(textureRef) else {
            throw CardVideoExportError.frameUnavailable
        }

        model.orientation = WrappedHeadphoneScene.orientation(at: progress)
        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        let signal = AsyncStream<Void>.makeStream()
        let buffers = RenderBuffers(pixelBuffer: pixelBuffer, texture: textureRef)
        defer { signal.continuation.finish() }
        try renderer.updateAndRender(deltaTime: 1.0 / 30, cameraOutput: output, onComplete: { _ in
            // The Core Video texture and IOSurface must stay alive even if the frame times out.
            withExtendedLifetime(buffers) {
                _ = signal.continuation.yield(())
            }
        })
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in signal.stream { return }
                throw CardVideoExportError.frameUnavailable
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw CardVideoExportError.frameUnavailable
            }
            defer { group.cancelAll() }
            try await group.next()
        }

        return try autoreleasepool {
            guard Self.containsTransparentModel(pixelBuffer, dimension: dimension) else {
                throw CardVideoExportError.frameUnavailable
            }
            let background = try renderWrappedPoster(summary: summary, locale: locale, progress: progress, size: size,
                                                     includesHeadphones: false)
            let foreground = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: CGAffineTransform(
                translationX: (size.width - CGFloat(dimension)) / 2,
                y: size.height * (1 - WrappedReelPoster.modelCenter / WrappedReelPoster.size.height) - CGFloat(dimension) / 2
            ))
            let composited = foreground.composited(over: CIImage(cgImage: background))
            guard let frame = context.createCGImage(composited, from: CGRect(origin: .zero, size: size)) else {
                throw CardVideoExportError.frameUnavailable
            }
            return frame
        }
    }

    private static func containsTransparentModel(_ buffer: CVPixelBuffer, dimension: Int) -> Bool {
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return false }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let bytes = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self),
              bytes[3] < 20 else { return false }
        let strideBytes = CVPixelBufferGetBytesPerRow(buffer)
        let step = max(1, dimension / 24)
        for y in stride(from: step, to: dimension, by: step) {
            for x in stride(from: step, to: dimension, by: step) where bytes[y * strideBytes + x * 4 + 3] > 100 {
                return true
            }
        }
        return false
    }

}

@MainActor
enum WrappedHeadphoneScene {
    static func makeCamera() -> PerspectiveCamera {
        let camera = PerspectiveCamera()
        camera.position.z = 0.78
        camera.camera.fieldOfViewInDegrees = 38
        return camera
    }

    static func makeLights() -> [DirectionalLight] {
        let positions: [SIMD3<Float>] = [[1, 1, 2], [-1, 0.5, 1]]
        return positions.map { position in
            let light = DirectionalLight()
            light.light.intensity = 1600
            light.look(at: .zero, from: position, relativeTo: nil)
            return light
        }
    }

    static func orientation(at progress: Double) -> simd_quatf {
        simd_quatf(angle: Float(progress * 2 * .pi), axis: [0, 1, 0])
            * simd_quatf(angle: 0.12, axis: [1, 0, 0])
    }

    static func makeHeadphones(overEar: Bool) -> Entity {
        let root = Entity()
        let enamel = SimpleMaterial(color: UIColor(red: 0.67, green: 0.94, blue: 0.86, alpha: 1),
                                    roughness: 0.39, isMetallic: true)
        let cushion = SimpleMaterial(color: UIColor(red: 0.12, green: 0.25, blue: 0.28, alpha: 1),
                                     roughness: 0.9, isMetallic: false)
        func add(_ mesh: MeshResource, at position: SIMD3<Float>, material: SimpleMaterial) -> ModelEntity {
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = position
            root.addChild(entity)
            return entity
        }
        if overEar {
            // Small overlapping spheres form a rounded, segmented arch with no product-specific geometry.
            for step in 0...24 {
                let angle = Float(step) / 24 * .pi
                _ = add(.generateSphere(radius: 0.013), at: [0.142 * cos(angle), 0.142 * sin(angle) - 0.026, 0], material: enamel)
            }
            for side: Float in [-1, 1] {
                let cup = MeshResource.generateBox(width: 0.065, height: 0.116, depth: 0.080, cornerRadius: 0.026)
                let pad = MeshResource.generateBox(width: 0.030, height: 0.100, depth: 0.072, cornerRadius: 0.014)
                _ = add(cup, at: [side * 0.145, -0.063, 0], material: enamel)
                _ = add(pad, at: [side * 0.110, -0.063, 0], material: cushion)
            }
        } else {
            for side: Float in [-1, 1] {
                let bud = add(.generateSphere(radius: 0.065), at: [side * 0.090, side * 0.041, 0], material: enamel)
                bud.scale = [0.92, 1, 0.58]
                let tip = add(.generateSphere(radius: 0.035), at: [side * 0.067, side * 0.041, 0.04], material: cushion)
                tip.scale = [0.92, 0.92, 0.65]
            }
        }
        return root
    }
}
