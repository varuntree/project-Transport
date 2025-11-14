# Checkpoint 8: iOS Departures View (Countdown UI)

## Goal
SwiftUI view with List, DepartureRow, auto-refresh on appear. Countdown updates, delay badges orange, pull-to-refresh works.

## Approach

### iOS Implementation
- Create `SydneyTransit/Features/Departures/DeparturesView.swift`
- View definition:
  ```swift
  import SwiftUI

  struct DeparturesView: View {
      let stop: Stop
      @StateObject private var viewModel = DeparturesViewModel()

      var body: some View {
          List {
              if viewModel.isLoading && viewModel.departures.isEmpty {
                  ProgressView("Loading departures...")
                      .frame(maxWidth: .infinity, alignment: .center)
              } else if let errorMessage = viewModel.errorMessage {
                  Text(errorMessage)
                      .foregroundColor(.red)
                      .frame(maxWidth: .infinity, alignment: .center)
              } else {
                  ForEach(viewModel.departures) { departure in
                      DepartureRow(departure: departure)
                  }
              }
          }
          .navigationTitle("Departures")
          .refreshable {
              await viewModel.loadDepartures(stopId: stop.sid)
          }
          .onAppear {
              Task {
                  await viewModel.loadDepartures(stopId: stop.sid)
              }
              viewModel.startAutoRefresh(stopId: stop.sid)
          }
          .onDisappear {
              viewModel.stopAutoRefresh()
          }
      }
  }

  struct DepartureRow: View {
      let departure: Departure

      var body: some View {
          HStack(spacing: 12) {
              // Route badge (blue circle with route number)
              Text(departure.routeShortName)
                  .font(.headline)
                  .foregroundColor(.white)
                  .frame(width: 44, height: 44)
                  .background(Color.blue)
                  .clipShape(Circle())

              // Headsign + delay text
              VStack(alignment: .leading, spacing: 4) {
                  Text(departure.headsign)
                      .font(.body)
                      .lineLimit(1)

                  if let delayText = departure.delayText {
                      Text(delayText)
                          .font(.caption)
                          .foregroundColor(.white)
                          .padding(.horizontal, 8)
                          .padding(.vertical, 2)
                          .background(Color.orange)
                          .cornerRadius(4)
                  }
              }

              Spacer()

              // Countdown + departure time
              VStack(alignment: .trailing, spacing: 4) {
                  Text("\(departure.minutesUntil) min")
                      .font(.headline)
                      .foregroundColor(.primary)

                  Text(departure.departureTime)
                      .font(.caption)
                      .foregroundColor(.secondary)
              }
          }
          .padding(.vertical, 4)
      }
  }
  ```

### Critical Pattern
- **SwiftUI List auto-diff:** List diffs by Identifiable.id (Departure.tripId), no manual optimization needed
- **Countdown updates on refresh:** minutesUntil is computed property, recalculates automatically on each render
- **Timer lifecycle:** startAutoRefresh() in .onAppear, stopAutoRefresh() in .onDisappear
- **.refreshable:** Pull-to-refresh triggers async loadDepartures, shows loading indicator automatically

## Design Constraints
- Follow IOS_APP_SPECIFICATION.md:Section 5.1 for SwiftUI views
- SwiftUI List auto-diffs by Identifiable.id—no manual optimization needed (from ios-research-list-refresh-optimization.md)
- Delay badge orange if `delay_s > 0`, no badge if delay_s == 0
- Countdown updates on refresh (minutesUntil is computed property, recalculates automatically)
- Must call stopAutoRefresh() in .onDisappear to prevent memory leak

## Risks
- Timer not stopped → memory leak, battery drain
  - Mitigation: Always call stopAutoRefresh() in .onDisappear
- Countdown not updating → user confused
  - Mitigation: minutesUntil is computed property, recalculates on each refresh (every 30s)
- List performance slow (>100 items) → UI lag
  - Mitigation: API returns limit=10, List handles small datasets efficiently

## Validation
```bash
# Xcode simulator (Cmd+R)
# Manual test:
# 1. Tap stop → 'View Departures' → list shows
# 2. Countdown shows '5 min' (or similar)
# 3. Wait 30s → list auto-refreshes, countdown updates to '4 min'
# 4. Delay badges show orange '+2 min' when delay_s > 0
# 5. Pull down → loading indicator → refresh completes
# 6. Back navigation → Timer stops (no memory leak, verify with Xcode Instruments)

# Expected logs (if added debug prints):
# Timer fired (every 30s while view visible)
# Timer stopped (when navigating away)
```

## References for Subagent
- iOS Research: `.phase-logs/phase-2/ios-research-list-refresh-optimization.md` (List performance)
- iOS Research: `.phase-logs/phase-2/ios-research-timer-scheduling.md` (Timer lifecycle)
- Pattern: SwiftUI .refreshable (PHASE_2_REALTIME.md:L681-684)
- Architecture: IOS_APP_SPECIFICATION.md:Section 5.1
- Standards: DEVELOPMENT_STANDARDS.md:iOS section (SwiftUI views)

## Estimated Complexity
**moderate** - SwiftUI List, DepartureRow custom view, timer lifecycle, refreshable modifier
