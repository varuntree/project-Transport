//
//  AlertRepository.swift
//  SydneyTransit
//
//  Created by Claude Code on 2025-11-22.
//  Phase 2.2 RT Feature Completion - Checkpoint 2
//

import Foundation
import Logging

// MARK: - Protocol

/// Repository for fetching service alerts
protocol AlertRepository {
    /// Fetch active alerts affecting a specific stop
    /// - Parameter stopId: Stop ID to fetch alerts for
    /// - Returns: Array of ServiceAlert objects
    func fetchAlerts(stopId: String) async throws -> [ServiceAlert]
}

// MARK: - Implementation

/// Implementation of AlertRepository using APIClient
class AlertRepositoryImpl: AlertRepository {
    private let apiClient: APIClient
    private let logger = Logger.app

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchAlerts(stopId: String) async throws -> [ServiceAlert] {
        struct Response: Decodable {
            struct Data: Decodable {
                let alerts: [ServiceAlert]
                let count: Int
            }
            struct Meta: Decodable {
                let stopId: String
                let at: Int

                enum CodingKeys: String, CodingKey {
                    case stopId = "stop_id"
                    case at
                }
            }
            let data: Data
            let meta: Meta
        }

        // Use APIClient.get() with custom endpoint path
        let endpoint = "/api/v1/stops/\(stopId)/alerts"

        do {
            let response: Response = try await apiClient.get(endpoint)

            logger.info(
                "alerts_fetched",
                metadata: .from([
                    "stop_id": stopId,
                    "count": response.data.count
                ])
            )

            return response.data.alerts

        } catch {
            logger.error(
                "alerts_fetch_failed",
                metadata: .from([
                    "stop_id": stopId,
                    "error": error.localizedDescription
                ])
            )
            throw error
        }
    }
}
