# iOS Research: GRDB FTS5 MATCH Syntax

## Key Pattern
FTS5 MATCH queries use special tokenization syntax. Query string must match tokenizer rules (default: porter stemming). Phrases use quotes, AND/OR/NOT operators supported. Single-term queries match stemmed tokens across all indexed columns.

## Code Example
```swift
import GRDB

struct Stop: FetchableRecord {
    let sid: Int
    let name: String

    static func search(db: Database, query: String) throws -> [Stop] {
        // Basic MATCH query - searches name column
        try Stop.fetchAll(db, sql: """
            SELECT s.* FROM stops s
            JOIN stops_fts ON stops_fts.sid = s.sid
            WHERE stops_fts MATCH ?
            LIMIT 20
            """, arguments: [query])
    }
}

// Usage examples:
// query = "circular"        → matches "Circular Quay", "Circular Station"
// query = "\"circular quay\"" → exact phrase match
// query = "circular OR central" → matches either term
```

## Critical Constraints
- Query syntax errors throw SQLITE_ERROR (use GRDB try/catch)
- Tokenizer must match table definition (tokenize='porter' in Phase 1)
- Special characters (*, ", -, OR, AND, NOT) have semantic meaning - escape user input if literal
- Column weights not supported in basic FTS5 (all columns equal priority)
- MATCH queries case-insensitive by default (folding done by tokenizer)

## Common Gotchas
- User typing "O'Brien" fails (apostrophe treated as token separator) - sanitize input or use prefix queries
- Empty string MATCH query throws error - always check `query.isEmpty` before executing
- Multi-word queries without operators treated as AND by default ("circular quay" = "circular AND quay")
- Prefix wildcards not supported ("*quay" invalid) - only suffix ("quay*")

## API Reference
- SQLite FTS5: https://www.sqlite.org/fts5.html (not Apple docs, core SQLite feature)
- GRDB FTS5: https://github.com/groue/GRDB.swift#full-text-search

## Relevance to Phase 1
Used in Checkpoint 8 (iOS Search UI): `Stop.search(db, query)` performs FTS5 MATCH against stops_fts table. Handles user-typed queries in SearchView's `performSearch()` method. Must validate empty queries, sanitize special characters.
