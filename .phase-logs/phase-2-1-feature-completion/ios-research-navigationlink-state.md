# iOS Research: NavigationLink with Complex State Passing

## Key Pattern
NavigationLink supports two patterns: 1) `destination` closure (pass views directly), 2) `value` parameter + `.navigationDestination(for:)` (pass data, better for programmatic nav). Complex objects passed as immutable values, destination view fetches additional data via ViewModel.

## Code Example
```swift
import SwiftUI

// Pattern 1: Direct destination (simple, inline)
NavigationLink {
    DeparturesView(stop: stop) // Pass stop object
} label: {
    Label("View Departures", systemImage: "clock")
}

// Pattern 2: Value-based (better for state management)
struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        NavigationLink(value: departure.tripId) {
            HStack {
                Text(departure.headsign)
                Spacer()
                Text(departure.countdownText)
            }
        }
    }
}

// In parent view
NavigationStack {
    List(departures) { departure in
        DepartureRow(departure: departure)
    }
    .navigationDestination(for: String.self) { tripId in
        TripDetailsView(tripId: tripId) // View fetches trip data
    }
}

// TripDetailsView ViewModel pattern
struct TripDetailsView: View {
    let tripId: String
    @StateObject private var viewModel: TripDetailsViewModel

    init(tripId: String) {
        self.tripId = tripId
        _viewModel = StateObject(wrappedValue: TripDetailsViewModel(tripId: tripId))
    }

    var body: some View {
        // ViewModel.loadTrip() called in .onAppear
    }
}
```

## Critical Constraints
- **Value must be Hashable**: For value-based links, type must conform to `Hashable` (String, UUID, Int work)
- **Navigation stack required**: Links only work inside `NavigationStack` or `NavigationSplitView`
- **One destination per type**: `.navigationDestination(for: Type.self)` applies to all values of that type in stack
- **Immutable objects**: Passed objects are value copies, changes in destination don't affect source

## Common Gotchas
- **Multiple destination modifiers**: If multiple `.navigationDestination(for: String.self)`, last one wins (avoid duplicates)
- **StateObject initialization**: Use `_viewModel = StateObject(wrappedValue:)` in init, not `@StateObject var viewModel = ...`
- **Deep linking**: Can programmatically navigate by appending to `NavigationStack(path:)` binding array
- **Back button**: Automatic, pops navigation stack, no custom handling needed unless state restoration required

## API Reference
- Apple docs: https://developer.apple.com/documentation/swiftui/navigationlink
- Related: https://developer.apple.com/documentation/swiftui/bringing-robust-navigation-structure-to-your-swiftui-app
- Related APIs: `NavigationStack`, `.navigationDestination(for:destination:)`, `NavigationPath`

## Relevance to Plan
Used in Checkpoint 2 "Real Departures Integration" (StopDetailsView → DeparturesView) and Checkpoint 3 "Trip Details View" (DepartureRow → TripDetailsView). Passes stop/tripId, destination fetches full data via repository.
