import MapKit
import SwiftUI

/// Custom annotation view for stop pins with transport mode icons and clustering
final class StopAnnotationView: MKMarkerAnnotationView {
    static let reuseIdentifier = "StopAnnotationView"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        // Enable clustering for dense areas (CBD)
        clusteringIdentifier = "stop"

        // High priority to show most important stops when space limited
        displayPriority = .defaultHigh

        // Enable callout on tap
        canShowCallout = true

        // Configure appearance from annotation
        configure(for: annotation)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    /// Configure view appearance based on StopAnnotation data
    private func configure(for annotation: MKAnnotation?) {
        guard let stopAnnotation = annotation as? StopAnnotation else { return }

        // Set marker color based on route type
        markerTintColor = stopAnnotation.markerTintColor

        // Set icon glyph (SF Symbol)
        glyphImage = UIImage(systemName: stopAnnotation.transportIcon)

        // Accessibility: descriptive label for VoiceOver
        accessibilityLabel = "\(stopAnnotation.stop.stopName), \(stopAnnotation.subtitle ?? "Stop")"
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // Reset to defaults
        markerTintColor = .systemBlue
        glyphImage = nil
        accessibilityLabel = nil
    }
}
