import Foundation

protocol DeparturesRepository {
    func fetchDepartures(stopId: String) async throws -> [Departure]
}

class DeparturesRepositoryImpl: DeparturesRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchDepartures(stopId: String) async throws -> [Departure] {
        struct DeparturesData: Codable {
            let departures: [Departure]
            let count: Int
        }

        struct Response: Codable {
            let data: DeparturesData
        }

        let endpoint = APIEndpoint.getDepartures(stopId: stopId)
        let response: Response = try await apiClient.request(endpoint)
        return response.data.departures
    }
}
