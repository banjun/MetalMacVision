import Foundation

extension Duration {
    var timestamp: TimeInterval {
        TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }
}

import CompositorServices

extension LayerRenderer.Frame.Timing {
    var presentationTimestamp: TimeInterval {presentationTime.timestamp}
}
extension LayerRenderer.Clock.Instant {
    var timestamp: TimeInterval {LayerRenderer.Clock.Instant.epoch.duration(to: self).timestamp}
}
