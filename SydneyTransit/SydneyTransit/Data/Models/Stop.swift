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

    // FTS5 search (sanitized)
    static func search(_ db: Database, query: String) throws -> [Stop] {
        // Sanitize query (remove FTS5 special chars)
        let sanitized = query
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: " OR ", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: " AND ", with: " ", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        guard !sanitized.isEmpty else { return [] }

        // FTS5 MATCH query
        let sql = """
            SELECT s.*
            FROM stops s
            JOIN stops_fts fts ON s.sid = fts.sid
            WHERE stops_fts MATCH ?
            LIMIT 50
        """

        return try Stop.fetchAll(db, sql: sql, arguments: [sanitized + "*"])
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
}
