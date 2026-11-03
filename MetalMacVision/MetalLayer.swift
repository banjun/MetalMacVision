#if os(macOS)
import SwiftUI
import Metal

struct MetalLayer: NSViewRepresentable {
    var renderer: Renderer?
    var arkitContainer: Renderer.ARKitContainer?

    func makeNSView(context: Context) -> MetalLayerView {
        MetalLayerView()
    }
    func updateNSView(_ v: MetalLayerView, context: Context) {
        renderer?.layerRenderer = v.metalLayer
        v.updateDrawable()
        if let arkitContainer {
            renderer?.startRenderLoop(arkitContainer: arkitContainer)
        }
    }
}

final class MetalLayerView: NSView {
    var metalLayer: CAMetalLayer {layer as! CAMetalLayer}

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer = CAMetalLayer()
    }
    required init?(coder: NSCoder) {fatalError()}

    override func layout() {
        super.layout()
        updateDrawable()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawable()
    }

    func updateDrawable() {
        metalLayer.drawableSize = convertToBacking(bounds).size
        metalLayer.device = MTLCreateSystemDefaultDevice()!
        metalLayer.wantsExtendedDynamicRangeContent = true
        metalLayer.edrMetadata = nil
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        metalLayer.framebufferOnly = false
        metalLayer.pixelFormat = .rgba16Float
        NSLog("%@", "metalLayer.drawableSize = \(metalLayer.drawableSize)")
    }
}

#endif
