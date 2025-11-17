# Checkpoint 3: Fix Missing Route Modalities

## Goal
Route list shows all 7 modalities (4687 routes total): Train, Metro, Bus, School Bus, Regional Bus, Ferry, Light Rail.

## Approach

### Backend Implementation
None (API returns all 4687 routes correctly, verified in exploration)

### iOS Implementation

#### 1. Edit `SydneyTransit/Data/Models/Route.swift`

**Add enum cases (line ~56-58):**
```swift
case metro = 401
case regularBus = 700
case schoolBus = 712
case regionalBus = 714
case lightRail = 900
```

**Update displayName switch (line ~60-70):**
```swift
case .metro: return "Metro"
case .regularBus: return "Bus"
case .schoolBus: return "School Bus"
case .regionalBus: return "Regional Bus"
case .lightRail: return "Light Rail"
```

**Update color switch (line ~72-82):**
```swift
case .metro: return .purple
case .regularBus: return .blue
case .schoolBus: return .orange
case .regionalBus: return .green
case .lightRail: return .red
```

#### 2. Edit `SydneyTransit/Features/Routes/RouteListView.swift`

**Update priority array (line 86-88 in visibleRouteTypes() function):**
```swift
let priority: [RouteType] = [.rail, .metro, .regularBus, .schoolBus, .regionalBus, .ferry, .lightRail]
```

## Design Constraints
- Follow GTFS Extended Route Types spec:
  - 401: Metro (rail variant)
  - 700: Bus (standard)
  - 712: School Bus (bus variant)
  - 714: Regional Bus (bus variant)
  - 900: Tram/Light Rail
- Maintain alphabetical index navigation (already handles dynamic types)
- Color palette from IOS_APP_SPECIFICATION.md brand colors
- Expected route counts (from Supabase verification):
  - Rail (type 2): 99 routes
  - Ferry (type 4): 11 routes
  - Metro (type 401): 1 route
  - Regular Bus (type 700): 679 routes
  - School Bus (type 712): 3866 routes
  - Regional Bus (type 714): 30 routes
  - Light Rail (type 900): 1 route

## Risks
- Enum rawValue conflict
  - Mitigation: Extended GTFS types are distinct from standard 0-7 types
- Color palette clash
  - Mitigation: Use iOS system colors (purple, blue, orange, green, red)
- Priority array order affecting UI
  - Mitigation: Alphabetical index navigation is independent of priority array

## Validation
```
1. Run iOS app in Xcode simulator (Cmd+R)
2. Home → All Routes
3. Verify segmented control shows 7 tabs: Train, Metro, Bus, School Bus, Regional Bus, Ferry, Light Rail
4. Switch to Metro → shows 1 route
5. Switch to Bus → shows ~679 routes
6. Switch to School Bus → shows ~3866 routes
7. Switch to Regional Bus → shows ~30 routes
8. Switch to Light Rail → shows 1 route
9. Verify alphabetical index (A-Z) works for all modalities
10. Test search filter within each modality
```

## References for Subagent
- Exploration report: `affected_systems[2]` → Route modality filtering
- Exploration report: `data_verification.supabase_routes` → Route type distribution
- Standards: DATA_ARCHITECTURE.md → GTFS schema
- File locations:
  - SydneyTransit/Data/Models/Route.swift:49-87
  - SydneyTransit/Features/Routes/RouteListView.swift:86-88
- GTFS spec: Extended Route Types (Google Transit spec)

## Estimated Complexity
Medium - 5 enum cases + 10 switch cases + 1 array update, 20 min implementation + 10 min validation
