import Foundation

@MainActor
class DeparturesViewModel: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var isLoadingPast = false
    @Published var isLoadingFuture = false
    @Published var errorMessage: String?

    private var earliestTimeSecs: Int?
    private var latestTimeSecs: Int?
    private var hasMorePast = true
    private var hasMoreFuture = true
    private var loadedDepartureIds = Set<String>()  // Deduplication by full ID (tripId_scheduledTime)

    private let repository: DeparturesRepository
    private var refreshTimer: Timer?
    private var currentStopId: String?

    init(repository: DeparturesRepository = DeparturesRepositoryImpl()) {
        self.repository = repository
    }

    func loadInitialDepartures(stopId: String) async {
        isLoading = true
        errorMessage = nil
        currentStopId = stopId

        // Reset state
        departures = []
        loadedDepartureIds.removeAll()
        earliestTimeSecs = nil
        latestTimeSecs = nil
        hasMorePast = true
        hasMoreFuture = true

        do {
            let page = try await repository.fetchDeparturesPage(
                stopId: stopId,
                timeSecs: nil,  // Default to now()
                direction: "future",
                limit: 15
            )

            departures = page.departures
            loadedDepartureIds = Set(page.departures.map { $0.id })
            earliestTimeSecs = page.earliestTimeSecs
            latestTimeSecs = page.latestTimeSecs
            hasMorePast = page.hasMorePast
            hasMoreFuture = page.hasMoreFuture

        } catch let error as URLError where error.code == .notConnectedToInternet {
            errorMessage = "No internet connection"
        } catch let error as URLError where error.code == .timedOut {
            errorMessage = "Request timed out. Please try again."
        } catch let error as DecodingError {
            errorMessage = "Invalid response from server"
        } catch {
            let errorDesc = error.localizedDescription
            if errorDesc.contains("404") {
                errorMessage = "Stop not found in backend"
            } else if errorDesc.contains("500") {
                errorMessage = "Server error. Please try again later."
            } else {
                errorMessage = "Failed to load departures: \(errorDesc)"
            }
        }

        isLoading = false
    }

    func loadPastDepartures() async {
        // Check if we should load (not already loading, have more data, have required state)
        guard !isLoadingPast, hasMorePast, let stopId = currentStopId, let earliestTime = earliestTimeSecs else {
            return
        }

        // Set flag IMMEDIATELY before async work to prevent race condition
        // (sentinel .onAppear can re-trigger during scroll bounce)
        isLoadingPast = true

        do {
            let page = try await repository.fetchDeparturesPage(
                stopId: stopId,
                timeSecs: earliestTime - 1,  // Load earlier than earliest
                direction: "past",
                limit: 10
            )

            // Deduplicate and prepend
            // Backend returns past in DESC order [latest→earliest], reverse to get ASC for chronological display
            let newDepartures = page.departures.filter { !loadedDepartureIds.contains($0.id) }
            departures.insert(contentsOf: newDepartures.reversed(), at: 0)

            // Update state
            loadedDepartureIds.formUnion(newDepartures.map { $0.id })
            if let newEarliest = page.earliestTimeSecs {
                earliestTimeSecs = newEarliest
            }
            hasMorePast = page.hasMorePast

        } catch {
            // Silent fail for pagination errors (don't disrupt UX)
            print("[DeparturesVM] loadPastDepartures failed: \(error)")
        }

        isLoadingPast = false
    }

    func loadFutureDepartures() async {
        guard !isLoadingFuture, hasMoreFuture, let stopId = currentStopId, let latestTime = latestTimeSecs else {
            return
        }

        isLoadingFuture = true

        do {
            let page = try await repository.fetchDeparturesPage(
                stopId: stopId,
                timeSecs: latestTime + 1,  // Load later than latest
                direction: "future",
                limit: 10
            )

            // Deduplicate and append
            let newDepartures = page.departures.filter { !loadedDepartureIds.contains($0.id) }
            departures.append(contentsOf: newDepartures)

            // Update state
            loadedDepartureIds.formUnion(newDepartures.map { $0.id })
            if let newLatest = page.latestTimeSecs {
                latestTimeSecs = newLatest
            }
            hasMoreFuture = page.hasMoreFuture

        } catch {
            // Silent fail for pagination errors
            print("[DeparturesVM] loadFutureDepartures failed: \(error)")
        }

        isLoadingFuture = false
    }

    func startAutoRefresh(stopId: String) {
        // Invalidate existing timer
        refreshTimer?.invalidate()

        // Schedule new timer (30s interval)
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.refreshDeparturesInPlace(stopId: stopId)
            }
        }
    }

    private func refreshDeparturesInPlace(stopId: String) async {
        // Refresh real-time data for EXISTING time window (don't fetch new future departures)
        // This updates delays/occupancy for already-loaded departures without changing the list
        guard let earliest = earliestTimeSecs, let latest = latestTimeSecs else {
            return  // No existing window to refresh
        }

        do {
            // Fetch departures in the ORIGINAL time window (earliest to latest)
            // This gets updated real-time data for trips already displayed
            let page = try await repository.fetchDeparturesPage(
                stopId: stopId,
                timeSecs: earliest,  // Use original earliest time, not now()
                direction: "future",
                limit: 50  // Larger limit to cover full window
            )

            // Filter to keep only departures within original window
            let refreshedDepartures = page.departures.filter { dep in
                dep.realtimeTimeSecs >= earliest && dep.realtimeTimeSecs <= latest
            }

            // Update departures list (preserves scroll position)
            departures = refreshedDepartures
            loadedDepartureIds = Set(refreshedDepartures.map { $0.id })

            // Keep original boundaries (don't shift window forward)
            // earliestTimeSecs and latestTimeSecs stay unchanged

        } catch {
            // Silent fail (don't disrupt UX)
            print("[DeparturesVM] refreshDeparturesInPlace failed: \(error)")
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
