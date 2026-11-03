import CompositorServices
import QuartzCore

protocol RendererFrame {
    func startUpdate()
    func endUpdate()
    func startSubmission()
    func endSubmission()

    func waitForOptimalInputTime()
    func queryDrawables() -> [any RendererDrawable]
}

extension LayerRenderer.Frame: RendererFrame {
    func waitForOptimalInputTime() {
        if let timing = predictTiming() {
            LayerRenderer.Clock().wait(until: timing.optimalInputTime)
        }
    }
    func queryDrawables() -> [any RendererDrawable] {
        queryDrawables() as [LayerRenderer.Drawable]
    }
}

extension CAMetalLayer: RendererFrame {
    func startUpdate() {}
    func endUpdate() {}
    func startSubmission() {}
    func endSubmission() {}

    func waitForOptimalInputTime() {
        // TODO
    }
    func queryDrawables() -> [any RendererDrawable] {
        [nextDrawable()].compactMap(\.self).map {AnyRendererDrawable($0)}
    }
}

