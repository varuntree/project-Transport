import Foundation

@MainActor
class TripDetailsViewModel: ObservableObject {
    @Published var trip: Trip?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: TripRepository

    init(repository: TripRepository = TripRepositoryImpl()) {
        self.repository = repository
    }

    func loadTrip(id: String) async {
        isLoading = true
        errorMessage = nil

        do {
            trip = try await repository.fetchTrip(id: id)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            errorMessage = "No internet connection"
        } catch let error as APIError {
            errorMessage = error.errorDescription ?? "Failed to load trip details"
        } catch {
            errorMessage = "Failed to load trip details"
        }

        isLoading = false
    }
}
