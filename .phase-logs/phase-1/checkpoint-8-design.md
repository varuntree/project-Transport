# Checkpoint 8: iOS GRDB Setup + Models

## Goal
Add GRDB to iOS via SPM, bundle gtfs.db in app, create DatabaseManager singleton with read-only access, create Stop/Route models with FTS5 search support.

## Approach

### iOS Implementation
- Add GRDB.swift via Swift Package Manager
- Copy generated gtfs.db to iOS project Resources
- Create database singleton + models
- Files to create:
  - `SydneyTransit/Core/Database/DatabaseManager.swift` - Singleton for DB access
  - `SydneyTransit/Data/Models/Stop.swift` - Stop model with FTS5 search
  - `SydneyTransit/Data/Models/Route.swift` - Route model
  - `SydneyTransit/Resources/gtfs.db` - Bundled SQLite (copied from backend)
- Files to modify:
  - Xcode project: Add GRDB SPM dependency, add gtfs.db to Copy Bundle Resources
- Critical pattern: Read-only DB access (immutable), FTS5 MATCH query sanitization

### Implementation Details

**Step 1: Add GRDB via SPM**

Xcode → File → Add Package Dependencies:
- URL: `https://github.com/groue/GRDB.swift`
- Version: 6.22.0 or later (Up to Next Major)
- Add to target: SydneyTransit

**Step 2: Copy gtfs.db to Resources**

```bash
# Backend generates gtfs.db (Checkpoint 5)
# Copy to iOS project:
cp backend/ios_output/gtfs.db SydneyTransit/SydneyTransit/Resources/gtfs.db
```

Xcode → Project Navigator → Add Files:
- Select `Resources/gtfs.db`
- Add to target: SydneyTransit
- Verify: Build Phases → Copy Bundle Resources → gtfs.db listed

**Step 3: DatabaseManager Singleton**

```swift
// Core/Database/DatabaseManager.swift
import Foundation
import GRDB

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
            config.prepareDatabase { db in
                db.busyMode = .timeout(5.0)
            }

            // Open database
            dbQueue = try DatabaseQueue(path: path, configuration: config)

            Logger.app.info("database_loaded", path: path)

            // Validate database
            try dbQueue.read { db in
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stops") ?? 0
                Logger.app.info("database_validated", stops_count: count)
            }
        } catch {
            Logger.app.error("database_init_failed", error: error.localizedDescription)
            fatalError("Failed to initialize database: \\(error)")
        }
    }

    // Read-only access
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }
}
```

**Step 4: Stop Model with FTS5 Search**

```swift
// Data/Models/Stop.swift
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
            .replacingOccurrences(of: "OR", with: "")
            .replacingOccurrences(of: "AND", with: "")
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
```

**Step 5: Route Model**

```swift
// Data/Models/Route.swift
import Foundation
import GRDB

struct Route: Codable, FetchableRecord, Identifiable {
    var id: Int { rid }

    let rid: Int
    let routeShortName: String
    let routeLongName: String
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
        case .train: return .red
        case .metro: return .purple
        case .bus: return .blue
        case .ferry: return .green
        case .tram: return .orange
        default: return .gray
        }
    }
}
```

## Design Constraints
- **Read-only mode:** `config.readonly = true` prevents writes (crash if attempted)
- **Bundle.main.path:** Works in simulator + device, fails gracefully if missing
- **FTS5 sanitization:** Remove *, ", OR, AND to prevent SQLITE_ERROR
- **Porter tokenization:** FTS5 uses porter stemming (e.g., "Station" → "station"), add * for prefix search
- **Main actor:** DatabaseManager marked @MainActor for thread safety with SwiftUI
- Follow IOS_APP_SPECIFICATION.md:Section 4.2 for GRDB patterns
- iOS research: `.phase-logs/phase-1/ios-research-bundle-readonly-mode.md` for read-only config
- iOS research: `.phase-logs/phase-1/ios-research-grdb-fts5-match.md` for FTS5 syntax

## Risks
- **gtfs.db not in bundle:** Build succeeds but runtime crash
  - Mitigation: Validate in Build Phases, guard let in DatabaseManager
- **FTS5 SQLITE_ERROR:** Unsanitized query with special chars
  - Mitigation: Explicit sanitization in Stop.search()
- **Thread safety:** GRDB access from background threads
  - Mitigation: @MainActor on DatabaseManager (SwiftUI always main thread)
- **Large bundle:** 15-20MB DB increases app size
  - Mitigation: Acceptable for Phase 1, Phase 2 adds download logic

## Validation
```bash
# Open Xcode
open SydneyTransit/SydneyTransit.xcodeproj

# Build (Cmd+B)
# Expected: No GRDB import errors, build succeeds

# Check Package Dependencies:
# Xcode → Project → Package Dependencies → GRDB.swift 6.22.0+ listed

# Check Bundle Resources:
# Xcode → Target SydneyTransit → Build Phases → Copy Bundle Resources
# Expected: gtfs.db listed

# Run in simulator (Cmd+R)
# Expected: App launches without crash

# Check Xcode Console logs:
# database_loaded: path=/Users/.../gtfs.db
# database_validated: stops_count=15000

# Test search in LLDB console (pause app):
# (lldb) po try DatabaseManager.shared.read { try Stop.search($0, query: "circular") }
# Expected: Array of Stop objects with "Circular Quay" in name
```

## References for Subagent
- Exploration report: `critical_patterns` → "GRDB read-only singleton (iOS)"
- Standards: DEVELOPMENT_STANDARDS.md:Section 3.2.2 (iOS model patterns)
- Architecture: IOS_APP_SPECIFICATION.md:Section 4.2 (GRDB setup)
- iOS research: `.phase-logs/phase-1/ios-research-bundle-readonly-mode.md` (read-only config)
- iOS research: `.phase-logs/phase-1/ios-research-grdb-fts5-match.md` (FTS5 MATCH syntax)
- iOS research: `.phase-logs/phase-1/ios-research-without-rowid.md` (schema reference)
- Existing Logger: SydneyTransit/Core/Utilities/Logger.swift (Phase 0)
- iOS SQLite schema: Checkpoint 5 (dict tables, FTS5 structure)

## Estimated Complexity
**moderate** - SPM integration straightforward, but GRDB configuration, FTS5 sanitization, read-only setup require careful attention. Bundle resource setup critical (easy to miss).
