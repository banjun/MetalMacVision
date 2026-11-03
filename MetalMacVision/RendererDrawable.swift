import CompositorServices
import Metal
import QuartzCore

protocol RendererDrawable {
    var colorTexture: (any MTLTexture)? { get }
    var depthTexture: (any MTLTexture)? { get }
    var rasterizationRateMap: (any MTLRasterizationRateMap)? { get }
    func setDeviceAnchor(_ a: DeviceAnchor?)
    var framePresentationTimestamp: TimeInterval { get }
    func viewFromOrigin(originFromDeviceAnchor: simd_float4x4) -> (simd_float4x4, simd_float4x4)
    var clipFromView: (simd_float4x4, simd_float4x4)? { get }
    func encodePresent(commandBuffer command_buffer: any MTLCommandBuffer)
}
extension RendererDrawable {
    var viewCount: Int {colorTexture?.arrayLength ?? 0}
}

extension LayerRenderer.Drawable: RendererDrawable {
    var colorTexture: (any MTLTexture)? {colorTextures.first}
    var depthTexture: (any MTLTexture)? {depthTextures.first}
    var rasterizationRateMap: (any MTLRasterizationRateMap)? {rasterizationRateMaps.first}
    func setDeviceAnchor(_ a: DeviceAnchor?) {deviceAnchor = a}
    var framePresentationTimestamp: TimeInterval {frameTiming.presentationTimestamp}
    func viewFromOrigin(originFromDeviceAnchor: simd_float4x4) -> (simd_float4x4, simd_float4x4) {
        (views.first.map {($0.transform.inverse * originFromDeviceAnchor.inverse)} ?? matrix_identity_float4x4,
         views.last.map {($0.transform.inverse * originFromDeviceAnchor.inverse)} ?? matrix_identity_float4x4)
    }
    var clipFromView: (simd_float4x4, simd_float4x4)? {
        (computeProjection(convention: .rightUpBack, viewIndex: min(viewCount - 1, 0)),
         computeProjection(convention: .rightUpBack, viewIndex: min(viewCount - 1, 1)))
    }
}

class AnyRendererDrawable: RendererDrawable {
    let base: any MTLDrawable
    init<Base: MTLDrawable>(_ base: Base) {
        self.base = base
    }

    var colorTexture: (any MTLTexture)? {(base as? CAMetalDrawable)?.texture}
    var depthTexture: (any MTLTexture)? {nil}
    var rasterizationRateMap: (any MTLRasterizationRateMap)? {nil}
    func setDeviceAnchor(_ a: DeviceAnchor?) {}
    var framePresentationTimestamp: TimeInterval {CACurrentMediaTime()}
    func viewFromOrigin(originFromDeviceAnchor: simd_float4x4) -> (simd_float4x4, simd_float4x4) {
        (originFromDeviceAnchor.inverse, originFromDeviceAnchor.inverse) // monoscopic
    }
    var clipFromView: (simd_float4x4, simd_float4x4)? = nil

    func encodePresent(commandBuffer: any MTLCommandBuffer) {
        commandBuffer.present(base)
    }
}
