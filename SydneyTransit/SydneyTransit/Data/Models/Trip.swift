import Foundation
import SwiftUI

struct Trip: Codable, Identifiable {
    let tripId: String
    let route: RouteInfo
    let headsign: String
    let stops: [TripStop]

    var id: String { tripId }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case route
        case headsign
        case stops
    }
}

struct RouteInfo: Codable {
    let shortName: String
    let color: String?

    enum CodingKeys: String, CodingKey {
        case shortName = "short_name"
        case color
    }
}

struct TripStop: Codable, Identifiable {
    let stopId: String
    let stopName: String
    let arrivalTimeSecs: Int
    let platform: String?
    let wheelchairAccessible: Int
    let lat: Double?
    let lon: Double?

    // Real-time fields (optional, backward-compatible)
    let delayS: Int?
    let realtime: Bool?
    let realtimeArrivalTimeSecs: Int?

    var id: String { stopId }

    // Computed: arrival time to display (RT if available, else scheduled)
    var displayArrivalTimeSecs: Int {
        return realtimeArrivalTimeSecs ?? arrivalTimeSecs
    }

    // Computed: is this stop delayed?
    var isDelayed: Bool {
        guard let delay = delayS else { return false }
        return abs(delay) > 60  // More than 1 minute
    }

    // Computed: formatted arrival time (HH:mm) - uses displayArrivalTimeSecs
    var arrivalTime: String {
        let mins = displayArrivalTimeSecs / 60
        let hours = mins / 60
        let remainingMins = mins % 60
        return String(format: "%02d:%02d", hours, remainingMins)
    }

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case arrivalTimeSecs = "arrival_time_secs"
        case platform
        case wheelchairAccessible = "wheelchair_accessible"
        case lat
        case lon
        case delayS = "delay_s"
        case realtime
        case realtimeArrivalTimeSecs = "realtime_arrival_time_secs"
    }
}

// MARK: - TripStop Computed Properties (Delay Badge)
extension TripStop {
    // Computed: delay color (green/gray/orange/red based on delay magnitude)
    var delayColor: Color {
        guard let delayS = delayS else {
            return .gray  // No RT data
        }

        if delayS < -60 {
            return .green  // Early >1 min
        } else if abs(delayS) <= 60 {
            return .gray   // On time ±1 min
        } else if delayS <= 300 {
            return .orange // Late 1-5 min
        } else {
            return .red    // Late >5 min
        }
    }

    // Computed: delay text ('On time', 'X min early', '+X min')
    var delayText: String {
        guard let delayS = delayS, delayS != 0 else {
            return "On time"
        }

        let delayMin = abs(delayS) / 60

        if delayS < 0 {
            return "\(delayMin) min early"
        } else {
            return "+\(delayMin) min"
        }
    }
}
