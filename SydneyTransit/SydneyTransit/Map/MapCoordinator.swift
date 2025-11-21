import Foundation
import MapKit

/// Navigation coordinator for Map feature
/// Placeholder for Phase 3 navigation integration
@MainActor
class MapCoordinator: ObservableObject {
    /// Navigate to specific stop and show details
    /// - Parameter stop: Stop to center map on
    /// Note: Currently navigation is handled via NavigationLink(MapView(selectedStop:))
    /// This coordinator will be used in Phase 3 for programmatic navigation
    func navigateToStop(_ stop: Stop) {
        // Phase 1.5: Navigation handled via NavigationLink with selectedStop parameter
        // Phase 3: Will implement programmatic navigation pattern
    }
}
