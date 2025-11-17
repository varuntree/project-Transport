import Foundation
import Logging

protocol DeparturesRepository {
    func fetchDepartures(stopId: String) async throws -> [Departure]
}

class DeparturesRepositoryImpl: DeparturesRepository {
    private let apiClient: APIClient
    private let logger = Logger.app

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

        do {
            // Try API first (real-time data when available)
            let endpoint = APIEndpoint.getDepartures(stopId: stopId)
            let response: Response = try await apiClient.request(endpoint)

            // If API returns data, use it
            if !response.data.departures.isEmpty {
                return response.data.departures
            }

            // API returned empty - fallback to offline
            logger.info("API returned empty departures, using offline data", metadata: ["stop_id": "\(stopId)"])

        } catch {
            // API failed - fallback to offline
            logger.warning("API request failed, using offline data", metadata: [
                "error": "\(error.localizedDescription)",
                "stop_id": "\(stopId)"
            ])
        }

        // Offline fallback: query bundled GRDB
        return try DatabaseManager.shared.getDepartures(stopId: stopId)
    }
}
