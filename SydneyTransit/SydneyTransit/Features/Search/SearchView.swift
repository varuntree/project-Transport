import SwiftUI
import Logging

enum SearchMode: String, CaseIterable {
    case all = "All"
    case train = "Train"
    case bus = "Bus"
    case ferry = "Ferry"
    case lightRail = "Light Rail"
    case metro = "Metro"

    var displayName: String { self.rawValue }

    var routeTypes: [Int]? {
        switch self {
        case .all: return nil
        case .train: return [2]
        case .bus: return [3, 700, 712, 714]
        case .ferry: return [4]
        case .lightRail: return [900]
        case .metro: return [1, 401]
        }
    }
}

struct SearchView: View {
    @State private var selectedMode: SearchMode = .all
    @State private var searchQuery: String = ""
    @State private var searchResults: [Stop] = []
    @State private var isLoading: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Transport Mode", selection: $selectedMode) {
                ForEach(SearchMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            } else if searchQuery.isEmpty {
                Text("Search for stops by name or code")
                    .foregroundColor(.secondary)
                    .font(.body)
            } else if searchResults.isEmpty {
                Text("No stops found for \"\(searchQuery)\"")
                    .foregroundColor(.secondary)
                    .font(.body)
            } else {
                ForEach(searchResults) { stop in
                    NavigationLink {
                        StopDetailsView(stop: stop)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: stop.transportIcon)
                                .foregroundColor(.blue)
                                .imageScale(.medium)
                                .accessibilityLabel("\(stop.routeTypeDisplayName) stop")

                            VStack(alignment: .leading, spacing: 4) {
                                Text(stop.stopName)
                                    .font(.body)
                                    .fontWeight(.medium)

                                if let stopCode = stop.stopCode {
                                    Text("Stop \(stopCode)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // View on Map button
                            NavigationLink {
                                MapView(selectedStop: stop)
                            } label: {
                                Image(systemName: "map")
                                    .foregroundColor(.blue)
                                    .imageScale(.medium)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            }
        }
        .navigationTitle("Search Stops")
        .searchable(text: $searchQuery, prompt: "Stop name or code")
        .onChange(of: searchQuery) { newValue in
            // Cancel previous search task
            searchTask?.cancel()

            // Reset error
            errorMessage = nil

            // Empty query - clear results immediately
            guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                searchResults = []
                isLoading = false
                return
            }

            // Start new debounced search (300ms delay)
            isLoading = true
            searchTask = Task {
                // Debounce delay
                do {
                    try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                } catch {
                    // Task cancelled
                    return
                }

                // Check if task was cancelled during sleep
                guard !Task.isCancelled else {
                    return
                }

                // Perform search
                await performSearch(query: newValue)
            }
        }
        .onChange(of: selectedMode) { newMode in
            // Cancel existing search task
            searchTask?.cancel()

            // Trigger search with debounce if query not empty
            if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    guard !Task.isCancelled else { return }
                    await performSearch(query: searchQuery)
                }
            }
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        let startTime = Date()

        do {
            let results = try DatabaseManager.shared.read { db in
                try Stop.search(db, query: query)
            }

            let duration = Date().timeIntervalSince(startTime) * 1000 // ms

            Logger.database.info(
                "search_completed",
                metadata: .from([
                    "query": query,
                    "results_count": results.count,
                    "duration_ms": Int(duration)
                ])
            )

            // Log route type distribution for multi-modal coverage validation
            let routeTypeCounts = Dictionary(grouping: results, by: { $0.primaryRouteType })
                .mapValues { $0.count }

            let routeTypeStr = routeTypeCounts
                .map { "\($0.key.map(String.init) ?? "nil"):\($0.value)" }
                .sorted()
                .joined(separator: ",")

            Logger.database.info(
                "search_results_ios",
                metadata: .from([
                    "query": query,
                    "total": results.count,
                    "route_types": routeTypeStr
                ])
            )

            searchResults = results
            isLoading = false

        } catch {
            Logger.database.error(
                "search_failed",
                metadata: .from([
                    "query": query,
                    "error": error.localizedDescription
                ])
            )

            errorMessage = "Search failed: \(error.localizedDescription)"
            searchResults = []
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
