import SwiftUI
import MapKit

struct TripMapView: UIViewRepresentable {
    let stops: [TripStop]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove old annotations/overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        // Create annotations for each stop with valid coordinates
        let annotations = stops.compactMap { stop -> MKPointAnnotation? in
            guard let lat = stop.lat, let lon = stop.lon else { return nil }
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            annotation.title = stop.stopName
            annotation.subtitle = "Arrives at \(stop.arrivalTime)"
            return annotation
        }

        // Add annotations to map
        mapView.addAnnotations(annotations)

        // Create polyline from stop coordinates
        let coordinates = stops.compactMap { stop -> CLLocationCoordinate2D? in
            guard let lat = stop.lat, let lon = stop.lon else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        // Add polyline overlay if we have at least 2 points
        if coordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }

        // Auto-zoom to fit all annotations
        if !annotations.isEmpty {
            mapView.showAnnotations(annotations, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 3.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
