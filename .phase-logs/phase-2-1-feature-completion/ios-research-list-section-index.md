# iOS Research: SwiftUI List Section Index Titles

## Key Pattern
iOS 26+ provides `.listSectionIndexVisibility()` + `.sectionIndexLabel()` for A-Z alphabetical navigation. Displays vertical letter stack on trailing edge, tapping letter scrolls to section. Automatically visible when sections have index labels.

## Code Example
```swift
import SwiftUI

struct RouteListView: View {
    let sections: [RouteSection] // Alphabetically grouped routes

    var body: some View {
        List(sections) { section in
            Section(section.title) {
                ForEach(section.routes) { route in
                    RouteRow(route: route)
                }
            }
            .sectionIndexLabel(section.indexTitle) // "A", "B", "C", etc.
        }
        .listSectionIndexVisibility(.visible)
    }
}

// Data structure
struct RouteSection: Identifiable {
    let id = UUID()
    let title: String      // "Routes starting with A"
    let indexTitle: String // "A" (single letter)
    let routes: [Route]
}
```

## Critical Constraints
- **iOS 26+ only**: Check `@available(iOS 26.0, *)` or use fallback UI for older versions
- **Single-letter index labels**: Each section's `indexTitle` must be single character (A, B, C...), not multi-char strings
- **Automatic visibility**: Index shows by default if any section has `.sectionIndexLabel()`, use `.listSectionIndexVisibility(.automatic)` for default
- **Requires sections**: List must use `Section` containers, not flat array of items

## Common Gotchas
- **WatchOS behavior differs**: On watchOS shows index next to crown scroll indicator, not vertical stack
- **Empty sections**: Can show index labels without visible sections by hiding headers with `.sectionIndexLabel()` + empty content
- **Non-alphabetic use**: Works with any single-char labels (numbers, symbols), not limited to A-Z
- **Index shows only labeled sections**: Sections without `.sectionIndexLabel()` won't appear in index (useful for filtering)

## API Reference
- Apple docs: https://developer.apple.com/documentation/swiftui/view/listsectionindexvisibility(_:)
- Related APIs: `.sectionIndexLabel(_:)`, `Visibility.visible/.automatic/.hidden`

## Relevance to Plan
Used in Checkpoint 5 "Alphabetical Index Navigation" for RouteListView. Routes grouped by first letter (T1, T2 → "T"), displayed with A-Z index on right edge for quick navigation.
