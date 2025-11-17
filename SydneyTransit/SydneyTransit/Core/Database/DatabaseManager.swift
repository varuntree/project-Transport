import Foundation
import GRDB
import Logging

@MainActor
class DatabaseManager {
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue

    private init() {
        do {
            // Get bundle path with better debugging
            guard let path = Bundle.main.path(forResource: "gtfs", ofType: "db") else {
                // Log all resources for debugging
                if let resourcePath = Bundle.main.resourcePath {
                    Logger.database.error("database_not_found_in_bundle", metadata: [
                        "resource_path": "\(resourcePath)",
                        "searched_for": "gtfs.db"
                    ])
                }
                fatalError("gtfs.db not found in bundle")
            }

            // Read-only configuration
            var config = Configuration()
            config.readonly = true
            config.busyMode = .timeout(5.0)

            // Open database
            dbQueue = try DatabaseQueue(path: path, configuration: config)

            Logger.database.info("database_loaded", metadata: ["path": "\(path)"])

            // Validate database with more checks
            try dbQueue.read { db in
                let stopsCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stops") ?? 0
                let routesCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM routes") ?? 0

                Logger.database.info("database_validated", metadata: [
                    "stops_count": "\(stopsCount)",
                    "routes_count": "\(routesCount)"
                ])

                // Test route decoding
                if let firstRoute = try? Route.fetchOne(db, sql: "SELECT * FROM routes LIMIT 1") {
                    Logger.database.info("route_decode_test_passed", metadata: [
                        "route_id": "\(firstRoute.rid)",
                        "route_name": "\(firstRoute.routeShortName)"
                    ])
                } else {
                    Logger.database.warning("route_decode_test_failed")
                }
            }
        } catch {
            Logger.database.error("database_init_failed", metadata: [
                "error": "\(error.localizedDescription)",
                "error_type": "\(type(of: error))"
            ])
            fatalError("Failed to initialize database: \(error)")
        }
    }

    // Read-only access
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }
}
