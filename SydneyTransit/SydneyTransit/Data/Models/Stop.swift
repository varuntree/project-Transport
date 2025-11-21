import Foundation
import GRDB

struct Stop: Codable, FetchableRecord, Identifiable {
    var id: Int { sid }

    let sid: Int
    let stopCode: String?
    let stopName: String
    let stopLat: Double
    let stopLon: Double
    let wheelchairBoarding: Int?

    enum CodingKeys: String, CodingKey {
        case sid
        case stopCode = "stop_code"
        case stopName = "stop_name"
        case stopLat = "stop_lat"
        case stopLon = "stop_lon"
        case wheelchairBoarding = "wheelchair_boarding"
    }

    // FTS5 search (sanitized), optionally filtered by route_type
    static func search(_ db: Database, query: String, routeTypes: [Int]? = nil) throws -> [Stop] {
        // Sanitize query (remove FTS5 special chars)
        let punctuation = CharacterSet.punctuationCharacters
        let cleaned = query.unicodeScalars.map { scalar -> Character in
            punctuation.contains(scalar) ? " " : Character(scalar)
        }

        let sanitized = String(cleaned)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: " OR ", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: " AND ", with: " ", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else { return [] }

        if let routeTypes = routeTypes, !routeTypes.isEmpty {
            // FTS5 MATCH + route_type filter via JOIN
            // CRITICAL: FTS5 MATCH must be in WHERE clause (not JOIN ON) for index usage
            let placeholders = routeTypes.map { _ in "?" }.joined(separator: ",")
            let sql = """
                SELECT DISTINCT s.*
                FROM stops_fts
                JOIN stops s ON stops_fts.rowid = s.rowid
                JOIN pattern_stops ps ON s.sid = ps.sid
                JOIN patterns p ON ps.pid = p.pid
                JOIN routes r ON p.rid = r.rid
                WHERE stops_fts MATCH ?
                  AND r.route_type IN (\(placeholders))
                LIMIT 50
                """

            var arguments = [DatabaseValueConvertible]()
            arguments.append(sanitized + "*")
            arguments.append(contentsOf: routeTypes)

            return try Stop.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        } else {
            // FTS5 MATCH only (existing behavior)
            let sql = """
                SELECT s.*
                FROM stops_fts
                JOIN stops s ON stops_fts.rowid = s.rowid
                WHERE stops_fts MATCH ?
                LIMIT 50
                """

            return try Stop.fetchAll(db, sql: sql, arguments: [sanitized + "*"])
        }
    }

    // Get stop by ID
    static func fetchByID(_ db: Database, sid: Int) throws -> Stop? {
        return try Stop.fetchOne(db, sql: "SELECT * FROM stops WHERE sid = ?", arguments: [sid])
    }

    // Lookup stop_id from dict
    static func fetchByStopID(_ db: Database, stopID: String) throws -> Stop? {
        let sql = """
            SELECT s.*
            FROM stops s
            JOIN dict_stop d ON s.sid = d.sid
            WHERE d.stop_id = ?
        """
        return try Stop.fetchOne(db, sql: sql, arguments: [stopID])
    }

    // Get GTFS stop_id for this stop (for API calls)
    func getStopID() throws -> String? {
        return try DatabaseManager.shared.read { db in
            let sql = "SELECT stop_id FROM dict_stop WHERE sid = ?"
            return try String.fetchOne(db, sql: sql, arguments: [sid])
        }
    }

    // Primary route type (most frequent route_type serving this stop)
    // Computed property - queries DB each access (optimize later if needed)
    nonisolated var primaryRouteType: Int? {
        do {
            return try MainActor.assumeIsolated {
                try DatabaseManager.shared.read { db in
                    let sql = """
                        SELECT r.route_type
                        FROM pattern_stops ps
                        JOIN patterns p ON ps.pid = p.pid
                        JOIN routes r ON p.rid = r.rid
                        WHERE ps.sid = ?
                        GROUP BY r.route_type
                        ORDER BY COUNT(*) DESC
                        LIMIT 1
                    """
                    return try Int.fetchOne(db, sql: sql, arguments: [sid])
                }
            }
        } catch {
            return nil
        }
    }

    // Transport mode SF Symbol icon
    var transportIcon: String {
        switch primaryRouteType {
        case 0, 900: return "tram.fill"           // Tram/Light Rail (900=NSW Light Rail)
        case 1: return "lightrail.fill"      // Metro/Subway
        case 2: return "train.side.front.car" // Rail
        case 3: return "bus.fill"            // Bus (standard GTFS)
        case 4: return "ferry.fill"          // Ferry
        case 5: return "cablecar.fill"       // Cable Tram
        case 401: return "lightrail.fill"    // NSW Metro
        case 700, 712, 714: return "bus.fill" // NSW Bus variants
        default: return "mappin.circle.fill" // Generic/Unknown
        }
    }

    // Route type display name (for accessibility)
    var routeTypeDisplayName: String {
        switch primaryRouteType {
        case 0, 900: return "Light Rail"  // 900=NSW Light Rail
        case 1: return "Metro"
        case 2: return "Train"
        case 3: return "Bus"
        case 4: return "Ferry"
        case 5: return "Cable Tram"
        case 401: return "Metro"  // NSW Metro
        case 700, 712, 714: return "Bus"
        default: return "Stop"
        }
    }
}
