import SwiftUI
import CoreLocation
import Combine

@MainActor
class NearbyStopsViewModel: ObservableObject {
    @Published var stops: [(Stop, Double)] = []
    @Published var isLoading = false
    @Published var permissionState: PermissionState = .notDetermined
    @Published var error: String?
    
    enum PermissionState {
        case notDetermined
        case authorized
        case denied
        case restricted
    }
    
    private var locationManager = LocationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe permission changes
        locationManager.$authorizationStatus
            .receive(on: RunLoop.main)
            .map { status -> PermissionState in
                switch status {
                case .authorizedWhenInUse, .authorizedAlways: return .authorized
                case .denied: return .denied
                case .restricted: return .restricted
                case .notDetermined: return .notDetermined
                @unknown default: return .notDetermined
                }
            }
            .assign(to: &$permissionState)
        
        // Observe location changes
        locationManager.$currentLocation
            .compactMap { $0 }
            // Debounce to avoid rapid updates
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] location in
                Task {
                    await self?.fetchStops(location: location)
                }
            }
            .store(in: &cancellables)
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func fetchStops(location: CLLocation) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            // Run database query on background thread
            let results = try await Task.detached(priority: .userInitiated) {
                try DatabaseManager.shared.getNearbyStops(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }.value
            
            self.stops = results
        } catch {
            self.error = "Failed to load stops: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct NearbyStopsSection: View {
    @StateObject private var viewModel = NearbyStopsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearby Stops")
                .font(.headline)
                .padding(.horizontal)
            
            content
        }
        .onAppear {
            // If permission not determined, we can prompt or wait for user interaction.
            // Checkpoint 1/3 implies user triggers it or it shows empty state.
            // We'll show the list or empty state.
        }
    }
    
    @ViewBuilder
    var content: some View {
        switch viewModel.permissionState {
        case .notDetermined:
            requestPermissionView
        case .denied:
            permissionDeniedView
        case .restricted:
            permissionRestrictedView
        case .authorized:
            if viewModel.isLoading && viewModel.stops.isEmpty {
                ProgressView("Finding stops...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if viewModel.stops.isEmpty {
                noStopsView
            } else {
                stopsList
            }
        }
    }
    
    var stopsList: some View {
        // Using simple ForEach since we are inside a ScrollView (HomeView is usually a ScrollView)
        // If HomeView is NOT a ScrollView, we might need List.
        // BUT HomeView usually has multiple sections.
        // If we use List, it consumes the whole view.
        // We should probably use VStack + ForEach for embedding in HomeView ScrollView.
        // Research said "List automatically lazy...". But embedding List in ScrollView is bad.
        // If HomeView is a ScrollView, we should use LazyVStack or VStack.
        // For 20 items, VStack is fine.
        
        VStack(spacing: 0) {
            ForEach(viewModel.stops, id: \.0.sid) { (stop, distance) in
                NavigationLink(destination: StopDetailsView(stop: stop)) {
                    HStack(spacing: 16) {
                        Image(systemName: stop.transportIcon)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.stopName)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text("\(Int(distance))m away")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .contentShape(Rectangle()) // Tappable area
                }
                
                Divider()
                    .padding(.leading, 60)
            }
        }
        .background(Color(.systemBackground))
    }
    
    var requestPermissionView: some View {
        emptyState(
            icon: "location.circle.fill",
            title: "Nearby Stops",
            message: "See stops near you by enabling location access.",
            buttonTitle: "Allow Location Access",
            action: viewModel.requestPermission
        )
    }
    
    var permissionDeniedView: some View {
        emptyState(
            icon: "location.slash.fill",
            title: "Location Denied",
            message: "Please enable location access in Settings to see nearby stops.",
            buttonTitle: "Open Settings",
            action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        )
    }
    
    var permissionRestrictedView: some View {
        emptyState(
            icon: "lock.shield.fill",
            title: "Location Unavailable",
            message: "Location access is restricted on this device.",
            buttonTitle: nil,
            action: {}
        )
    }
    
    var noStopsView: some View {
        emptyState(
            icon: "bus.doubledecker.fill", // generic transit icon
            title: "No Stops Nearby",
            message: "No stops found within 500m.",
            buttonTitle: nil,
            action: {}
        )
    }
    
    func emptyState(icon: String, title: String, message: String, buttonTitle: String?, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            if let buttonTitle = buttonTitle {
                Button(action: action) {
                    Text(buttonTitle)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
