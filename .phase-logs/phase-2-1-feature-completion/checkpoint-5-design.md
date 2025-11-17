# Checkpoint 5: Alphabetical Index Navigation

## Goal
Route list shows A-Z index on right side (iOS Contacts-style), tapping letter scrolls to routes starting with that letter.

## Approach

### Backend Implementation
None - iOS-only feature.

### iOS Implementation

**Step 1: Group routes alphabetically**
- After filtering (from Checkpoint 4), sort routes by displayName:
  ```swift
  let sortedRoutes = filteredRoutes.sorted { $0.displayName < $1.displayName }
  ```
- Group by first letter:
  ```swift
  let alphabeticalSections = Dictionary(grouping: sortedRoutes) { route in
      String(route.displayName.prefix(1).uppercased())
  }
  ```
- Result: `["T": [T1, T2, T3], "M": [M10, M20], ...]`

**Step 2: Update List to use alphabetical sections**
- Replace current List structure with:
  ```swift
  List {
      ForEach(alphabeticalSections.keys.sorted(), id: \.self) { letter in
          Section {
              ForEach(alphabeticalSections[letter]!) { route in
                  NavigationLink(value: route) {
                      RouteRow(route: route)
                  }
              }
          } header: {
              Text(letter)
                  .font(.headline)
                  .sectionIndexLabel(letter)  // iOS 26+ API
          }
      }
  }
  .listSectionIndexVisibility(.automatic)
  ```

**Step 3: Handle iOS version compatibility**
- `.listSectionIndexVisibility()` and `.sectionIndexLabel()` are iOS 26+ APIs (per ios-research-list-section-index.md)
- Wrap in `if #available(iOS 26, *)` or use unconditionally if target is iOS 26+
- Fallback for iOS <26: Show sections without index (graceful degradation)

**Step 4: Handle edge cases**
- Routes starting with numbers (e.g., "190 Bus"): Group under "#" section
- Empty sections: Skip (won't occur if routes exist)
- Single-letter routes: May have section with 1 item (acceptable)

**Files to create:**
None

**Files to modify:**
- `SydneyTransit/Features/Routes/RouteListView.swift`:
  - Replace type-based grouping with alphabetical grouping
  - Update List to use ForEach over alphabeticalSections
  - Add `.listSectionIndexVisibility()` modifier
  - Add `.sectionIndexLabel()` to section headers

## Design Constraints
- iOS 26+ API per ios-research-list-section-index.md
- Section headers must be single-letter strings ("A", "B", ..., "Z", "#")
- Sort routes alphabetically BEFORE grouping by first letter
- Index shows on trailing edge automatically (no custom layout needed)
- Follow SwiftUI List sections pattern (IOS_APP_SPECIFICATION.md Section 5)

## Risks
- **iOS version compatibility:** iOS 26 released 2024, may need fallback for older devices
  - Mitigation: Graceful degradation - sections work without index on iOS <26, core functionality intact
- **Mixed alphanumeric route names:** Some routes may start with numbers ("190"), others with letters ("T1")
  - Mitigation: Group numeric routes under "#" section, sort before "A"
- **Many sections:** 26 letters + "#" = 27 potential sections, may be sparse
  - Mitigation: Only create sections for letters that exist in filtered routes (Dictionary grouping handles automatically)

## Validation
```bash
# Run app on iOS 26+ simulator (iPhone 15 Pro with latest iOS)
# Navigate to Routes tab → select "Train" from segmented control
# Expect: A-Z index on right edge (vertical strip with letters)
# Tap "T" in index → scroll to T1/T2/T3 section
# Tap "M" → scroll to M routes (if any exist for Train mode)
# Switch to "Bus" mode → see index update with relevant letters (1-9, #)
# Test on iOS <26 simulator (if available) → sections visible, no index (graceful degradation)
```

## References for Subagent
- iOS research: `.phase-logs/phase-2-1-feature-completion/ios-research-list-section-index.md` (critical - contains iOS 26+ API usage)
- Pattern: SwiftUI List sections (IOS_APP_SPECIFICATION.md Section 5)
- Example: SearchView.swift:12-50 (List with ForEach pattern)

## Estimated Complexity
Simple - Reorganize existing List with alphabetical grouping + add iOS 26 modifiers. No new files, ~20 lines code.
