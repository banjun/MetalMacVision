import SwiftUI
import CompositorServices

struct RemoteSceneContent: CompositorContent {
    @Environment(RendererSceneController.self) private var rendererSceneController
    @Environment(\.remoteDeviceIdentifier) private var remoteDeviceIdentifier
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    struct Configuration: CompositorLayerConfiguration {
        func makeConfiguration(capabilities: LayerRenderer.Capabilities, configuration: inout LayerRenderer.Configuration) {
            configuration.layout = capabilities.supportedLayouts(options: [.foveationEnabled]).contains(.layered) ? .layered : .dedicated
            configuration.colorFormat = .rgba16Float
            configuration.depthFormat = .depth32Float//_stencil8
            configuration.isFoveationEnabled = capabilities.supportsFoveation
//            configuration.drawableRenderContextStencilFormat = .depth32Float_stencil8// .invalid// .depth32Float_stencil8
//            configuration.drawableRenderContextRasterSampleCount = 1
        }
    }

    var arkitContainer: (RemoteDeviceIdentifier?) -> Renderer.ARKitContainer? = { remoteDeviceIdentifier in
#if os(macOS)
            NSLog("%@", "setup ARKitSession for remoteDeviceIdentifier = \(String(describing: remoteDeviceIdentifier))")
            let arkitSession = remoteDeviceIdentifier.map {ARKitSession(device: $0)}
#else
            let arkitSession = ARKitSession()
#endif
        return Renderer.ARKitContainer(arkitSession: arkitSession)
    }

    var body: some CompositorContent {
        CompositorLayer(configuration: Configuration()) { @MainActor in
            // as remoteDeviceIdentifier is Environment, we must consume it immediately
            if let arkitContainer = arkitContainer(remoteDeviceIdentifier) {
                rendererSceneController.startRenderLoop(layerRenderer: $0, arkitContainer: arkitContainer)
            }
        }
        .onAppear {
            NSLog("%@", "CompositorLayer.onAppear")
            rendererSceneController.isRemoteSceneActive = true
        }
        .onDisappear {
            NSLog("%@", "CompositorLayer.onDisappear")
            rendererSceneController.isRemoteSceneActive = false
            rendererSceneController.stopRenderLoop()
        }
    }
}
