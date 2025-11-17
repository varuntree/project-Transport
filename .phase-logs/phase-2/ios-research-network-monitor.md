# iOS Research: NWPathMonitor for Offline Detection

## Key Pattern
NWPathMonitor observes network path changes asynchronously. Start monitor on background DispatchQueue, receive updates via pathUpdateHandler closure. Check path.status == .satisfied for connectivity. Monitor automatically detects Wi-Fi/cellular transitions.

## Code Example
```swift
import Network

@MainActor
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var isExpensive = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}

struct DeparturesView: View {
    @StateObject var networkMonitor = NetworkMonitor()

    var body: some View {
        VStack {
            if !networkMonitor.isConnected {
                Text("Offline - showing cached data")
                    .foregroundColor(.orange)
            }
            // List content...
        }
        .onAppear { networkMonitor.startMonitoring() }
        .onDisappear { networkMonitor.stopMonitoring() }
    }
}
```

## Critical Constraints
- Must call `start(queue:)` with background queue (never main queue - blocks UI)
- pathUpdateHandler may be called on any thread - use @MainActor for UI updates
- Call `cancel()` to stop monitoring (releases resources, stops callbacks)
- path.status values: .satisfied (connected), .unsatisfied (offline), .requiresConnection (waiting)

## Common Gotchas
- **Main queue blocking**: Starting monitor on main queue causes hangs - always use background DispatchQueue
- **Memory leak**: Forgetting `cancel()` - monitor continues running after view dismissed
- **Thread safety**: Updating @Published from pathUpdateHandler crashes - wrap in `Task { @MainActor in ... }`
- **False positives**: path.status == .satisfied doesn't guarantee internet (could be local network only) - check path.usesInterfaceType() for specific interface

## API Reference
- Apple docs: https://developer.apple.com/documentation/network/nwpathmonitor
- Related APIs: NWPath, NWPath.Status, NWInterface, NWPathMonitor.pathUpdateHandler

## Relevance to Phase 2
Checkpoint 10 (Graceful Degradation Test): NetworkMonitor detects offline state, shows banner in DeparturesView. When path.status == .unsatisfied, API calls fail gracefully (errorMessage shows, no crash). Helps distinguish network failures from backend errors.
