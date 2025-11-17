import Foundation
import GRDB
import SwiftUI

struct Route: Codable, FetchableRecord, Identifiable {
    var id: Int { rid }

    let rid: Int
    let routeShortName: String?
    let routeLongName: String?
    let routeType: Int
    let routeColor: String?
    let routeTextColor: String?

    enum CodingKeys: String, CodingKey {
        case rid
        case routeShortName = "route_short_name"
        case routeLongName = "route_long_name"
        case routeType = "route_type"
        case routeColor = "route_color"
        case routeTextColor = "route_text_color"
    }

    // Route type enum
    var type: RouteType {
        return RouteType(rawValue: routeType) ?? .unknown
    }

    // Display name (fallback for NULL names)
    var displayName: String {
        return routeShortName ?? routeLongName ?? "Unknown Route"
    }

    var displayLongName: String {
        return routeLongName ?? routeShortName ?? "Unknown Route"
    }

    // Fetch all routes
    static func fetchAll(_ db: Database) throws -> [Route] {
        return try Route.fetchAll(db, sql: "SELECT * FROM routes ORDER BY route_short_name")
    }

    // Fetch by type
    static func fetchByType(_ db: Database, type: RouteType) throws -> [Route] {
        return try Route.fetchAll(db, sql: "SELECT * FROM routes WHERE route_type = ? ORDER BY route_short_name", arguments: [type.rawValue])
    }
}

enum RouteType: Int, CaseIterable {
    case tram = 0
    case metro = 1
    case rail = 2
    case bus = 3
    case ferry = 4
    case cableTram = 5
    case aerialLift = 6
    case funicular = 7
    case unknown = -1

    var displayName: String {
        switch self {
        case .tram: return "Tram"
        case .metro: return "Metro"
        case .rail: return "Train"
        case .bus: return "Bus"
        case .ferry: return "Ferry"
        case .cableTram: return "Cable Tram"
        case .aerialLift: return "Aerial Lift"
        case .funicular: return "Funicular"
        case .unknown: return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .rail: return .red
        case .metro: return .purple
        case .bus: return .blue
        case .ferry: return .green
        case .tram: return .orange
        default: return .gray
        }
    }
}
