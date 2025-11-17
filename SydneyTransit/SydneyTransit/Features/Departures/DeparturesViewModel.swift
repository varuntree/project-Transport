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
        } catch {
            errorMessage = "Failed to load departures"
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
