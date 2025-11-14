# Checkpoint 7: iOS Departures ViewModel (Auto-Refresh)

## Goal
ViewModel with Timer-based 30s refresh, loading/error states. iOS compiles, Timer fires on main thread.

## Approach

### iOS Implementation
- Create `SydneyTransit/Features/Departures/DeparturesViewModel.swift`
- ViewModel definition:
  ```swift
  import Foundation

  @MainActor
  class DeparturesViewModel: ObservableObject {
      @Published var departures: [Departure] = []
      @Published var isLoading = false
      @Published var errorMessage: String?

      private let repository: DeparturesRepository
      private var refreshTimer: Timer?

      init(repository: DeparturesRepository = DeparturesRepositoryImpl()) {
          self.repository = repository
      }

      func loadDepartures(stopId: String) async {
          isLoading = true
          errorMessage = nil

          do {
              departures = try await repository.fetchDepartures(stopId: stopId)
          } catch let error as URLError where error.code == .notConnectedToInternet {
              errorMessage = "No internet connection"
          } catch {
              errorMessage = "Failed to load departures"
          }

          isLoading = false
      }

      func startAutoRefresh(stopId: String) {
          // Invalidate existing timer
          refreshTimer?.invalidate()

          // Schedule new timer (30s interval)
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

### Critical Pattern
- **@MainActor:** Ensures Timer.scheduledTimer fires on main RunLoop (no manual RunLoop.main.add() needed)
- **[weak self]:** Prevents retain cycle (Timer holds strong reference to closure until invalidated)
- **Timer.invalidate():** Must call in stopAutoRefresh() to prevent memory leak
- **Task { await ... }:** Timer closure is sync, wrap async loadDepartures in Task

## Design Constraints
- Follow IOS_APP_SPECIFICATION.md:Section 5.2 for ViewModel pattern
- @MainActor ensures Timer.scheduledTimer fires on main RunLoop (from ios-research-timer-scheduling.md)
- Must invalidate timer on disappear to prevent memory leak
- Handle errors gracefully: URLError.notConnectedToInternet → "No internet connection"
- No Combine needed (Timer is Foundation, not Combine.Timer.publish)

## Risks
- Memory leak if timer not invalidated → app crashes after navigating away multiple times
  - Mitigation: Always call stopAutoRefresh() in view's .onDisappear
- Retain cycle if strong self capture → view never deallocates
  - Mitigation: Use [weak self] in timer closure
- Timer continues firing after view dismissed → unnecessary network calls
  - Mitigation: Invalidate timer in stopAutoRefresh(), call from .onDisappear

## Validation
```bash
# Xcode build
# Cmd+B to build
# Expected: ViewModel compiles, Timer import Foundation, no Combine needed

# Manual test (Checkpoint 8): Timer fires every 30s, isLoading toggles
# Add print("Timer fired") in timer closure, verify console output every 30s
# Navigate away from view, verify timer stops (no more prints)
```

## References for Subagent
- iOS Research: `.phase-logs/phase-2/ios-research-timer-scheduling.md` (Timer pattern)
- Pattern: ViewModel (@MainActor, @Published) (IOS_APP_SPECIFICATION.md:Section 5.2)
- Architecture: PHASE_2_REALTIME.md:L633-645
- Standards: DEVELOPMENT_STANDARDS.md:iOS section (ViewModel patterns)

## Estimated Complexity
**moderate** - Timer lifecycle management, async/await in timer closure, error handling, memory safety
