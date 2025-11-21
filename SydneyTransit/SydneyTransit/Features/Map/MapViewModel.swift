import Foundation
import MapKit
import Logging

@MainActor
class MapViewModel: NSObject, ObservableObject {
    @Published var annotations: [StopAnnotation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Drawer state
    @Published var selectedStop: Stop?
    @Published var departures: [Departure] = []
    @Published var isLoadingDepartures = false
    @Published var departuresErrorMessage: String?

    private var loadedDepartureIds = Set<String>()  // Deduplication by full ID (tripId_scheduledTime)
    private var regionChangeTask: Task<Void, Never>?
    private let dbManager = DatabaseManager.shared

    // Track last loaded region to avoid redundant queries
    private var lastLoadedRegion: MKCoordinateRegion?

    /// Load stops for visible map region with debouncing
    /// Called from MapView when region changes
    func onRegionChanged(_ region: MKCoordinateRegion) {
        // Cancel previous pending task to debounce
        regionChangeTask?.cancel()

        // Debounce: wait 300ms after last region change
        regionChangeTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms

                guard !Task.isCancelled else { return }

                await loadStops(for: region)
            } catch {
                // Task cancelled or sleep interrupted - ignore
            }
        }
    }

    /// Load stops within visible region from GRDB
    func loadStops(for region: MKCoordinateRegion) async {
        // Skip if region hasn't changed significantly (>50% overlap)
        if let lastRegion = lastLoadedRegion, regionsOverlap(lastRegion, region, threshold: 0.5) {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let bbox = region.boundingBox

            let stops = try dbManager.getStopsInRegion(
                minLat: bbox.minLat,
                maxLat: bbox.maxLat,
                minLon: bbox.minLon,
                maxLon: bbox.maxLon,
                limit: 200
            )

            // Create annotations with cached route types
            let newAnnotations = stops.map { StopAnnotation(stop: $0) }

            self.annotations = newAnnotations
            self.lastLoadedRegion = region

            Logger.map.info(
                "map_stops_updated",
                metadata: .from([
                    "count": stops.count,
                    "center_lat": region.center.latitude,
                    "center_lon": region.center.longitude
                ])
            )
        } catch {
            errorMessage = "Failed to load stops"
            Logger.map.error(
                "map_stops_load_failed",
                metadata: .from([
                    "error": error.localizedDescription
                ])
            )
        }

        isLoading = false
    }

    /// Check if two regions overlap significantly
    private func regionsOverlap(_ r1: MKCoordinateRegion, _ r2: MKCoordinateRegion, threshold: Double) -> Bool {
        let box1 = r1.boundingBox
        let box2 = r2.boundingBox

        // Calculate overlap area vs union area
        let overlapLat = min(box1.maxLat, box2.maxLat) - max(box1.minLat, box2.minLat)
        let overlapLon = min(box1.maxLon, box2.maxLon) - max(box1.minLon, box2.minLon)

        guard overlapLat > 0, overlapLon > 0 else { return false }

        let overlapArea = overlapLat * overlapLon
        let r1Area = (box1.maxLat - box1.minLat) * (box1.maxLon - box1.minLon)

        return (overlapArea / r1Area) >= threshold
    }

    // MARK: - Drawer Management

    /// Select stop and load departures for drawer
    func selectStop(_ stop: Stop) {
        selectedStop = stop
        Task {
            await loadDepartures(for: stop)
        }
    }

    /// Load static departures for selected stop
    private func loadDepartures(for stop: Stop) async {
        isLoadingDepartures = true
        departuresErrorMessage = nil

        do {
            // Get GTFS stop_id from dict_stop table
            guard let stopId = try stop.getStopID() else {
                departuresErrorMessage = "Unable to fetch departures: stop ID mapping missing"
                Logger.map.error(
                    "drawer_departures_missing_stop_id",
                    metadata: .from([
                        "sid": stop.sid,
                        "stop_name": stop.stopName
                    ])
                )
                isLoadingDepartures = false
                return
            }

            // Fetch static departures from GRDB
            let fetchedDepartures = try dbManager.getDepartures(stopId: stopId, limit: 20)

            // Deduplicate (pattern model may return duplicate trips for same pattern)
            let newDepartures = fetchedDepartures.filter { !loadedDepartureIds.contains($0.id) }
            departures = newDepartures
            loadedDepartureIds.formUnion(newDepartures.map { $0.id })

            Logger.map.info(
                "drawer_departures_loaded",
                metadata: .from([
                    "stop_id": stopId,
                    "stop_name": stop.stopName,
                    "count": fetchedDepartures.count
                ])
            )
        } catch {
            departuresErrorMessage = "Failed to load departures"
            Logger.map.error(
                "drawer_departures_load_failed",
                metadata: .from([
                    "sid": stop.sid,
                    "error": error.localizedDescription
                ])
            )
        }

        isLoadingDepartures = false
    }

    /// Deselect stop (close drawer)
    func deselectStop() {
        selectedStop = nil
        departures = []
        departuresErrorMessage = nil
        loadedDepartureIds.removeAll()
    }

    /// Center map on specific stop and open drawer
    /// Called when navigating from SearchView or DeparturesView
    func centerOnStop(_ stop: Stop, region: Binding<MKCoordinateRegion>) {
        // Update map region to center on stop with tight zoom
        region.wrappedValue = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: stop.stopLat, longitude: stop.stopLon),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // ~1km radius
        )

        // Select stop to trigger drawer
        selectStop(stop)

        Logger.map.info(
            "map_centered_on_stop",
            metadata: .from([
                "stop_id": stop.sid,
                "stop_name": stop.stopName,
                "lat": stop.stopLat,
                "lon": stop.stopLon
            ])
        )
    }
}

// MARK: - MKCoordinateRegion Extension

extension MKCoordinateRegion {
    /// Calculate bounding box from region center and span
    var boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2
        return (minLat, maxLat, minLon, maxLon)
    }
}

// MARK: - Logger Extension

extension Logger {
    static let map = Logger(label: "map")
}
