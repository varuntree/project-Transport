# iOS Research: SwiftUI List Item Refresh Without Full Reload

## Key Pattern
SwiftUI List optimizes updates automatically using `Identifiable` conformance and structural identity. Updating @Published array triggers differential update (not full reload). Avoid expensive computations in view body - use computed properties on model or @State for derived data.

## Code Example
```swift
import SwiftUI

struct Departure: Identifiable, Codable {
    let trip_id: String
    let realtime_time_secs: Int
    var id: String { trip_id }

    // Computed property - recalculated on each render (cheap)
    var minutesUntil: Int {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowSecs = (now.hour ?? 0) * 3600 + (now.minute ?? 0) * 60
        return max(0, (realtime_time_secs - nowSecs) / 60)
    }
}

@MainActor
class DeparturesViewModel: ObservableObject {
    @Published var departures: [Departure] = []

    func loadDepartures() async {
        // Fetch new data, SwiftUI diffs by id
        departures = try await repository.fetchDepartures(stopId: stopId)
    }
}

struct DeparturesView: View {
    @StateObject var viewModel: DeparturesViewModel

    var body: some View {
        List {
            ForEach(viewModel.departures) { departure in
                DepartureRow(departure: departure)
            }
        }
        .refreshable { await viewModel.loadDepartures() }
    }
}
```

## Critical Constraints
- Model must conform to `Identifiable` (stable `id` property required)
- Avoid storing closures in views - captures state, causes excess updates
- Keep view body fast (<16ms target) - move business logic to model layer
- SwiftUI recreates views frequently - expensive init/body work kills performance

## Common Gotchas
- **Full reload**: Changing array reference (departures = newArray) triggers diff, but changing id values forces full recreation
- **Excess updates**: Observable object with many properties updates view when *any* property changes (migrate to @Observable macro for fine-grained tracking)
- **Slow computed properties**: Complex calculations in body run on every render - cache results or use @State
- **Closure capture**: Storing closures that capture `self` causes updates when unrelated properties change

## API Reference
- Apple docs: https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance
- Related APIs: Identifiable, ForEach, @Published, @Observable macro

## Relevance to Phase 2
Checkpoint 8 (DeparturesView): List refreshes every 30s, but only changed items re-render (SwiftUI diffs by trip_id). `minutesUntil` computed property recalculates on each update (cheap math). No manual optimization needed - Identifiable conformance handles diffing.
