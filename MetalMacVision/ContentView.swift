import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(RendererSceneController.self) private var rendererSceneController
    // another renderer than rendererSceneController.renderer, as it dosen't support multi-input yet
    @State private var renderer: Renderer = .init(vertexFunction: .nameOnDefaultLib("vertexShader"), fragmentFunction: .nameOnDefaultLib("fragmentShader"))

    var body: some View {
        HStack(alignment: .top) {
            VStack {
#if os(macOS)
                VStack {
                    Text("CAMetalLayer").padding()
                    MetalLayer(renderer: renderer, arkitContainer: .fakeFixed(fallbackDeviceAnchorProvider: {
                        rendererSceneController.arkitValue?.viewFromOrigin.0.inverse ??
                        rendererSceneController.camera.transform.matrix
                    }))
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

struct Matrix: View {
    var value: simd_float4x4

    private var rows: [[Float]] {
        (0..<4).map { row in
            (0..<4).map { column in
                value[column][row]
            }
        }
    }

    var body: some View {
        let f = Decimal.FormatStyle.number.precision(.fractionLength(3))
        Grid {
            ForEach(0..<4, id: \.self) { row in
                GridRow {
                    ForEach(0..<4, id: \.self) { column in
                        Text(Decimal(Double(rows[row][column])).formatted(f))
                    }
                }
            }
        }
        .monospacedDigit()
        .fixedSize()
    }
}
