import Foundation
import SwiftUI

struct Departure: Codable, Identifiable, Hashable {
    let tripId: String
    let routeShortName: String
    let headsign: String
    let scheduledTimeSecs: Int
    let realtimeTimeSecs: Int
    let minutesUntil: Int  // Centralized from backend
    let delayS: Int
    let realtime: Bool
    let platform: String?
    let wheelchairAccessible: Int
    let occupancy_status: Int?
    let stopSequence: Int

    // Unique ID: trip can visit same stop multiple times, so use trip_id + scheduled_time + stop_sequence
    var id: String { "\(tripId)_\(scheduledTimeSecs)_\(stopSequence)" }

    // Computed: user-facing countdown text
    var minutesUntilText: String {
        // Logic centralized in backend, this is just formatting
        if minutesUntil == 0 {
            // Check if it's actually "Now" or "Left already"
            // For simplicity, if backend says 0, we show "Now" or "Due"
            // But wait, if delayS is negative (early), minutesUntil might be 0 even if early?
            // Backend: max(0, remaining // 60). So negatives become 0.
            return "Now"
        } else {
            return "\(minutesUntil) min"
        }
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
        case minutesUntil = "minutes_until"
        case delayS = "delay_s"
        case realtime
        case platform
        case wheelchairAccessible = "wheelchair_accessible"
        case occupancy_status = "occupancy_status"
        case stopSequence = "stop_sequence"
    }

    // Memberwise initializer used by offline GRDB fallback (DatabaseManager).
    init(
        tripId: String,
        routeShortName: String,
        headsign: String,
        scheduledTimeSecs: Int,
        realtimeTimeSecs: Int,
        minutesUntil: Int,
        delayS: Int,
        realtime: Bool,
        platform: String?,
        wheelchairAccessible: Int,
        occupancy_status: Int?,
        stopSequence: Int
    ) {
        self.tripId = tripId
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.scheduledTimeSecs = scheduledTimeSecs
        self.realtimeTimeSecs = realtimeTimeSecs
        self.minutesUntil = minutesUntil
        self.delayS = delayS
        self.realtime = realtime
        self.platform = platform
        self.wheelchairAccessible = wheelchairAccessible
        self.occupancy_status = occupancy_status
        self.stopSequence = stopSequence
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

        minutesUntil = try container.decodeIfPresent(Int.self, forKey: .minutesUntil) ?? 0
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
        stopSequence = try container.decodeIfPresent(Int.self, forKey: .stopSequence) ?? 0
    }
}
