import SwiftUI
import MapKit
import Logging

/// Map view showing transit stops with region-based loading and clustering
struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093), // Sydney CBD
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // ~5km radius
    )

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Map with stop annotations
            MapViewRepresentable(
                region: $region,
                annotations: viewModel.annotations,
                onRegionChanged: { newRegion in
                    viewModel.onRegionChanged(newRegion)
                },
                onStopSelected: { stop in
                    viewModel.selectStop(stop)
                }
            )
            .ignoresSafeArea()

            // Loading indicator
            if viewModel.isLoading {
                ProgressView()
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Initial load on appear
            await viewModel.loadStops(for: region)
        }
        .sheet(isPresented: .constant(viewModel.selectedStop != nil)) {
            if let selectedStop = viewModel.selectedStop {
                StopDetailsDrawer(
                    stop: selectedStop,
                    departures: viewModel.departures,
                    isLoading: viewModel.isLoadingDepartures,
                    errorMessage: viewModel.departuresErrorMessage
                )
                .presentationDetents([.fraction(0.15), .medium, .large])
                .presentationDragIndicator(.visible)
                .safePresentationBackgroundInteraction()
                .safePresentationBackground()
                .safePresentationCornerRadius()
                .interactiveDismissDisabled()
            }
        }
    }
}

/// UIViewRepresentable wrapper for MKMapView with delegate support
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [StopAnnotation]
    let onRegionChanged: (MKCoordinateRegion) -> Void
    let onStopSelected: (Stop) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region

        // Register custom annotation view
        mapView.register(
            StopAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: StopAnnotationView.reuseIdentifier
        )

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update annotations when they change
        let currentAnnotations = Set(mapView.annotations.compactMap { $0 as? StopAnnotation }.map { $0.stop.sid })
        let newAnnotations = Set(annotations.map { $0.stop.sid })

        if currentAnnotations != newAnnotations {
            // Remove old annotations
            let toRemove = mapView.annotations.filter { annotation in
                guard let stopAnnotation = annotation as? StopAnnotation else { return false }
                return !newAnnotations.contains(stopAnnotation.stop.sid)
            }
            mapView.removeAnnotations(toRemove)

            // Add new annotations
            let toAdd = annotations.filter { annotation in
                !currentAnnotations.contains(annotation.stop.sid)
            }
            mapView.addAnnotations(toAdd)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(region: $region, onRegionChanged: onRegionChanged, onStopSelected: onStopSelected)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var region: MKCoordinateRegion
        let onRegionChanged: (MKCoordinateRegion) -> Void
        let onStopSelected: (Stop) -> Void

        init(
            region: Binding<MKCoordinateRegion>,
            onRegionChanged: @escaping (MKCoordinateRegion) -> Void,
            onStopSelected: @escaping (Stop) -> Void
        ) {
            self._region = region
            self.onRegionChanged = onRegionChanged
            self.onStopSelected = onStopSelected
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update binding and trigger debounced load
            region = mapView.region
            onRegionChanged(mapView.region)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Handle cluster annotations
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                    annotation: cluster,
                    reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
                )

                view.markerTintColor = .systemBlue
                view.glyphText = "\(cluster.memberAnnotations.count)"
                view.displayPriority = .required

                // Accessibility for clusters
                view.accessibilityLabel = "\(cluster.memberAnnotations.count) stops"

                return view
            }

            // Handle stop annotations
            if let stopAnnotation = annotation as? StopAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: StopAnnotationView.reuseIdentifier,
                    for: stopAnnotation
                ) as? StopAnnotationView ?? StopAnnotationView(
                    annotation: stopAnnotation,
                    reuseIdentifier: StopAnnotationView.reuseIdentifier
                )

                // Configure view (already done in StopAnnotationView init)
                return view
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Handle stop selection - open drawer with departures
            if let stopAnnotation = view.annotation as? StopAnnotation {
                Logger.map.info(
                    "stop_annotation_selected",
                    metadata: .from([
                        "stop_id": stopAnnotation.stop.sid,
                        "stop_name": stopAnnotation.stop.stopName
                    ])
                )

                // Trigger drawer presentation with selected stop
                onStopSelected(stopAnnotation.stop)

                // Deselect annotation immediately to allow re-tapping
                mapView.deselectAnnotation(view.annotation, animated: false)
            }
        }
    }
}

// MARK: - Extensions for iOS 16.4+ Compatibility

extension View {
    @ViewBuilder
    func safePresentationBackgroundInteraction() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackgroundInteraction(.enabled(upThrough: .medium))
        } else {
            self
        }
    }

    @ViewBuilder
    func safePresentationBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.ultraThinMaterial)
        } else {
            self
        }
    }

    @ViewBuilder
    func safePresentationCornerRadius() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(16)
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        MapView()
    }
}
