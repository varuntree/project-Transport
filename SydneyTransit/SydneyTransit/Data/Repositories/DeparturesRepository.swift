import Foundation
import Logging

struct DeparturesPage {
    let departures: [Departure]
    let earliestTimeSecs: Int?
    let latestTimeSecs: Int?
    let hasMorePast: Bool
    let hasMoreFuture: Bool
}

protocol DeparturesRepository {
    func fetchDepartures(stopId: String) async throws -> [Departure]
    func fetchDeparturesPage(stopId: String, timeSecs: Int?, direction: String, limit: Int) async throws -> DeparturesPage
}

class DeparturesRepositoryImpl: DeparturesRepository {
    private let apiClient: APIClient
    private let offlineLimit: Int
    private let logger = Logger.app

    init(apiClient: APIClient = .shared, offlineLimit: Int = 20) {
        self.apiClient = apiClient
        self.offlineLimit = offlineLimit
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
            logger.info(
                "API returned empty departures, using offline data",
                metadata: .from(["stop_id": stopId])
            )

        } catch {
            // API failed - fallback to offline
            logger.warning(
                "API request failed, using offline data",
                metadata: .from([
                    "error": error.localizedDescription,
                    "stop_id": stopId
                ])
            )
        }

        // Offline fallback: query bundled GRDB
        do {
            let departures = try DatabaseManager.shared.getDepartures(stopId: stopId, limit: offlineLimit)
            logger.info(
                "offline_departures_loaded",
                metadata: .from([
                    "stop_id": stopId,
                    "count": departures.count
                ])
            )
            return departures
        } catch {
            logger.warning(
                "offline_departures_failed",
                metadata: .from([
                    "stop_id": stopId,
                    "error": error.localizedDescription
                ])
            )
            return []
        }
    }

    func fetchDeparturesPage(stopId: String, timeSecs: Int?, direction: String, limit: Int) async throws -> DeparturesPage {
        struct PaginationMeta: Codable {
            let hasMorePast: Bool?
            let hasMoreFuture: Bool?
            let earliestTimeSecs: Int?
            let latestTimeSecs: Int?
            let direction: String?

            enum CodingKeys: String, CodingKey {
                case hasMorePast = "has_more_past"
                case hasMoreFuture = "has_more_future"
                case earliestTimeSecs = "earliest_time_secs"
                case latestTimeSecs = "latest_time_secs"
                case direction
            }
        }

        struct MetaData: Codable {
            let pagination: PaginationMeta?
        }

        struct DeparturesData: Codable {
            let departures: [Departure]
            let count: Int
        }

        struct Response: Codable {
            let data: DeparturesData
            let meta: MetaData
        }

        let endpoint = APIEndpoint.getDepartures(stopId: stopId, timeSecs: timeSecs, direction: direction, limit: limit)
        let response: Response = try await apiClient.request(endpoint)

        return DeparturesPage(
            departures: response.data.departures,
            earliestTimeSecs: response.meta.pagination?.earliestTimeSecs,
            latestTimeSecs: response.meta.pagination?.latestTimeSecs,
            hasMorePast: response.meta.pagination?.hasMorePast ?? false,
            hasMoreFuture: response.meta.pagination?.hasMoreFuture ?? false
        )
    }
}
