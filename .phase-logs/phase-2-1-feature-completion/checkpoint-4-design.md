# Checkpoint 4: Route List Modality Filter

## Goal
Route list has segmented control (All/Train/Bus/Metro/Ferry/Tram) at top, selecting mode filters routes to show only that type.

## Approach

### Backend Implementation
None - iOS-only feature.

### iOS Implementation

**Step 1: Add filter state to RouteListView**
- Add `@State private var selectedMode: RouteType? = nil` property
- nil represents "All" mode (show all routes)
- Non-nil filters to specific RouteType (train/bus/metro/ferry/tram)

**Step 2: Add segmented Picker above List**
- Create Picker with selection binding to `$selectedMode`:
  ```swift
  Picker("Transport Mode", selection: $selectedMode) {
      Text("All").tag(RouteType?.none)
      ForEach(RouteType.allCases) { type in
          Text(type.displayName).tag(type as RouteType?)
      }
  }
  .pickerStyle(.segmented)
  .padding(.horizontal)
  ```
- Ensure RouteType conforms to CaseIterable (likely already does)
- Add displayName computed property to RouteType if missing (0→"Tram", 1→"Metro", 2→"Train", 3→"Bus", 4→"Ferry")

**Step 3: Filter routes before display**
- Before grouping/sorting routes, apply filter:
  ```swift
  let filteredRoutes = selectedMode == nil
      ? routes
      : routes.filter { $0.type == selectedMode }
  ```
- Then group/sort filteredRoutes as before

**Step 4: Update section logic**
- If selectedMode != nil, show single modality (no need for type-based sections)
- If selectedMode == nil, show all routes grouped by type (existing behavior)
- Simplify section headers when filtered

**Files to create:**
None

**Files to modify:**
- `SydneyTransit/Features/Routes/RouteListView.swift`:
  - Add @State var selectedMode
  - Add Picker above List
  - Filter routes based on selectedMode before grouping
  - Adjust section headers for filtered view
- `SydneyTransit/Data/Models/Route.swift` (if needed):
  - Add displayName computed property to RouteType enum if missing

## Design Constraints
- Segmented control for 6 options per iOS HIG (ios-research-picker-vs-segmented.md)
- RouteType enum must conform to CaseIterable + Identifiable for ForEach
- Maintain scroll position when switching modes (SwiftUI List handles automatically)
- Picker should be outside List (not in section header) to remain visible when scrolling
- Follow @State SwiftUI state management pattern (DEVELOPMENT_STANDARDS.md iOS ViewModels)

## Risks
- **RouteType enum missing CaseIterable:** May need to add conformance
  - Mitigation: Check Route.swift, add conformance if missing, simple fix
- **Picker UI too crowded:** 6 segments may be tight on small iPhones (SE)
  - Mitigation: Use abbreviated labels ("All", "Train", "Bus", etc - 1 word max), test on iPhone SE simulator

## Validation
```bash
# Run app in simulator (Cmd+R in Xcode)
# Navigate to Routes tab
# Expect: Segmented control at top with "All | Train | Bus | Metro | Ferry | Tram"
# Tap "Train" → see only T1, T2, T3, T4, T8, T9 routes
# Tap "Bus" → see only bus routes (hundreds, should scroll)
# Tap "All" → see all routes grouped by type (existing behavior)
# Verify scroll position resets when switching modes (acceptable UX)
```

## References for Subagent
- iOS research: `.phase-logs/phase-2-1-feature-completion/ios-research-picker-vs-segmented.md`
- Pattern: @State SwiftUI state management (DEVELOPMENT_STANDARDS.md iOS ViewModels)
- Example: SearchView.swift:5-9 (@State properties pattern)

## Estimated Complexity
Simple - Add Picker + filter logic to existing view. No new files, minimal code.
