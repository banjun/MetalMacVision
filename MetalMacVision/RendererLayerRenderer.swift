import CompositorServices
import Metal
import QuartzCore

protocol RendererLayerRenderer {
    var isRunning: Bool { get }
    func waitUntilRunning()
    var metalDevice: (any MTLDevice)? { get }
    var viewCount: Int { get }
    var colorFormat: MTLPixelFormat { get }
    var depthFormat: MTLPixelFormat { get }
    func queryNextFrame() -> (any RendererFrame)?
}

extension LayerRenderer: RendererLayerRenderer {
    var isRunning: Bool {state == .running}
    var metalDevice: (any MTLDevice)? {device}
    var viewCount: Int {properties.viewCount}
    var colorFormat: MTLPixelFormat {configuration.colorFormat}
    var depthFormat: MTLPixelFormat {configuration.depthFormat}
    func queryNextFrame() -> (any RendererFrame)? {
        queryNextFrame() as Frame?
    }
}

extension CAMetalLayer: RendererLayerRenderer {
    var isRunning: Bool {true}
    func waitUntilRunning() {}
    var metalDevice: (any MTLDevice)? {device}
    var viewCount: Int {1}
    var colorFormat: MTLPixelFormat {pixelFormat}
    var depthFormat: MTLPixelFormat {.invalid}
    func queryNextFrame() -> (any RendererFrame)? {self}
}
