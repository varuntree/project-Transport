import Foundation

protocol TripRepository {
    func fetchTrip(id: String) async throws -> Trip
}

class TripRepositoryImpl: TripRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchTrip(id: String) async throws -> Trip {
        struct Response: Codable {
            let data: Trip
        }

        let endpoint = APIEndpoint.getTrip(tripId: id)
        let response: Response = try await apiClient.request(endpoint)
        return response.data
    }
}
