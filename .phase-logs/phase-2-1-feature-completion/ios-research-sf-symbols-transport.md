# iOS Research: SF Symbols for Transport Modes

## Key Pattern
SF Symbols provides native transport icons (tram.fill, lightrail.fill, train.side.front.car, bus.fill, ferry.fill) that scale with text, support accessibility, and adapt to Dark Mode automatically. Use `Image(systemName:)` with symbol name string.

## Code Example
```swift
import SwiftUI

// Map GTFS route_type to SF Symbol
extension Stop {
    var transportIcon: String {
        switch primaryRouteType {
        case 0: return "tram.fill"           // Tram/Light Rail
        case 1: return "lightrail.fill"      // Metro/Subway
        case 2: return "train.side.front.car" // Rail
        case 3: return "bus.fill"            // Bus
        case 4: return "ferry.fill"          // Ferry
        case 5: return "cablecar.fill"       // Cable Tram
        default: return "mappin.circle.fill" // Generic
        }
    }
}

// Usage in SearchView
HStack(spacing: 12) {
    Image(systemName: stop.transportIcon)
        .foregroundColor(.blue)
        .accessibilityLabel("\(stop.routeTypeDescription) stop")

    VStack(alignment: .leading) {
        Text(stop.name)
        Text(stop.code).font(.caption)
    }
}
```

## Critical Constraints
- **System-provided only**: Cannot customize SF Symbol paths, use as-is or create custom symbol
- **Rendering modes**: Use `.foregroundColor()` for monochrome, `.symbolRenderingMode(.hierarchical)` for depth
- **Availability**: Check symbol exists in target iOS version (use SF Symbols app to verify)
- **Accessibility required**: Always provide `.accessibilityLabel()` for VoiceOver users

## Common Gotchas
- **Symbol name typos**: Wrong name shows empty image (no compile error), test on device
- **Weight/scale mismatch**: Symbols auto-match adjacent text weight/size, override with `.imageScale(.large)` if needed
- **Template vs fill**: `tram` (outline) vs `tram.fill` (solid), use `.fill` for better visibility at small sizes
- **Color not applying**: If using in Button/Label, may need `.renderingMode(.template)` for custom colors

## API Reference
- Apple docs: https://developer.apple.com/design/human-interface-guidelines/sf-symbols
- SF Symbols app: https://developer.apple.com/sf-symbols/ (browse all symbols)
- Related APIs: `Image(systemName:)`, `.symbolRenderingMode()`, `.imageScale()`

## Relevance to Plan
Used in Checkpoint 1 "Stop Search Icon Enhancement". SearchView displays transport mode icon next to stop name (train icon for Central, ferry icon for Circular Quay). Requires computing stop's primary route_type from GRDB.
