import CompositorServices
import ARKit
import SwiftUI
import Combine

final class Renderer {
    var layerRenderer: any RendererLayerRenderer?
    private var renderThread: Thread? {didSet {oldValue?.cancel()}}
    private var commandQueue: (any MTLCommandQueue)?
    var renderPipelineState: (any MTLRenderPipelineState)?
    var depthState: (any MTLDepthStencilState)?

    private let arkitValueSubject: CurrentValueSubject<ARKitValue?, Never> = .init(nil)
    var arkitValues: some Publisher<ARKitValue, Never> {arkitValueSubject.compactMap(\.self)}
    struct ARKitValue {
        var viewFromOrigin: (float4x4, float4x4)
        var clipFromView: (float4x4, float4x4)
    }

    var arkitContainer: ARKitContainer?
    /// abstracted layer for emitting ViewMatrices, typically using ARKitSession & WorldTrackingProvider
    final class ARKitContainer {
        private var arkitSession: ARKitSession? {didSet {oldValue?.stop()}}
        private var worldTrackingProvider: WorldTrackingProvider?
        var fallbackDeviceAnchorProvider: (() -> float4x4?)?

        static func fakeFixed(fallbackDeviceAnchorProvider: @escaping () -> float4x4?) -> ARKitContainer {
            let c = self.init(arkitSession: nil)
            c.fallbackDeviceAnchorProvider = fallbackDeviceAnchorProvider
            return c
        }

        init(arkitSession: ARKitSession?) {
            self.arkitSession = arkitSession
        }
        deinit {arkitSession?.stop()}

        func run(_ dataProviders: [any DataProvider]) {
            Task.immediate {await run(dataProviders)}
        }
        func run(_ dataProviders: [any DataProvider]) async {
            guard let arkitSession else { return }
            do {
                try await arkitSession.run(dataProviders)
                worldTrackingProvider = dataProviders.compactMap {$0 as? WorldTrackingProvider}.first
            } catch {
                NSLog("%@", "\(#function) error = \(String(describing: error))")
            }
        }

        func queryDeviceAnchor(atTimestamp t: TimeInterval) -> (originFromAnchorTransform: float4x4, deviceAnchor: DeviceAnchor?)? {
            if let deviceAnchor = worldTrackingProvider?.queryDeviceAnchor(atTimestamp: t) {
                return (deviceAnchor.originFromAnchorTransform, deviceAnchor)
            }
            return fallbackDeviceAnchorProvider?().map {($0, nil)} ?? nil
        }
    }

    enum FunctionDescriptor {
        case nameOnDefaultLib(String)
        case actual(any MTLFunction)
    }
    let vertexFunction: FunctionDescriptor
    let fragmentFunction: FunctionDescriptor
    var clearColor: MTLClearColor
    var clearDepth: Double //  RemoteImmersiveSpace requires non-zero to draw (but opacity will be lost). Apple uses 1e-4 for CS_HoverEffect sample code, and it helps all pixels are filled when clearColor.a = 0

    init(vertexFunction: FunctionDescriptor, fragmentFunction: FunctionDescriptor, clearColor: MTLClearColor = .init(red: 0, green: 0, blue: 0, alpha: 0), clearDepth: Double = 0) {
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.clearColor = clearColor
        self.clearDepth = clearDepth
    }

    @MainActor func startRenderLoop(arkitContainer: ARKitContainer) {
        self.arkitContainer = arkitContainer
        Task.immediate {
            await arkitContainer.run([WorldTrackingProvider()])

            renderThread = Thread {
                NSLog("%@", "renderThread started: \(self.renderThread?.debugDescription ?? "-")")
                defer {NSLog("%@", "renderThread finished: \(self.renderThread?.debugDescription ?? "-")")}
                while !Thread.current.isCancelled {
                    autoreleasepool {
                        self.renderNextFrame()
                    }
                }
            }
            renderThread?.qualityOfService = .userInitiated
            renderThread?.start()
        }
    }

    @MainActor func stopRenderLoop() {
        renderThread = nil
    }

    private func makeRenderPipelineState(device: any MTLDevice, vertexFunction: any MTLFunction, fragmentFunction: any MTLFunction, viewCount: Int, colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat) throws -> any MTLRenderPipelineState {
        let d = MTLRenderPipelineDescriptor()
        d.inputPrimitiveTopology = .triangle
        d.vertexDescriptor = nil
        d.maxVertexAmplificationCount = viewCount
        d.vertexFunction = vertexFunction
        d.fragmentFunction = fragmentFunction
        d.colorAttachments[0].pixelFormat = colorFormat
        d.depthAttachmentPixelFormat = depthFormat
//        d.stencilAttachmentPixelFormat = depthFormat
        d.rasterSampleCount = 1
        return try device.makeRenderPipelineState(descriptor: d)
    }

    private func makeDepthState(device: any MTLDevice) -> (any MTLDepthStencilState)? {
        let d = MTLDepthStencilDescriptor()
        d.depthCompareFunction = MTLCompareFunction.greater
        d.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: d)
    }

    private func renderNextFrame() {
        layerRenderer?.waitUntilRunning()
        guard let layerRenderer, layerRenderer.isRunning else {
            Thread.current.cancel()
            return
        }

        guard let device = layerRenderer.metalDevice else { return }
        let viewCount = layerRenderer.viewCount
        guard let commandQueue else {
            commandQueue = device.makeCommandQueue()
            return
        }
        guard let renderPipelineState, let depthState else {
            let vertexFunction = switch vertexFunction {
            case .actual(let f): f
            case .nameOnDefaultLib(let name): device.makeDefaultLibrary()!.makeFunction(name: name)!
            }
            let fragmentFunction = switch fragmentFunction {
            case .actual(let f): f
            case .nameOnDefaultLib(let name): device.makeDefaultLibrary()!.makeFunction(name: name)!
            }
            renderPipelineState = try! makeRenderPipelineState(device: device, vertexFunction: vertexFunction, fragmentFunction: fragmentFunction, viewCount: viewCount, colorFormat: layerRenderer.colorFormat, depthFormat: layerRenderer.depthFormat)
            depthState = makeDepthState(device: device)!

            NSLog("%@", "setup pipeline states for device = \(device.debugDescription ?? "-")")
            NSLog("%@", "renderPipelineState = \(renderPipelineState?.debugDescription ?? "-")")
            NSLog("%@", "depthState = \(depthState?.debugDescription ?? "-")")
            return
        }

        guard let frame: any RendererFrame = layerRenderer.queryNextFrame() else { return }

        frame.startUpdate()
        frame.endUpdate()
        frame.waitForOptimalInputTime()
        frame.startSubmission()

        for drawable in frame.queryDrawables() {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            defer {commandBuffer.commit()}

            let deviceAnchorResponse = arkitContainer?.queryDeviceAnchor(atTimestamp: drawable.framePresentationTimestamp)
            drawable.setDeviceAnchor(deviceAnchorResponse?.deviceAnchor)

            if let deviceAnchorResponse, let colorTexture = drawable.colorTexture {
                let viewFromOrigin = drawable.viewFromOrigin(originFromDeviceAnchor: deviceAnchorResponse.originFromAnchorTransform)
                let clipFromView = drawable.clipFromView ?? (
                    simd_float4x4(
                        SIMD4<Float>(1, 0, 0, 0),
                        SIMD4<Float>(0, 1.78, 0, 0),
                        SIMD4<Float>(0, 0, 0, -1),
                        SIMD4<Float>(0, 0, 0.097, 0),
                    ),
                    simd_float4x4(
                        SIMD4<Float>(1, 0, 0, 0),
                        SIMD4<Float>(0, 1.78, 0, 0),
                        SIMD4<Float>(0, 0, 0, -1),
                        SIMD4<Float>(0, 0, 0.097, 0),
                    ),
                )
                arkitValueSubject.send(.init(viewFromOrigin: viewFromOrigin, clipFromView: clipFromView))
                let viewCount = drawable.viewCount
                if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: {
                    let d = MTLRenderPassDescriptor()
                    d.renderTargetArrayLength = viewCount
                    d.colorAttachments[0].texture = colorTexture
                    d.colorAttachments[0].loadAction = .clear
                    d.colorAttachments[0].storeAction = .store
                    d.colorAttachments[0].clearColor = clearColor
                    if let depthTexture = drawable.depthTexture {
                        d.depthAttachment.texture = depthTexture
                        d.depthAttachment.loadAction = .clear
                        d.depthAttachment.storeAction = .store // required for device
                        d.depthAttachment.clearDepth = clearDepth
//                    d.stencilAttachment.texture = depthTexture
//                    d.stencilAttachment.loadAction = .clear
//                    d.stencilAttachment.storeAction = .store
//                    d.stencilAttachment.clearStencil = 0
                    }
                    d.rasterizationRateMap = drawable.rasterizationRateMap
                    return d
                }()) {
                    // for progressive portal stencil, not working
//                    let renderContext = drawable.addRenderContext(commandBuffer: commandBuffer)
//                    renderContext.drawMaskOnStencilAttachment(commandEncoder: encoder, value: 200)
//                    encoder.setStencilReferenceValue(200)
//                    defer {renderContext.endEncoding(commandEncoder: encoder)}
                    defer {encoder.endEncoding()}
                    encoder.setRenderPipelineState(renderPipelineState)
                    if drawable.depthTexture != nil {
                        encoder.setDepthStencilState(depthState)
                    }
                    if viewCount > 1 {
                        encoder.setVertexAmplificationCount(viewCount, viewMappings: nil)
                    }

                    renderFrame(
                        commandBuffer: commandBuffer,
                        encoder: encoder,
                        originFromModel: matrix_identity_float4x4,
                        viewFromOrigin: viewFromOrigin,
                        clipFromView: clipFromView,
                        )
                }
            }
            drawable.encodePresent(commandBuffer: commandBuffer)
        }

        guard layerRenderer.isRunning else { return }
        frame.endSubmission()
    }

    private func renderFrame(commandBuffer: any MTLCommandBuffer, encoder: any MTLRenderCommandEncoder, originFromModel: float4x4, viewFromOrigin: (float4x4, float4x4), clipFromView: (float4x4, float4x4)) {
        var uniforms = VertexUniforms(
            originFromModel: originFromModel,
            viewFromOrigin: viewFromOrigin,
            clipFromView: clipFromView)

        encoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
