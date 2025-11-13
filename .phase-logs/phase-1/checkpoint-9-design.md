# Checkpoint 9: iOS Search UI

## Goal
Create SearchView with SwiftUI .searchable modifier, debounced FTS5 stop search (<200ms), NavigationLink to StopDetailsView. Update HomeView with navigation.

## Approach

### iOS Implementation
- Create search UI with debouncing to avoid excessive FTS5 queries
- Files to create:
  - `SydneyTransit/Features/Search/SearchView.swift` - Main search screen
- Files to modify:
  - `SydneyTransit/Features/Home/HomeView.swift` - Add NavigationLink to search
- Critical pattern: SwiftUI .searchable debouncing (Task + sleep), FTS5 query optimization

### Implementation Details

**SearchView Implementation:**

```swift
// Features/Search/SearchView.swift
import SwiftUI
import GRDB

struct SearchView: View {
    @State private var searchQuery = ""
    @State private var searchResults: [Stop] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if searchResults.isEmpty && !searchQuery.isEmpty {
                Text("No stops found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(searchResults) { stop in
                    NavigationLink(destination: StopDetailsView(stop: stop)) {
                        StopRow(stop: stop)
                    }
                }
            }
        }
        .navigationTitle("Search Stops")
        .searchable(text: $searchQuery, prompt: "Search for stops")
        .onChange(of: searchQuery) { oldValue, newValue in
            performSearch(query: newValue)
        }
        .onAppear {
            Logger.app.info("search_view_appeared")
        }
    }

    private func performSearch(query: String) {
        // Cancel previous search task
        searchTask?.cancel()

        // Clear results if query empty
        guard !query.isEmpty else {
            searchResults = []
            isLoading = false
            return
        }

        // Debounce: wait 300ms before searching
        searchTask = Task {
            isLoading = true

            // Wait for debounce period
            try? await Task.sleep(for: .milliseconds(300))

            // Check if task was cancelled
            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            // Perform search
            do {
                let results = try await DatabaseManager.shared.read { db in
                    try Stop.search(db, query: query)
                }

                // Update UI on main thread
                await MainActor.run {
                    searchResults = results
                    isLoading = false
                    Logger.app.info("search_complete", query: query, result_count: results.count)
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isLoading = false
                    Logger.app.error("search_failed", query: query, error: error.localizedDescription)
                }
            }
        }
    }
}

struct StopRow: View {
    let stop: Stop

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stop.stopName)
                .font(.headline)

            if let stopCode = stop.stopCode {
                Text("Stop \(stopCode)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("\\(stop.stopLat, specifier: "%.4f"), \\(stop.stopLon, specifier: "%.4f")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
```

**Update HomeView:**

```swift
// Features/Home/HomeView.swift (add to existing file)
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Sydney Transit")
                    .font(.largeTitle)
                    .bold()

                // Navigation to Search
                NavigationLink(destination: SearchView()) {
                    Label("Search Stops", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                // Navigation to Routes (Checkpoint 10)
                NavigationLink(destination: RouteListView()) {
                    Label("Browse Routes", systemImage: "map")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
```

**Debouncing Strategy:**

1. **User types:** "circu"
2. **onChange triggers:** Start new Task, cancel previous
3. **Wait 300ms:** Task.sleep(for: .milliseconds(300))
4. **Check cancelled:** Previous task cancelled when new char typed
5. **Query DB:** Only after 300ms idle
6. **Update UI:** On main thread

This avoids FTS5 query on every keystroke (typing "circular" = 8 chars = 1 query, not 8).

## Design Constraints
- **Debounce delay:** 300ms (balance responsiveness vs query count)
- **Cancel previous task:** Avoid race conditions (multiple queries in flight)
- **Main thread updates:** `await MainActor.run {}` for UI state changes
- **Empty query:** Clear results immediately (don't wait for debounce)
- **FTS5 limit:** Stop.search() already limits to 50 results (prevent huge result sets)
- Follow IOS_APP_SPECIFICATION.md:Section 5.2 for search UI patterns
- iOS research: `.phase-logs/phase-1/ios-research-swiftui-searchable-debounce.md` for debouncing

## Risks
- **Race condition:** Multiple search tasks in flight
  - Mitigation: Cancel previous task before starting new one
- **FTS5 query spam:** User types fast, queries on every char
  - Mitigation: 300ms debounce + task cancellation
- **UI lag:** Search takes >200ms
  - Mitigation: Show loading indicator, async query
- **Empty state:** No feedback when query has no results
  - Mitigation: "No stops found" message

## Validation
```bash
# Open Xcode
open SydneyTransit/SydneyTransit.xcodeproj

# Run in simulator (Cmd+R)

# Test search flow:
1. Launch app → HomeView appears
2. Tap "Search Stops" → SearchView appears
3. Tap search field → Keyboard appears
4. Type "cir" → Wait 300ms → Results appear
5. Continue typing "circular" → Results update (single query after 300ms idle)
6. Verify results contain "Circular Quay" stops
7. Tap stop → StopDetailsView appears (Checkpoint 10)

# Performance check (Xcode Console):
# search_complete: query="circular", result_count=5, duration_ms=120
# Expected: <200ms query time

# Edge cases:
1. Type "xyz123nonexistent" → "No stops found" message
2. Clear search → Results disappear
3. Type rapidly "abcdefgh" → Only 1 query fires (debounced)

# No errors in console
```

## References for Subagent
- Exploration report: `critical_patterns` → "iOS Logger wrapper"
- Standards: DEVELOPMENT_STANDARDS.md:Section 3.2.3 (iOS view patterns)
- Architecture: IOS_APP_SPECIFICATION.md:Section 5.2 (search UI)
- iOS research: `.phase-logs/phase-1/ios-research-swiftui-searchable-debounce.md` (debouncing pattern)
- iOS research: `.phase-logs/phase-1/ios-research-grdb-fts5-match.md` (FTS5 performance)
- Existing models: Checkpoint 8 (Stop.search() method)
- Existing logger: SydneyTransit/Core/Utilities/Logger.swift
- HomeView: SydneyTransit/Features/Home/HomeView.swift (Phase 0)

## Estimated Complexity
**moderate** - SwiftUI .searchable straightforward, but debouncing pattern requires careful Task management (cancel previous, async/await, main thread updates)
