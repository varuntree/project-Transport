# Checkpoint 9: iOS Logger

## Goal
swift-log Logger configured, logs to Xcode console with structured metadata.

## Approach

### Backend Implementation
None

### iOS Implementation

Create `SydneyTransit/Core/Utilities/Logger.swift`:

```swift
import Logging

extension Logger {
    /// App-wide logger instance
    static let app = Logger(label: "com.sydneytransit.app")

    /// Networking logger instance
    static let network = Logger(label: "com.sydneytransit.network")

    /// Database logger instance
    static let database = Logger(label: "com.sydneytransit.database")
}
```

**Usage pattern:**
```swift
// In SydneyTransitApp.swift or views:
Logger.app.info("App launched")
Logger.network.info("API request completed", metadata: [
    "endpoint": "/stops/200060",
    "duration_ms": "120"
])
```

**Critical pattern:**
- Use reverse-DNS labels: `com.sydneytransit.<module>`
- Never log PII: email, name, tokens
- Use metadata dictionary for structured data

### iOS Implementation
Create Logger.swift as described above.

## Design Constraints
- Use swift-log Logger (not os.Logger or print())
- Label format: reverse-DNS com.sydneytransit.<module>
- Follow DEVELOPMENT_STANDARDS.md:L600-619
- Logs appear in Xcode console (not system log)

## Risks
- Logs too verbose in production → Use LOG_LEVEL from Config.plist
  - Mitigation: Defer production log level tuning to Phase 7
- Accidentally log secrets → Never log full request bodies or tokens
  - Mitigation: Code review pattern in DEVELOPMENT_STANDARDS

## Validation
```swift
// In SydneyTransitApp.swift init:
Logger.app.info("App launched")

// Run in simulator (Cmd+R)
// Expected Xcode console output:
// 2025-11-13T10:30:45+1100 info: App launched [com.sydneytransit.app]
```

## References for Subagent
- Pattern: DEVELOPMENT_STANDARDS.md:L600-619
- swift-log docs: https://github.com/apple/swift-log

## Estimated Complexity
**simple** - Logger extension, no complex logic
