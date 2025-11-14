# Checkpoint 6: iOS Departure Model + Repository

## Goal
Create Departure model with countdown logic, repository protocol. iOS compiles, no errors.

## Approach

### iOS Implementation
- Create `SydneyTransit/Data/Models/Departure.swift`
- Struct definition:
  ```swift
  import Foundation

  struct Departure: Codable, Identifiable {
      let tripId: String
      let routeShortName: String
      let headsign: String
      let scheduledTimeSecs: Int
      let realtimeTimeSecs: Int
      let delayS: Int
      let realtime: Bool

      var id: String { tripId }

      // Computed: minutes until departure (from now)
      var minutesUntil: Int {
          let sydney = TimeZone(identifier: "Australia/Sydney")!
          let now = Date()
          let calendar = Calendar.current
          let midnight = calendar.startOfDay(for: now)
          let secsSinceMidnight = Int(now.timeIntervalSince(midnight))
          let secsRemaining = realtimeTimeSecs - secsSinceMidnight
          return max(0, secsRemaining / 60)
      }

      // Computed: delay text ('+X min' if delayed, nil otherwise)
      var delayText: String? {
          guard delayS > 0 else { return nil }
          let mins = delayS / 60
          return "+\(mins) min"
      }

      // Computed: formatted departure time (HH:mm)
      var departureTime: String {
          let mins = realtimeTimeSecs / 60
          let hours = mins / 60
          let remainingMins = mins % 60
          return String(format: "%02d:%02d", hours, remainingMins)
      }

      enum CodingKeys: String, CodingKey {
          case tripId = "trip_id"
          case routeShortName = "route_short_name"
          case headsign
          case scheduledTimeSecs = "scheduled_time_secs"
          case realtimeTimeSecs = "realtime_time_secs"
          case delayS = "delay_s"
          case realtime
      }
  }
  ```

- Create `SydneyTransit/Data/Repositories/DeparturesRepository.swift`
- Protocol definition:
  ```swift
  import Foundation

  protocol DeparturesRepository {
      func fetchDepartures(stopId: String) async throws -> [Departure]
  }

  class DeparturesRepositoryImpl: DeparturesRepository {
      private let apiClient: APIClient

      init(apiClient: APIClient = .shared) {
          self.apiClient = apiClient
      }

      func fetchDepartures(stopId: String) async throws -> [Departure] {
          struct Response: Codable {
              let data: [Departure]
          }

          let endpoint = APIEndpoint.getDepartures(stopId: stopId)
          let response: Response = try await apiClient.request(endpoint)
          return response.data
      }
  }
  ```

- Update `SydneyTransit/Core/Network/APIClient.swift` (if not already configured):
  - Add URLSessionConfiguration with timeoutIntervalForRequest=8s, timeoutIntervalForResource=15s
  - Add APIEndpoint.getDepartures(stopId: String) case

### Critical Pattern
- **CodingKeys snake_case:** API returns trip_id, iOS uses tripId (snake_case → camelCase mapping)
- **Computed properties:** minutesUntil recalculates on each access (no stored state, always current time)
- **URLSession timeout:** 8s request, 15s resource (align with Celery soft 10s, hard 15s)

## Design Constraints
- Follow IOS_APP_SPECIFICATION.md:Section 5.1 for repository pattern
- Follow DEVELOPMENT_STANDARDS.md:iOS patterns for protocol-based repositories
- URLSession timeout: 8s request, 15s resource (from ios-research-urlsession-timeouts.md)
- API endpoint: `GET /api/v1/stops/{stopId}/departures`
- Sydney timezone for minutesUntil calculation (not device timezone)

## Risks
- Timezone mismatch (device in different timezone) → wrong countdown
  - Mitigation: Explicitly use TimeZone(identifier: "Australia/Sydney"), not TimeZone.current
- minutesUntil negative (departure passed) → display issue
  - Mitigation: Use max(0, ...) to clamp to 0
- APIClient not configured → import error
  - Mitigation: Check if APIClient exists from Phase 1, if not, create minimal version

## Validation
```bash
# Xcode build
open SydneyTransit.xcodeproj
# Cmd+B to build
# Expected: No compilation errors on Departure model, DeparturesRepositoryImpl compiles

# Manual test (Checkpoint 8): Verify minutesUntil updates dynamically
# Print departure.minutesUntil multiple times, should decrease over time
```

## References for Subagent
- iOS Research: `.phase-logs/phase-2/ios-research-urlsession-timeouts.md` (timeout configuration)
- Pattern: Repository protocol (IOS_APP_SPECIFICATION.md:Section 3.2)
- Architecture: INTEGRATION_CONTRACTS.md:L163-228 (API response format)
- Standards: DEVELOPMENT_STANDARDS.md:iOS section (protocol-based repos, snake_case mapping)

## Estimated Complexity
**moderate** - Struct with computed properties, timezone handling, repository protocol, APIClient integration
