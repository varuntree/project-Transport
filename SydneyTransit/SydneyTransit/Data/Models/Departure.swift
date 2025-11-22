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
        let secsRemaining = realtimeTimeSecs - currentSydneySecondsSinceMidnight
        return max(0, secsRemaining / 60)
    }

    // Computed: user-facing countdown text
    var minutesUntilText: String {
        let secsRemaining = realtimeTimeSecs - currentSydneySecondsSinceMidnight
        if secsRemaining < -59 {
            let minsAgo = (abs(secsRemaining) + 30) / 60
            return "\(minsAgo) min ago"
        } else if secsRemaining < 0 {
            return "Now"
        } else {
            let mins = max(1, Int(ceil(Double(secsRemaining) / 60.0)))
            return "\(mins) min"
        }
    }

    private var currentSydneySecondsSinceMidnight: Int {
        let sydney = TimeZone(identifier: "Australia/Sydney")!
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = sydney
        let midnight = calendar.startOfDay(for: now)
        return Int(now.timeIntervalSince(midnight))
    }

    // Computed: delay text ('On time', 'X min early', '+X min')
    var delayText: String {
        guard delayS != 0 else {
            return "On time"
        }

        let delayMin = abs(delayS) / 60

        if delayS < 0 {
            // Early
            return "\(delayMin) min early"
        } else {
            // Late
            return "+\(delayMin) min"
        }
    }

    // Computed: delay color (green/gray/orange/red based on delay magnitude)
    var delayColor: Color {
        if delayS < -60 {
            return .green  // Early >1 min
        } else if abs(delayS) <= 60 {
            return .gray   // On time ±1 min
        } else if delayS <= 300 {
            return .orange // Late 1-5 min (60-300 seconds)
        } else {
            return .red    // Late >5 min
        }
    }

    // Computed: is this departure delayed?
    var isDelayed: Bool {
        return abs(delayS) > 60  // More than 1 minute
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

    // Memberwise initializer used by offline GRDB fallback (DatabaseManager).
    init(
        tripId: String,
        routeShortName: String,
        headsign: String,
        scheduledTimeSecs: Int,
        realtimeTimeSecs: Int,
        delayS: Int,
        realtime: Bool,
        platform: String?,
        wheelchairAccessible: Int,
        occupancy_status: Int?
    ) {
        self.tripId = tripId
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.scheduledTimeSecs = scheduledTimeSecs
        self.realtimeTimeSecs = realtimeTimeSecs
        self.delayS = delayS
        self.realtime = realtime
        self.platform = platform
        self.wheelchairAccessible = wheelchairAccessible
        self.occupancy_status = occupancy_status
    }

    // Custom decoding to be resilient to missing or null fields from the backend.
    // This prevents user-visible "Failed to decode response: The data could not be read because it is missing"
    // errors when some departures omit optional fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required identifiers – fall back to empty strings if missing so UI can still render a row
        tripId = try container.decodeIfPresent(String.self, forKey: .tripId) ?? ""
        routeShortName = try container.decodeIfPresent(String.self, forKey: .routeShortName) ?? ""
        headsign = try container.decodeIfPresent(String.self, forKey: .headsign) ?? ""

        // Times and delay – if any field is missing, fall back to safe defaults
        let scheduled = try container.decodeIfPresent(Int.self, forKey: .scheduledTimeSecs) ?? 0
        scheduledTimeSecs = scheduled

        // realtime_time_secs may be omitted for purely static data; default to scheduled time
        realtimeTimeSecs = try container.decodeIfPresent(Int.self, forKey: .realtimeTimeSecs) ?? scheduled

        delayS = try container.decodeIfPresent(Int.self, forKey: .delayS) ?? 0
        realtime = try container.decodeIfPresent(Bool.self, forKey: .realtime) ?? (delayS != 0)

        // Platform can occasionally come back as either a string or an integer code; normalise to String?
        if let platformString = try container.decodeIfPresent(String.self, forKey: .platform) {
            platform = platformString
        } else if let platformInt = try? container.decodeIfPresent(Int.self, forKey: .platform) {
            // Normalise numeric platform codes to their string representation
            platform = String(platformInt)
        } else {
            platform = nil
        }

        wheelchairAccessible = try container.decodeIfPresent(Int.self, forKey: .wheelchairAccessible) ?? 0
        occupancy_status = try container.decodeIfPresent(Int.self, forKey: .occupancy_status)
    }
}
