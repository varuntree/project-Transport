import Foundation

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

    var id: String { stopId }

    // Computed: formatted arrival time (HH:mm)
    var arrivalTime: String {
        let mins = arrivalTimeSecs / 60
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
    }
}
