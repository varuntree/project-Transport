import Foundation
import Combine

@MainActor
class DeparturesViewModel: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var isLoadingPast = false
    @Published var isLoadingFuture = false
    @Published var errorMessage: String?
    @Published var isOffline = false

    private var earliestTimeSecs: Int?
    private var latestTimeSecs: Int?
    @Published private(set) var hasMorePast = true
    @Published private(set) var hasMoreFuture = true
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
            isOffline = page.isOffline

        } catch let error as URLError where error.code == .notConnectedToInternet {
            errorMessage = "No internet connection"
        } catch let error as URLError where error.code == .timedOut {
            errorMessage = "Request timed out. Please try again."
        } catch is DecodingError {
            errorMessage = "Invalid response from server"
        } catch let apiError as APIError {
            // Handle APIError with specific status codes
            if case .serverError(let statusCode, let message) = apiError {
                if statusCode == 404 {
                    errorMessage = "This stop is not in our database"
                } else if statusCode >= 500 {
                    errorMessage = "Server error. Please try again later."
                } else {
                    errorMessage = message ?? "Failed to load departures"
                }
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = "Failed to load departures: \(error.localizedDescription)"
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
        // SLIDING WINDOW REFRESH: Fetch fresh departures from NOW forward
        // MERGE with existing list to preserve "Past" items if user scrolled up
        
        do {
            // Calculate current time (Sydney timezone)
            let sydney = TimeZone(identifier: "Australia/Sydney")!
            let now = Date()
            var calendar = Calendar.current
            calendar.timeZone = sydney
            let midnight = calendar.startOfDay(for: now)
            let nowSecs = Int(now.timeIntervalSince(midnight))
            
            // Fetch departures starting from NOW (not old earliest time)
            let page = try await repository.fetchDeparturesPage(
                stopId: stopId,
                timeSecs: nowSecs,  // NOW - sliding window forward
                direction: "future",
                limit: 15  // Match initial load size
            )

            // MERGE LOGIC:
            // 1. Identify new items
            let newIds = Set(page.departures.map { $0.id })
            
            // 2. Keep existing items that are NOT in the new set (mostly past items)
            // This preserves the "history" at the top of the list
            let keptOldDepartures = self.departures.filter { !newIds.contains($0.id) }
            
            // 3. Combine: Kept Old + New Fresh
            var merged = keptOldDepartures
            merged.append(contentsOf: page.departures)
            
            // 4. Sort by time to ensure correct order
            merged.sort { $0.realtimeTimeSecs < $1.realtimeTimeSecs }
            
            // 5. Update State
            departures = merged
            loadedDepartureIds = Set(merged.map { $0.id })

            // 6. Update boundaries (expand, don't shrink)
            if let newEarliest = page.earliestTimeSecs {
                // If we have existing earliest, keep the min (don't lose our past boundary)
                earliestTimeSecs = min(earliestTimeSecs ?? newEarliest, newEarliest)
            }
            if let newLatest = page.latestTimeSecs {
                // If we have existing latest, keep the max
                latestTimeSecs = max(latestTimeSecs ?? newLatest, newLatest)
            }
            
            // Update flags from the fresh page
            // Note: hasMorePast from a "Future" query (starting at NOW) will usually be true
            hasMorePast = page.hasMorePast
            hasMoreFuture = page.hasMoreFuture
            isOffline = page.isOffline

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
