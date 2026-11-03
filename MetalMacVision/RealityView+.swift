import SwiftUI
import RealityKit

#if os(macOS)
private typealias RealityViewContent = RealityViewCameraContent
#endif

extension RealityView where Content == RealityViewContent.Body<RealityViewDefaultPlaceholder> {
    static func make(for c: RendererSceneController) -> some View {
        RealityView {c.realityViewContent = $0}
            .realityViewLayoutBehavior(.flexible)
#if os(macOS)
            .realityViewCameraControls(.orbit)
#endif
            .onAppear {Task {await c.didAppear()}}
            .onDisappear {Task {await c.didDisappear()}}
    }
}
