import RealityKit
import SwiftUI
import Observation
import CompositorServices
import Combine

/// manages rendering result for both RealityView at local & CompositorLayer at RemoteImmesriveSpace
@MainActor @Observable final class RendererSceneController {
    let root = Entity(naming: String(describing: type(of: RendererSceneController.self)))
    let camera = PerspectiveCamera(naming: "Camera")
    var realityViewContent: (any RealityViewContentProtocol)? {
        didSet {
            realityViewContent?.add(root)
#if os(macOS)
            camera.position.z = 2
            realityViewContent?.add(camera)
#endif
        }
    }
    let renderer: Renderer = .init(vertexFunction: .nameOnDefaultLib("vertexShader"), fragmentFunction: .nameOnDefaultLib("fragmentShader"), clearDepth: 1e-4)
    var isRemoteSceneActive: Bool = false

    var arkitValue: Renderer.ARKitValue?
    @ObservationIgnored var cancellables: Set<AnyCancellable> = []

    init() {
        renderer.arkitValues.throttle(for: .seconds(0.03), scheduler: DispatchQueue.main, latest: true).sink { [weak self] arkitValue in
            self?.arkitValue = arkitValue
        }.store(in: &cancellables)
    }

    func didAppear() async {
        let cube = ModelEntity(mesh: .generateBox(size: 1))
        root.addChild(cube)
    }

    func didDisappear() async {
        root.children.removeAll()
    }

    func startRenderLoop(layerRenderer: LayerRenderer, arkitContainer: Renderer.ARKitContainer) {
        renderer.layerRenderer = layerRenderer
        renderer.startRenderLoop(arkitContainer: arkitContainer)
    }

    func stopRenderLoop() {
        renderer.layerRenderer = nil
        renderer.stopRenderLoop()
    }
}
