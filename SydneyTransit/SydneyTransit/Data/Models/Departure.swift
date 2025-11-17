import Foundation
import SwiftUI

struct Departure: Codable, Identifiable, Hashable {
    let tripId: String
    let routeShortName: String
    let headsign: String
    let scheduledTimeSecs: Int
    let realtimeTimeSecs: Int
    let delayS: Int
    let realtime: Bool
    let platform: String?
    let wheelchairAccessible: Int
    let occupancy_status: Int?

    // Unique ID: trip can visit same stop multiple times, so use trip_id + scheduled_time
    var id: String { "\(tripId)_\(scheduledTimeSecs)" }

    // Computed: minutes until departure (from now)
    var minutesUntil: Int {
        let sydney = TimeZone(identifier: "Australia/Sydney")!
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = sydney
        let midnight = calendar.startOfDay(for: now)
        let secsSinceMidnight = Int(now.timeIntervalSince(midnight))
        let secsRemaining = realtimeTimeSecs - secsSinceMidnight
        return max(0, secsRemaining / 60)
    }

    // Computed: delay text ('+X min' if delayed, nil otherwise)
    var delayText: String? {
        guard delayS > 0 else { return nil }
        let mins = delayS / 60
        return "+\(mins) min"
    }

    // Computed: formatted departure time (HH:mm)
    var departureTime: String {
        let mins = realtimeTimeSecs / 60
        let hours = mins / 60
        let remainingMins = mins % 60
        return String(format: "%02d:%02d", hours, remainingMins)
    }

    // Computed: occupancy icon (SF Symbol + color + accessibility label)
    var occupancyIcon: (symbolName: String, color: Color, label: String)? {
        guard let status = occupancy_status else { return nil }

        switch status {
        case 0...1:
            return ("figure.stand", .green, "Low occupancy")
        case 2:
            return ("figure.stand.line.dotted.figure.stand", .yellow, "Moderate occupancy")
        case 3...4:
            return ("figure.stand.line.dotted.figure.stand", .orange, "High occupancy")
        case 5...6:
            return ("figure.stand.line.dotted.figure.stand", .red, "Very crowded")
        default:
            return nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case routeShortName = "route_short_name"
        case headsign
        case scheduledTimeSecs = "scheduled_time_secs"
        case realtimeTimeSecs = "realtime_time_secs"
        case delayS = "delay_s"
        case realtime
        case platform
        case wheelchairAccessible = "wheelchair_accessible"
        case occupancy_status = "occupancy_status"
    }
}
