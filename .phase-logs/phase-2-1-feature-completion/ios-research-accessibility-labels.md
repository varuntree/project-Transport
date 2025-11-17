# iOS Research: Accessibility Labels for SF Symbol Icons

## Key Pattern
VoiceOver doesn't auto-describe SF Symbols. Use `.accessibilityLabel()` to provide descriptive text ("Train stop", "Ferry departure") and `.accessibilityHint()` for additional context if needed. Standard UIKit controls (Text, Button) are accessible by default.

## Code Example
```swift
import SwiftUI

// Example 1: Stop search icon with accessibility
HStack(spacing: 12) {
    Image(systemName: stop.transportIcon)
        .foregroundColor(.blue)
        .accessibilityLabel("\(stop.routeTypeDescription) stop")
        // VoiceOver reads: "Train stop" instead of just image

    VStack(alignment: .leading) {
        Text(stop.name) // Auto-accessible (reads text)
        Text(stop.code).font(.caption)
    }
}

// Example 2: Button with icon and label (compound)
Button {
    showDepartures()
} label: {
    Label("View Departures", systemImage: "clock")
}
.accessibilityLabel("View real-time departures")
.accessibilityHint("Opens list of upcoming trains")

// Example 3: Grouping elements for clear context
VStack {
    Image(systemName: "ferry.fill")
    Text("Circular Quay")
    Text("Wharf 5")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Ferry stop Circular Quay, Wharf 5")

// Example 4: Dynamic labels for state changes
Image(systemName: departure.wheelchairAccessible ? "figure.roll" : "figure.walk")
    .accessibilityLabel(departure.wheelchairAccessible
        ? "Wheelchair accessible"
        : "Not wheelchair accessible")
```

## Critical Constraints
- **Short and informative**: Label should be 1-3 words describing purpose, not verbose instructions
- **No redundancy**: If text already exists (Button with Text), don't duplicate in label
- **Hints are optional**: Only add `.accessibilityHint()` if label doesn't provide enough context
- **Test with VoiceOver**: Enable Settings > Accessibility > VoiceOver to verify actual behavior

## Common Gotchas
- **Label vs Hint confusion**: Label = what it is ("Play button"), Hint = what it does ("Starts playback")
- **Over-describing**: Avoid "Image of a train" → just "Train stop" (VoiceOver announces "Image" automatically)
- **Forgetting dynamic state**: If icon changes (play/pause), label must update too
- **Grouping issues**: Use `.accessibilityElement(children: .combine)` to merge related elements, or VoiceOver reads separately

## API Reference
- Apple docs: https://developer.apple.com/documentation/uikit/supporting-voiceover-in-your-app
- HIG: https://developer.apple.com/design/human-interface-guidelines/voiceover
- Related APIs: `.accessibilityHint()`, `.accessibilityElement()`, `UIAccessibility`

## Relevance to Plan
Used in Checkpoint 1 "Stop Search Icon Enhancement" (transport mode icons need labels like "Train stop", "Bus stop"). Also Checkpoint 2 "Real Departures Integration" (wheelchair icons, platform info must be VoiceOver-readable).
