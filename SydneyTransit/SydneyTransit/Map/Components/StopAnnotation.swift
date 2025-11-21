import Foundation
import MapKit

/// MKAnnotation wrapper for Stop model with cached primaryRouteType
/// Prevents repeated DB queries during pin rendering
final class StopAnnotation: NSObject, MKAnnotation {
    let stop: Stop
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    /// Cached route type to avoid DB hits on each annotation view render
    let cachedRouteType: Int?

    init(stop: Stop) {
        self.stop = stop
        self.coordinate = CLLocationCoordinate2D(
            latitude: stop.stopLat,
            longitude: stop.stopLon
        )
        self.title = stop.stopName

        // Cache primaryRouteType (computed property queries DB)
        self.cachedRouteType = stop.primaryRouteType

        // Subtitle shows route type display name for VoiceOver
        if let routeType = self.cachedRouteType {
            switch routeType {
            case 0, 900: self.subtitle = "Light Rail"
            case 1: self.subtitle = "Metro"
            case 2: self.subtitle = "Train"
            case 3: self.subtitle = "Bus"
            case 4: self.subtitle = "Ferry"
            case 5: self.subtitle = "Cable Tram"
            case 401: self.subtitle = "Metro"
            case 700, 712, 714: self.subtitle = "Bus"
            default: self.subtitle = "Stop"
            }
        } else {
            self.subtitle = "Stop"
        }

        super.init()
    }

    /// Transport icon based on cached route type
    var transportIcon: String {
        switch cachedRouteType {
        case 0, 900: return "tram.fill"           // Light Rail
        case 1: return "lightrail.fill"           // Metro
        case 2: return "train.side.front.car"     // Train
        case 3: return "bus.fill"                 // Bus
        case 4: return "ferry.fill"               // Ferry
        case 5: return "cablecar.fill"            // Cable Tram
        case 401: return "lightrail.fill"         // NSW Metro
        case 700, 712, 714: return "bus.fill"     // NSW Bus
        default: return "mappin.circle.fill"      // Unknown
        }
    }

    /// Marker tint color based on route type
    var markerTintColor: UIColor {
        switch cachedRouteType {
        case 2: return .systemYellow           // Train - yellow
        case 401, 1: return .systemRed         // Metro - red
        case 0, 900: return .systemGreen       // Light Rail - green
        case 4: return .systemTeal             // Ferry - teal
        case 3, 700, 712, 714: return .systemBlue  // Bus - blue
        default: return .systemGray            // Unknown - gray
        }
    }
}
