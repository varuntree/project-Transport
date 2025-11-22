//
//  ServiceAlert.swift
//  SydneyTransit
//
//  Created by Claude Code on 2025-11-22.
//  Phase 2.2 RT Feature Completion - Checkpoint 1
//

import Foundation

/// Service alert from GTFS-RT feed representing a disruption or planned work
///
/// Represents service disruptions, planned work, and other alerts affecting transit service.
/// Used for:
/// - Real-time disruption notifications in departures UI
/// - Alert matching for user favorites (future checkpoints)
/// - Push notification filtering (future checkpoints)
struct ServiceAlert: Codable, Identifiable {
    let id: String
    let headerText: String
    let descriptionText: String?
    let effect: String?  // "NO_SERVICE", "REDUCED_SERVICE", "SIGNIFICANT_DELAYS", etc.
    let cause: String?   // "CONSTRUCTION", "ACCIDENT", "WEATHER", etc.
    let activePeriod: [TimeRange]
    let informedEntity: [EntitySelector]
    let severityLevel: String?  // "WARNING", "SEVERE", "INFO"

    enum CodingKeys: String, CodingKey {
        case id
        case headerText = "header_text"
        case descriptionText = "description_text"
        case effect
        case cause
        case activePeriod = "active_period"
        case informedEntity = "informed_entity"
        case severityLevel = "severity_level"
    }

    /// Time range for alert active period
    struct TimeRange: Codable {
        let start: Int?  // Unix timestamp (nil = unbounded start)
        let end: Int?    // Unix timestamp (nil = unbounded end)
    }

    /// Entity selector identifying affected routes/stops/trips
    struct EntitySelector: Codable {
        let agencyId: String?
        let routeId: String?
        let routeType: Int?  // GTFS route_type (0=tram, 1=metro, 2=rail, 3=bus, 4=ferry)
        let stopId: String?
        let trip: TripDescriptor?

        enum CodingKeys: String, CodingKey {
            case agencyId = "agency_id"
            case routeId = "route_id"
            case routeType = "route_type"
            case stopId = "stop_id"
            case trip
        }
    }

    /// Trip descriptor identifying a GTFS trip
    struct TripDescriptor: Codable {
        let tripId: String

        enum CodingKeys: String, CodingKey {
            case tripId = "trip_id"
        }
    }

    // MARK: - Computed Properties

    /// Check if alert is currently active
    ///
    /// An alert is active if:
    /// - No active periods specified (assumed always active)
    /// - Current time is within at least one active period
    var isActive: Bool {
        let now = Int(Date().timeIntervalSince1970)

        // If no active periods, assume always active
        guard !activePeriod.isEmpty else { return true }

        // Check if current time is within any active period
        return activePeriod.contains { period in
            let afterStart = period.start == nil || now >= period.start!
            let beforeEnd = period.end == nil || now <= period.end!
            return afterStart && beforeEnd
        }
    }

    /// Check if alert affects a specific stop
    ///
    /// - Parameter stopId: Stop ID to check
    /// - Returns: true if this alert affects the stop
    func affectsStop(_ stopId: String) -> Bool {
        return informedEntity.contains { entity in
            entity.stopId == stopId
        }
    }

    /// Check if alert affects a specific route
    ///
    /// - Parameter routeId: Route ID to check
    /// - Returns: true if this alert affects the route
    func affectsRoute(_ routeId: String) -> Bool {
        return informedEntity.contains { entity in
            entity.routeId == routeId
        }
    }

    /// Check if alert affects a specific trip
    ///
    /// - Parameter tripId: Trip ID to check
    /// - Returns: true if this alert affects the trip
    func affectsTrip(_ tripId: String) -> Bool {
        return informedEntity.contains { entity in
            entity.trip?.tripId == tripId
        }
    }

    // MARK: - UI Helpers

    /// Get severity color for UI display
    var severityColor: String {
        switch severityLevel?.uppercased() {
        case "SEVERE":
            return "red"
        case "WARNING":
            return "orange"
        case "INFO":
            return "blue"
        default:
            return "gray"
        }
    }

    /// Get effect icon name for UI display
    var effectIcon: String {
        switch effect?.uppercased() {
        case "NO_SERVICE":
            return "xmark.circle.fill"
        case "REDUCED_SERVICE":
            return "exclamationmark.triangle.fill"
        case "SIGNIFICANT_DELAYS":
            return "clock.fill"
        case "DETOUR", "MODIFIED_SERVICE":
            return "arrow.triangle.turn.up.right.diamond.fill"
        default:
            return "info.circle.fill"
        }
    }
}
