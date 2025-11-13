# Checkpoint 10: iOS Home Screen

## Goal
SwiftUI HomeView displays "Sydney Transit" title, app launches without crashes, logs app startup.

## Approach

### Backend Implementation
None

### iOS Implementation

**File 1: Create `SydneyTransit/Features/Home/HomeView.swift`:**

```swift
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Sydney Transit")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Phase 0: Foundation")
                    .font(.title3)
                    .foregroundColor(.secondary)

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

**File 2: Update `SydneyTransit/SydneyTransitApp.swift`:**

```swift
import SwiftUI
import Logging

@main
struct SydneyTransitApp: App {
    init() {
        // Log app launch
        Logger.app.info("App launched")

        // Verify config loaded
        Logger.app.info("Configuration loaded", metadata: [
            "api_base_url": "\(Config.apiBaseURL)"
        ])
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

**Critical patterns:**
- Use NavigationStack (not deprecated NavigationView)
- iOS 16 compatibility: Use @State for local view state (see iOS research)
- Log app launch in App init
- Keep view simple (no ViewModels yet, Phase 1+)

### iOS Implementation
Create HomeView.swift and update SydneyTransitApp.swift as described.

## Design Constraints
- NavigationStack (iOS 16+ compatible)
- iOS 16 compat: Use ObservableObject for future ViewModels (see `.phase-logs/phase-0/ios-research-observable-vs-observableobject.md`)
- Log app launch with metadata
- No complex logic yet (pure UI foundation)

## Risks
- NavigationStack not available in iOS 16 → IT IS available (iOS 16+)
  - Mitigation: Verified in iOS research
- App crashes on launch → Check Config.plist exists
  - Mitigation: Config validation in checkpoint 8

## Validation
```bash
# In Xcode:
# 1. Select iPhone 15 Pro simulator
# 2. Press Cmd+R (run)
# Expected:
#   - App launches successfully
#   - Displays "Sydney Transit" title
#   - Displays "Phase 0: Foundation" subtitle
#   - Xcode console shows: "App launched" log
```

## References for Subagent
- iOS Research: `.phase-logs/phase-0/ios-research-observable-vs-observableobject.md`
- SwiftUI patterns: DEVELOPMENT_STANDARDS.md:L747-905

## Estimated Complexity
**simple** - Basic SwiftUI view + app setup
