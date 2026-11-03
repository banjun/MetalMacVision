import SwiftUI

@main struct App: SwiftUI.App {
    @State private var rendererSceneController = RendererSceneController()
    @State private var immersionStyle: any ImmersionStyle = .full

    var body: some Scene {
        Group {
            WindowGroup {
                ContentView()
            }
#if os(macOS)
            RemoteImmersiveSpace(id: "RemoteScene") {
                RemoteSceneContent()
            }
//            .immersionStyle(selection: $immersionStyle, in: .full) // .mixed is not supported in macOS
#elseif os(visionOS)
            ImmersiveSpace(id: "ImmersiveSpace") {
                RemoteSceneContent()
            }
            //.immersionStyle(selection: $immersionStyle, in: .full, .progressive, .mixed) // need to use drawable render context when supporting progressive style.
#endif
        }
        .environment(rendererSceneController)
    }
}
