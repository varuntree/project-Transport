# iOS Research: Picker vs Segmented Control for Modality Filter

## Key Pattern
Segmented control better for 3-7 mutually exclusive options with short labels (Train/Bus/Ferry). Use `.pickerStyle(.segmented)` for horizontal tabs. Picker with `.menu` style better for long lists or options with descriptions.

## Code Example
```swift
import SwiftUI

struct RouteListView: View {
    enum FilterMode: String, CaseIterable, Identifiable {
        case all = "All"
        case train = "Train"
        case bus = "Bus"
        case metro = "Metro"
        case ferry = "Ferry"
        case tram = "Tram"

        var id: String { rawValue }
    }

    @State private var selectedMode: FilterMode = .all
    let routes: [Route]

    var filteredRoutes: [Route] {
        guard selectedMode != .all else { return routes }
        return routes.filter { $0.type.rawValue == selectedMode.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Option 1: Segmented control (recommended for 3-7 options)
            Picker("Mode", selection: $selectedMode) {
                ForEach(FilterMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Option 2: Menu style (alternative for >7 options)
            // Picker("Mode", selection: $selectedMode) {
            //     ForEach(FilterMode.allCases) { mode in
            //         Text(mode.rawValue).tag(mode)
            //     }
            // }
            // .pickerStyle(.menu)

            List(filteredRoutes) { route in
                RouteRow(route: route)
            }
        }
    }
}
```

## Critical Constraints
- **Segmented: 3-7 segments max**: More segments → hard to parse, use menu style instead
- **Segmented: Short labels only**: Long text truncates, use nouns not phrases ("Train" not "Train Routes")
- **No mixed content**: All segments must be text OR icons, not mix (inconsistent UI)
- **Binding required**: Picker needs `@State` var + `$binding`, changes trigger view update

## Common Gotchas
- **Tags required**: Must use `.tag()` on each picker option, or selection won't update
- **Toolbar conflict**: Avoid segmented control in toolbars (iOS HIG violation), use menu style
- **iPad behavior**: Segmented control may adapt to menu on iPad compact width, test both
- **Selection state**: Changing selection doesn't automatically filter list, must compute `filteredRoutes` from binding

## API Reference
- Apple docs: https://developer.apple.com/documentation/swiftui/segmentedpickerstyle
- HIG: https://developer.apple.com/design/human-interface-guidelines/segmented-controls
- Related APIs: `.pickerStyle(.menu)`, `.pickerStyle(.wheel)`, `Picker` initializers

## Relevance to Plan
Used in Checkpoint 4 "Route List Modality Filter". RouteListView adds segmented control above List for filtering by transport type (Train/Bus/Metro/Ferry/Tram/All). 6 segments fits within recommended limit.
