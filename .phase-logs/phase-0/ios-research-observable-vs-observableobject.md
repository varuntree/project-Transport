# iOS Research: @Observable vs ObservableObject

## Key Pattern
iOS 17+ introduces `@Observable` macro (Observation framework) replacing Combine's `ObservableObject`. Key difference: `@Observable` tracks granular property reads in view bodies (better performance), doesn't require `@Published` wrapper. iOS 16 requires `ObservableObject` fallback with `@StateObject`/`@EnvironmentObject`.

## Code Example
```swift
// iOS 17+ (@Observable)
import Observation

@Observable
class DeparturesViewModel {
    var departures: [Departure] = []
    var isLoading = false
    var errorMessage: String?

    // No @Published needed, all properties auto-tracked
    // Use @ObservationIgnored for non-tracked properties
}

// Usage in SwiftUI
struct DeparturesView: View {
    @State private var viewModel = DeparturesViewModel()

    var body: some View {
        List(viewModel.departures) { /* ... */ }
            .environment(viewModel) // Use .environment(), not .environmentObject()
    }
}

// iOS 16 Fallback (ObservableObject)
import Combine

class DeparturesViewModel: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Must use @Published for tracked properties
}

// Usage in SwiftUI (iOS 16)
struct DeparturesView: View {
    @StateObject private var viewModel = DeparturesViewModel()

    var body: some View {
        List(viewModel.departures) { /* ... */ }
            .environmentObject(viewModel) // Use .environmentObject()
    }
}
```

## Critical Constraints
- **@Observable requires iOS 17+**: Must use `ObservableObject` for iOS 16 minimum deployment target
- **Property wrapper changes**: `@StateObject` → `@State`, `@EnvironmentObject` → `@Environment`, `@ObservedObject` → `@Bindable`
- **Incremental migration OK**: Can mix `@Observable` and `ObservableObject` types in same app during transition
- **Granular tracking**: `@Observable` only updates views when body reads changed property; `ObservableObject` updates on ANY `@Published` property change

## Common Gotchas
- **Don't mix property wrappers**: Using `@StateObject` with `@Observable` type still works (backwards compat) but doesn't leverage performance gains—always use `@State` for `@Observable` types
- **No @Published with @Observable**: Applying `@Published` to `@Observable` properties causes compilation error
- **Binding support**: Use `@Bindable` property wrapper (not `@ObservedObject`) when passing `@Observable` type to views needing bindings (e.g., `TextField`)
- **Class-only constraint**: Both `@Observable` and `ObservableObject` require reference types (classes, not structs)

## API Reference
- Apple docs: https://developer.apple.com/documentation/observation/observable
- Migration guide: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
- Related APIs: `@ObservationIgnored()`, `@Bindable`, `@State`, `@Environment`

## Relevance to Phase 0
Phase 0 targets iOS 16+ (CLAUDE.md specifies iOS 16 minimum). Must use `ObservableObject` pattern with `@Published`/`@StateObject` for ViewModels. Phase 1+ ViewModels (DeparturesViewModel, StopSearchViewModel, etc.) will follow `ObservableObject` pattern until deployment target raised to iOS 17+. Checkpoints 9-10 (iOS Home Screen, Integration Test) will use `@State` for local view state, not ViewModels yet.
