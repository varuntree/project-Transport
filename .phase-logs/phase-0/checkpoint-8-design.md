# Checkpoint 8: iOS Configuration

## Goal
Config.plist for secrets, Constants.swift to read it, expose API_BASE_URL and Supabase credentials.

## Approach

### Backend Implementation
None

### iOS Implementation

**File 1: Create `SydneyTransit/Config-Example.plist` (template, commit to git):**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>API_BASE_URL</key>
    <string>http://localhost:8000/api/v1</string>
    <key>SUPABASE_URL</key>
    <string>https://xxxxx.supabase.co</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>your_anon_key_here</string>
    <key>LOG_LEVEL</key>
    <string>info</string>
</dict>
</plist>
```

**File 2: Create `SydneyTransit/Core/Utilities/Constants.swift`:**

```swift
import Foundation

enum Config {
    private static let config: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("Config.plist not found. Copy Config-Example.plist to Config.plist and fill in your values.")
        }
        return dict
    }()

    static var apiBaseURL: String {
        guard let url = config["API_BASE_URL"] as? String else {
            fatalError("API_BASE_URL not found in Config.plist")
        }
        return url
    }

    static var supabaseURL: String {
        guard let url = config["SUPABASE_URL"] as? String else {
            fatalError("SUPABASE_URL not found in Config.plist")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = config["SUPABASE_ANON_KEY"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Config.plist")
        }
        return key
    }

    static var logLevel: String {
        return config["LOG_LEVEL"] as? String ?? "info"
    }
}
```

**Critical pattern:**
- Config.plist contains actual secrets (not committed to git)
- Config-Example.plist is safe template (committed to git)
- Constants.swift reads Config.plist at runtime
- fatalError if Config.plist missing (guides developer to create it)

### iOS Implementation
Create both files as described above.

## Design Constraints
- Config.plist must be in .gitignore (contains secrets)
- Config-Example.plist must be committed (safe template)
- Constants enum (not struct/class) prevents instantiation
- Clear error messages if plist missing or keys missing
- Follow DEVELOPMENT_STANDARDS.md:L966-1009

## Risks
- Developer forgets to create Config.plist → fatalError with helpful message
  - Mitigation: Error says "Copy Config-Example.plist to Config.plist"
- Config.plist committed to git by accident → .gitignore prevents
  - Mitigation: .gitignore added in checkpoint 6

## Validation
```swift
// Add temporary test in SydneyTransitApp.swift init:
print("API Base URL: \(Config.apiBaseURL)")
// Expected: "http://localhost:8000/api/v1" (or user's actual value)

// If Config.plist missing:
// Expected: fatalError with message "Config.plist not found. Copy Config-Example.plist..."
```

## References for Subagent
- Pattern: DEVELOPMENT_STANDARDS.md:L966-1009
- iOS Config: IOS_APP_SPECIFICATION.md:Section 4

## Estimated Complexity
**simple** - Plist creation + Swift property reading
