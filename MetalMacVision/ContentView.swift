import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(RendererSceneController.self) private var rendererSceneController
    // another renderer than rendererSceneController.renderer, as it dosen't support multi-input yet
    @State private var renderer1: Renderer = .init(vertexFunction: .nameOnDefaultLib("vertexShader"), fragmentFunction: .nameOnDefaultLib("fragmentShader"))
    @State private var renderer2: Renderer = .init(vertexFunction: .nameOnDefaultLib("vertexShader"), fragmentFunction: .nameOnDefaultLib("fragmentShader"))

    var body: some View {
        HStack(alignment: .top) {
            VStack {
#if os(macOS)
                VStack {
                    Text("CAMetalLayer").padding()
                    HStack {
                        MetalLayer(renderer: renderer1, arkitContainer: .fake(
                            fallbackDeviceAnchorProvider: {
                                rendererSceneController.arkitValue?.viewFromOrigin.0.inverse ??
                                rendererSceneController.camera.transform.matrix
                            },
                            fallbackProjectionProvider: {
                                rendererSceneController.arkitValue.map {($0.clipFromView.0, $0.clipFromView.0)}
                            },
                        ))
                        MetalLayer(renderer: renderer2, arkitContainer: .fake(
                            fallbackDeviceAnchorProvider: {
                                rendererSceneController.arkitValue?.viewFromOrigin.1.inverse ??
                                rendererSceneController.camera.transform.matrix
                            },
                            fallbackProjectionProvider: {
                                rendererSceneController.arkitValue.map {($0.clipFromView.1, $0.clipFromView.1)}
                            },
                        ))
                    }
                }
                Divider()
#endif
                VStack {
                    Text("RealityView").padding()
                    RealityView.make(for: rendererSceneController)
                        .toolbar {
                            ToolbarItem {
                                if rendererSceneController.isRemoteSceneActive {
                                    Button("Close Remote Scene") {
                                        Task {await dismissImmersiveSpace()}
                                    }
                                } else {
                                    Button("Open Remote Scene") {
                                        Task {await openImmersiveSpace(id: "RemoteScene")}
                                    }
                                }
                            }
                        }
#if os(visionOS)
                        .ornament(attachmentAnchor: .scene(.top)) {
                            Button("Open Immersive Space") {
                                Task {await openImmersiveSpace(id: "ImmersiveSpace")}
                            }
                        }
#endif
                }
            }
            Divider()
            VStack {
                Text("ARKit Values").padding()
                if let v = rendererSceneController.arkitValue {
                    VStack {
                        Text("viewFromOrigin").font(.caption)
                        HStack {
                            Matrix(value: v.viewFromOrigin.0)
                            Matrix(value: v.viewFromOrigin.1)
                        }
                        Divider()
                        Text("clipFromView").font(.caption)
                        HStack {
                            Matrix(value: v.clipFromView.0)
                            Matrix(value: v.clipFromView.1)
                        }
                    }
                } else {
                    Text("Unavailable")
                }
            }
            .fixedSize()
        }
    }
}
