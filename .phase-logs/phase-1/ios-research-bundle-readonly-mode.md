# iOS Research: Bundle.main.path Read-Only Mode

## Key Pattern
Bundled SQLite files opened via Bundle.main.path should use read-only mode URI parameters (`?mode=ro&immutable=1`) to prevent write attempts, enable query optimizations, and allow safe concurrent access. GRDB DatabaseQueue handles read-only connections automatically.

## Code Example
```swift
import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()
    private var dbQueue: DatabaseQueue!

    private init() {
        guard let path = Bundle.main.path(forResource: "gtfs", ofType: "db") else {
            fatalError("gtfs.db not found in bundle")
        }

        do {
            // GRDB opens bundled DB as read-only automatically
            // No URI params needed - GRDB detects Bundle.main path
            dbQueue = try DatabaseQueue(path: path)

            // Alternative: explicit read-only mode
            // var config = Configuration()
            // config.readonly = true
            // dbQueue = try DatabaseQueue(path: path, configuration: config)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        try dbQueue.read(block)
    }
}
```

## Critical Constraints
- Bundle.main files are read-only by iOS filesystem (write attempts fail with SQLITE_READONLY)
- `immutable=1` tells SQLite file will never change (enables shared cache, aggressive optimizations)
- GRDB DatabaseQueue enforces read-only for bundled paths (no explicit config needed)
- Concurrent reads safe with immutable flag (no locking overhead)
- Phase 2+ must replace bundled DB with writable Documents copy (for sync, caching)

## Common Gotchas
- Opening bundled DB without read-only mode succeeds but write fails at transaction commit (silent until tested)
- PRAGMA queries (journal_mode, synchronous) return defaults but cannot change settings
- GRDB write() method throws error on read-only DB - use read() exclusively in Phase 1
- Simulator allows writes to Bundle.main (bug) - test on device to catch read-only violations
- Copying bundled DB to Documents requires FileManager - Phase 2 task

## API Reference
- Apple docs: https://developer.apple.com/documentation/foundation/bundle/main
- SQLite URI parameters: https://www.sqlite.org/uri.html (not Apple-specific)
- GRDB Configuration: https://github.com/groue/GRDB.swift#database-configuration

## Relevance to Phase 1
Used in Checkpoint 7 (iOS GRDB Setup): DatabaseManager singleton opens gtfs.db from Bundle.main. Read-only mode prevents accidental writes, allows concurrent searches. Phase 1 has no write requirements (pure offline browsing).
