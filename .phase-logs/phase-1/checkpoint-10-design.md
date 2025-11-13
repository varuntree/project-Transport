# Checkpoint 10: iOS Stop Details + Route List

## Goal
Create StopDetailsView (display stop info, mock departures placeholder) + RouteListView (grouped by type with color badges). Update HomeView navigation.

## Approach

### iOS Implementation
- Create two new views: stop details, route list
- Files to create:
  - `SydneyTransit/Features/Stops/StopDetailsView.swift` - Stop details screen
  - `SydneyTransit/Features/Routes/RouteListView.swift` - Route list screen
- Files to modify:
  - `SydneyTransit/Features/Home/HomeView.swift` - Add route list navigation (already has search from Checkpoint 9)
- Critical pattern: SwiftUI grouped lists, color-coded route types, iOS share sheet

### Implementation Details

**StopDetailsView Implementation:**

```swift
// Features/Stops/StopDetailsView.swift
import SwiftUI
import MapKit

struct StopDetailsView: View {
    let stop: Stop

    @State private var region: MKCoordinateRegion

    init(stop: Stop) {
        self.stop = stop

        // Initialize map region
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: stop.stopLat, longitude: stop.stopLon),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        List {
            Section("Stop Information") {
                LabeledContent("Name", value: stop.stopName)

                if let stopCode = stop.stopCode {
                    LabeledContent("Stop Code", value: stopCode)
                }

                LabeledContent("Coordinates", value: coordinatesString)

                if let wheelchair = stop.wheelchairBoarding {
                    LabeledContent("Wheelchair", value: wheelchairAccessibilityString(wheelchair))
                }
            }

            Section("Location") {
                Map(coordinateRegion: $region, annotationItems: [stop]) { stop in
                    MapMarker(coordinate: CLLocationCoordinate2D(latitude: stop.stopLat, longitude: stop.stopLon), tint: .blue)
                }
                .frame(height: 200)
                .cornerRadius(10)
            }

            Section("Departures") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Real-time departures coming in Phase 2")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("For now, this shows static GTFS schedules. Phase 2 adds live GTFS-RT updates.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Stop Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            Logger.app.info("stop_details_viewed", stop_id: stop.sid, stop_name: stop.stopName)
        }
    }

    private var coordinatesString: String {
        String(format: "%.4f, %.4f", stop.stopLat, stop.stopLon)
    }

    private var shareText: String {
        var text = "\\(stop.stopName)\\n"
        if let code = stop.stopCode {
            text += "Stop Code: \\(code)\\n"
        }
        text += "Location: \\(coordinatesString)\\n"
        text += "https://maps.apple.com/?ll=\\(stop.stopLat),\\(stop.stopLon)"
        return text
    }

    private func wheelchairAccessibilityString(_ value: Int) -> String {
        switch value {
        case 1: return "Accessible"
        case 2: return "Not Accessible"
        default: return "Unknown"
        }
    }
}

#Preview {
    NavigationStack {
        StopDetailsView(stop: Stop(
            sid: 1,
            stopCode: "200060",
            stopName: "Circular Quay Station",
            stopLat: -33.8615,
            stopLon: 151.2106,
            wheelchairBoarding: 1
        ))
    }
}
```

**RouteListView Implementation:**

```swift
// Features/Routes/RouteListView.swift
import SwiftUI

struct RouteListView: View {
    @State private var routes: [Route] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading routes...")
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Failed to load routes")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                routesList
            }
        }
        .navigationTitle("Routes")
        .task {
            await loadRoutes()
        }
    }

    private var routesList: some View {
        List {
            ForEach(groupedRoutes.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \\.self) { routeType in
                Section(header: Text(routeType.displayName)) {
                    ForEach(groupedRoutes[routeType] ?? []) { route in
                        RouteRow(route: route)
                    }
                }
            }
        }
    }

    private var groupedRoutes: [RouteType: [Route]] {
        Dictionary(grouping: routes, by: { $0.type })
    }

    private func loadRoutes() async {
        Logger.app.info("route_list_loading")
        isLoading = true

        do {
            let loadedRoutes = try await DatabaseManager.shared.read { db in
                try Route.fetchAll(db)
            }

            await MainActor.run {
                routes = loadedRoutes
                isLoading = false
                Logger.app.info("route_list_loaded", count: loadedRoutes.count)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                Logger.app.error("route_list_load_failed", error: error.localizedDescription)
            }
        }
    }
}

struct RouteRow: View {
    let route: Route

    var body: some View {
        HStack {
            // Route type badge
            route.type.color
                .frame(width: 8)
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(route.routeShortName)
                        .font(.headline)

                    Text(route.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(route.type.color.opacity(0.2))
                        .foregroundColor(route.type.color)
                        .cornerRadius(4)
                }

                Text(route.routeLongName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RouteListView()
    }
}
```

**Fix RouteType Enum (from Checkpoint 8):**

```swift
// Data/Models/Route.swift (update color property)
extension RouteType {
    var color: Color {
        switch self {
        case .rail: return .red
        case .metro: return .purple
        case .bus: return .blue
        case .ferry: return .green
        case .tram: return .orange
        default: return .gray
        }
    }
}
```

**Update HomeView (if not done in Checkpoint 9):**

Already added in Checkpoint 9 - NavigationLink to RouteListView present.

## Design Constraints
- **StopDetailsView receives Stop object:** Not stop_id (avoid extra query)
- **Map annotation:** Use MapKit MapMarker (iOS 16+ simple API)
- **Share sheet:** Use iOS ShareLink (iOS 16+) for native share
- **Route grouping:** Use `Dictionary(grouping:by:)` standard library function
- **Color badges:** Route type colors match DEVELOPMENT_STANDARDS patterns
- **Mock departures:** Clear messaging "Phase 2" (no fake data)
- Follow IOS_APP_SPECIFICATION.md:Section 5.1-5.3 for view structure
- Follow DEVELOPMENT_STANDARDS.md:Section 3.2.3 for SwiftUI patterns

## Risks
- **Map rendering slow:** Large map tile downloads
  - Mitigation: Small span (0.01° ≈ 1km), single annotation
- **Routes list OOM:** Loading 800+ routes at once
  - Mitigation: Acceptable for 800 items (~200KB in-memory), List lazy loads
- **Grouping complexity:** Empty route types shown
  - Mitigation: Filter by `.keys.sorted()` only shows present types
- **ShareLink unavailable:** iOS <16
  - Mitigation: Project targets iOS 16+ (Phase 0 decision)

## Validation
```bash
# Open Xcode
open SydneyTransit/SydneyTransit.xcodeproj

# Run in simulator (Cmd+R)

# Test StopDetailsView:
1. Search "circular" → Tap "Circular Quay Station"
2. StopDetailsView shows:
   - Stop name, code, coordinates
   - Map with blue marker
   - "Phase 2" departures message
3. Tap Share button → iOS share sheet appears
4. Share text includes coordinates + Apple Maps link

# Test RouteListView:
1. HomeView → Tap "Browse Routes"
2. RouteListView shows grouped list:
   - Section "Train" → T1, T2, T3, ... (red badge)
   - Section "Metro" → M1 (purple badge)
   - Section "Bus" → 100, 200, 333, ... (blue badge)
   - Section "Ferry" → F1, F2, ... (green badge)
   - Section "Tram" → L1, L2, L3 (orange badge)
3. Verify route count: 400-1200 routes total
4. Smooth scrolling (List lazy loads)

# Check Xcode Console:
# stop_details_viewed: stop_id=1, stop_name="Circular Quay Station"
# route_list_loading
# route_list_loaded: count=800

# No errors, no crashes
```

## References for Subagent
- Exploration report: `critical_patterns` → "iOS Logger wrapper"
- Standards: DEVELOPMENT_STANDARDS.md:Section 3.2.3 (iOS view patterns)
- Architecture: IOS_APP_SPECIFICATION.md:Section 5.1-5.3 (view structure)
- Existing models: Checkpoint 8 (Stop, Route, RouteType)
- Existing logger: SydneyTransit/Core/Utilities/Logger.swift
- HomeView: SydneyTransit/Features/Home/HomeView.swift (Phase 0 + Checkpoint 9)
- SearchView: Checkpoint 9 (NavigationLink to StopDetailsView)

## Estimated Complexity
**simple** - SwiftUI List/Map/Share standard patterns, grouping straightforward, no complex state management
