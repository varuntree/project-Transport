# iOS Research: Timer.scheduledTimer Main Thread Scheduling

## Key Pattern
`Timer.scheduledTimer` automatically schedules on current thread's RunLoop (main thread when called from `@MainActor`). @MainActor annotation ensures timer fires on main thread, no additional RunLoop configuration needed for simple timers.

## Code Example
```swift
import Foundation

@MainActor
class DeparturesViewModel: ObservableObject {
    private var refreshTimer: Timer?

    func startAutoRefresh(stopId: String) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.loadDepartures(stopId: stopId)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
```

## Critical Constraints
- Timer scheduled on current thread's RunLoop (main RunLoop when called from @MainActor context)
- Must call `invalidate()` before deallocation to prevent memory leaks
- Timer holds strong reference to target/closure until invalidated
- Minimum interval: 0.0001s (system enforces non-negative values)

## Common Gotchas
- **Memory leak**: Forgetting `invalidate()` in deinit/onDisappear - timer keeps firing after view dismissed
- **Retain cycle**: Strong `self` capture in closure - use `[weak self]` or `[unowned self]`
- **Wrong thread**: Calling from background thread schedules on background RunLoop (won't fire if thread exits)
- **SwiftUI lifecycle**: Timer continues firing after view removed from hierarchy - must invalidate in `.onDisappear`

## API Reference
- Apple docs: https://developer.apple.com/documentation/foundation/timer/scheduledtimer(timeinterval:invocation:repeats:)
- Related APIs: RunLoop.current, RunLoop.main, Timer.publish (Combine alternative)

## Relevance to Phase 2
Checkpoint 7 (DeparturesViewModel): Auto-refresh every 30s requires timer scheduled on main thread. @MainActor sufficient - no manual RunLoop.main.add() needed. Timer.invalidate() in stopAutoRefresh() prevents leak when user navigates away from DeparturesView.
