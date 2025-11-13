# iOS Research: WITHOUT ROWID Performance

## Key Pattern
WITHOUT ROWID tables store data directly in B-tree by PRIMARY KEY (no separate rowid). Best for tables with non-integer PK or composite keys. Reduces storage 15-20% for small-row tables, improves locality for PK lookups. iOS GRDB supports transparently.

## Code Example
```swift
// SQL schema (backend iOS DB generator creates this):
CREATE TABLE stops (
    sid INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    lat REAL NOT NULL,
    lon REAL NOT NULL
) WITHOUT ROWID;

// GRDB read (no code changes needed):
let stop = try Stop.fetchOne(db, key: 123)  // PK lookup optimized

// Range queries also benefit:
let stops = try Stop.filter(Column("sid") >= 100 && Column("sid") < 200).fetchAll(db)
```

## Critical Constraints
- Requires explicit PRIMARY KEY (sid in Phase 1) - no auto-increment rowid fallback
- Only beneficial if PK frequently used in WHERE/JOIN clauses (true for sid lookups)
- Slower for full table scans (no rowid index to iterate) - use indexed columns
- Cannot use INTEGER PRIMARY KEY AUTOINCREMENT with WITHOUT ROWID
- Must fit in single B-tree page (8KB with page_size=8192) - avoid large BLOB columns

## Common Gotchas
- Adding WITHOUT ROWID to existing table requires recreation (no ALTER TABLE) - Phase 1 generates fresh DB
- FTS5 virtual tables cannot be WITHOUT ROWID (stops_fts remains normal table)
- Composite PRIMARY KEY performance depends on column order (most selective first)
- Deletes can fragment B-tree more than rowid tables (VACUUM recommended after bulk deletes)

## API Reference
- SQLite WITHOUT ROWID: https://www.sqlite.org/withoutrowid.html (core SQLite feature)
- Apple Core Data does not support WITHOUT ROWID (raw SQLite only)

## Relevance to Phase 1
Used in Checkpoint 4 (iOS SQLite Generator): All pattern model tables (stops, routes, patterns, pattern_stops) created WITHOUT ROWID to hit 15-20MB target. Dictionary encoding (text IDs→ints) required first - WITHOUT ROWID amplifies PK optimization.
