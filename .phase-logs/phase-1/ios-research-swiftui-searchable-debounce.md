# iOS Research: SwiftUI .searchable Debouncing

## Key Pattern
SwiftUI .searchable modifier updates binding on every keystroke (no built-in debounce). Use Task + try await Task.sleep() in onChange() to debounce expensive operations like FTS5 queries. Cancel previous task to avoid race conditions. Apple recommends 300-500ms delay for search UX.

## Code Example
```swift
import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Stop] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List(results, id: \.sid) { stop in
            NavigationLink(value: stop) {
                Text(stop.name)
            }
        }
        .searchable(text: $query, prompt: "Search stops")
        .onChange(of: query) { newQuery in
            // Cancel previous search task
            searchTask?.cancel()

            // Debounce: wait 300ms before searching
            searchTask = Task {
                guard !newQuery.isEmpty else {
                    results = []
                    return
                }

                try? await Task.sleep(for: .milliseconds(300))

                // Check if task was cancelled while sleeping
                guard !Task.isCancelled else { return }

                performSearch(query: newQuery)
            }
        }
        .navigationTitle("Search")
    }

    func performSearch(query: String) {
        do {
            results = try DatabaseManager.shared.read { db in
                try Stop.search(db: db, query: query, limit: 20)
            }
        } catch {
            Logger.app.error("Search failed: \(error)")
        }
    }
}
```

## Critical Constraints
- onChange() runs on MainActor (UI updates safe, DB queries block UI if synchronous)
- Task.sleep() uses Swift Concurrency (requires iOS 15+, async/await)
- Must check Task.isCancelled after sleep (avoids stale queries updating results)
- Store Task reference to cancel on next keystroke (prevents query backlog)
- Empty query check before sleep (immediate clear, no 300ms delay)

## Common Gotchas
- Forgetting searchTask?.cancel() causes multiple concurrent queries (last-write-wins race)
- Using DispatchQueue.asyncAfter instead of Task.sleep (cannot cancel, leaks closures)
- Debounce delay too short (<200ms) still triggers many queries; too long (>500ms) feels laggy
- FTS5 queries <50ms don't need debounce (test on device) - Phase 1's 15-20MB DB likely fast enough
- Task.sleep(for:) unavailable on older iOS - use try await Task.sleep(nanoseconds: 300_000_000)

## API Reference
- Apple docs: https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)
- Apple docs: https://developer.apple.com/documentation/swiftui/performing-a-search-operation
- Combine debounce alternative: https://developer.apple.com/documentation/combine/publishers/debounce

## Relevance to Phase 1
Used in Checkpoint 8 (iOS Search UI): SearchView's performSearch() debounces FTS5 MATCH queries. Prevents querying database on every keystroke (especially for multi-word queries). If FTS5 search <100ms, debounce may be optional - test and remove if unnecessary.
