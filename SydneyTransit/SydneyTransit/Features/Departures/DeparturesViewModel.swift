import Foundation

@MainActor
class DeparturesViewModel: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: DeparturesRepository
    private var refreshTimer: Timer?

    init(repository: DeparturesRepository = DeparturesRepositoryImpl()) {
        self.repository = repository
    }

    func loadDepartures(stopId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            departures = try await repository.fetchDepartures(stopId: stopId)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            errorMessage = "No internet connection"
        } catch let error as URLError where error.code == .timedOut {
            errorMessage = "Request timed out. Please try again."
        } catch let error as DecodingError {
            errorMessage = "Invalid response from server"
        } catch {
            // Check if it's an HTTP error with details
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

    func startAutoRefresh(stopId: String) {
        // Invalidate existing timer
        refreshTimer?.invalidate()

        // Schedule new timer (30s interval)
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.loadDepartures(stopId: stopId)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
