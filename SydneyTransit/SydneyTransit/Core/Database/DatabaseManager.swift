import Foundation
import GRDB
import Logging

@MainActor
class DatabaseManager {
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue

    private init() {
        do {
            // Get bundle path
            guard let path = Bundle.main.path(forResource: "gtfs", ofType: "db") else {
                fatalError("gtfs.db not found in bundle")
            }

            // Read-only configuration
            var config = Configuration()
            config.readonly = true
            config.busyMode = .timeout(5.0)

            // Open database
            dbQueue = try DatabaseQueue(path: path, configuration: config)

            Logger.database.info("database_loaded", metadata: ["path": "\(path)"])

            // Validate database
            try dbQueue.read { db in
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stops") ?? 0
                Logger.database.info("database_validated", metadata: ["stops_count": "\(count)"])
            }
        } catch {
            Logger.database.error("database_init_failed", metadata: ["error": "\(error.localizedDescription)"])
            fatalError("Failed to initialize database: \(error)")
        }
    }

    // Read-only access
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }
}
