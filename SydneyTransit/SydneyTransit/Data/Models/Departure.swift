import Foundation

struct Departure: Codable, Identifiable {
    let tripId: String
    let routeShortName: String
    let headsign: String
    let scheduledTimeSecs: Int
    let realtimeTimeSecs: Int
    let delayS: Int
    let realtime: Bool

    var id: String { tripId }

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

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case routeShortName = "route_short_name"
        case headsign
        case scheduledTimeSecs = "scheduled_time_secs"
        case realtimeTimeSecs = "realtime_time_secs"
        case delayS = "delay_s"
        case realtime
    }
}
