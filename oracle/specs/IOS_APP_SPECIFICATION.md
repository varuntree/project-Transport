# iOS App Specification - Sydney Transit App
**Project:** Swift/SwiftUI iOS Application
**Version:** 1.0 (Complete Specification)
**Date:** 2025-11-12
**Dependencies:** SYSTEM_OVERVIEW.md, DATA_ARCHITECTURE.md, BACKEND_SPECIFICATION.md
**Status:** Complete - No Oracle Consultations Required (Standard MVVM)

---

## Document Purpose

This document defines the iOS application architecture:
- SwiftUI + MVVM pattern
- Feature module structure
- Data layer (GRDB SQLite + network)
- Native iOS integrations (MapKit, APNs, Widgets, Live Activities)
- Performance & offline strategy
- Deployment & build configuration

**Note:** This follows standard iOS architectural patterns. No Oracle consultation needed.

---

## 1. Technology Stack

### Core Framework
- **Swift** 5.9+ (Xcode 15+)
- **SwiftUI** (iOS 16+ minimum, targets iOS 18 features where available)
- **Swift Concurrency** (async/await, actors, no Combine unless needed for streams)
- **Swift Package Manager** (SPM) for dependencies

### Key Dependencies (Minimal by Design)

```swift
// Package.swift
dependencies: [
    // Database
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),

    // Networking
    // (Using native URLSession async/await - no Alamofire)

    // Date/Time
    .package(url: "https://github.com/malcommac/SwiftDate.git", from: "7.0.0"),

    // Logging
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),

    // Supabase (Auth + Realtime if needed)
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
]
```

**Why these only:**
- **GRDB:** Battle-tested SQLite wrapper, type-safe, reactive queries, <50MB app size compatible
- **SwiftDate:** Robust timezone handling (Sydney DST), relative time formatting
- **swift-log:** Apple's official logging (unified with OSLog)
- **Supabase Swift:** Official client for auth + optional realtime

**Deliberately excluded:**
- ❌ Realm (performance issues at scale per research)
- ❌ Alamofire (native URLSession async/await is sufficient)
- ❌ Combine (SwiftUI + async/await covers most needs)
- ❌ RxSwift (unnecessary complexity)

---

## 2. App Architecture Pattern: MVVM + Coordinator

```
┌─────────────────────────────────────────────────────────────┐
│                      App Layer                               │
│  - AppDelegate (minimal, APNs registration)                 │
│  - App (SwiftUI lifecycle)                                  │
│  - DI Container (Environment, Services)                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
          ┌───────────▼──────────┐
          │   Coordinator        │
          │  (Navigation logic)  │
          └───────────┬──────────┘
                      │
     ┌────────────────┼────────────────┐
     │                │                │
┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐
│  View    │    │  View    │    │  View    │
│ (SwiftUI)│    │ (SwiftUI)│    │ (SwiftUI)│
└────┬─────┘    └────┬─────┘    └────┬─────┘
     │                │                │
┌────▼──────┐   ┌────▼──────┐   ┌────▼──────┐
│ ViewModel │   │ ViewModel │   │ ViewModel │
│@MainActor │   │@MainActor │   │@MainActor │
│Observable │   │Observable │   │Observable │
└────┬──────┘   └────┬──────┘   └────┬──────┘
     │                │                │
     └────────────────┼────────────────┘
                      │
          ┌───────────▼──────────────────────────┐
          │      Repository Layer                │
          │  (Protocol-based, testable)          │
          │  - StopsRepository                   │
          │  - RoutesRepository                  │
          │  - TripsRepository                   │
          │  - FavoritesRepository               │
          └───────────┬──────────────────────────┘
                      │
     ┌────────────────┼────────────────┐
     │                │                │
┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐
│ Network  │    │   GRDB   │    │ Supabase │
│ Service  │    │  SQLite  │    │  Client  │
└──────────┘    └──────────┘    └──────────┘
```

### Why MVVM + Coordinator?

**MVVM:**
- Clean separation: View (UI) ↔ ViewModel (logic) ↔ Repository (data)
- Testable (ViewModels are pure Swift, no UIKit/SwiftUI dependencies)
- SwiftUI-native with `@Observable` macro (iOS 17+) or `ObservableObject` (iOS 16)

**Coordinator:**
- Decouples navigation logic from views
- Handles deep links, universal links, push notification taps
- Manages navigation stacks per tab

---

## 3. Project Structure

```
TransitApp/
├── App/
│   ├── TransitApp.swift              # @main App entry point
│   ├── AppDelegate.swift              # UIApplicationDelegate (APNs, background)
│   ├── AppCoordinator.swift           # Root coordinator
│   └── DependencyContainer.swift      # Service injection
│
├── Core/
│   ├── DesignSystem/
│   │   ├── Colors.swift               # Semantic colors (light/dark)
│   │   ├── Typography.swift           # SF Pro text styles
│   │   ├── Components/
│   │   │   ├── TTButton.swift         # Primary/secondary buttons
│   │   │   ├── TTCard.swift           # Elevated cards
│   │   │   ├── TTTextField.swift      # Search field
│   │   │   └── TTEmptyState.swift     # Empty/error/loading states
│   │   └── Spacing.swift              # 4pt grid system
│   │
│   ├── Extensions/
│   │   ├── Date+Extensions.swift      # Relative time, Sydney TZ
│   │   ├── Color+Extensions.swift     # Hex init, semantic
│   │   └── View+Extensions.swift      # Custom modifiers
│   │
│   ├── Utilities/
│   │   ├── Logger.swift               # Unified logging (swift-log + OSLog)
│   │   ├── LocationManager.swift      # CoreLocation wrapper
│   │   ├── NotificationManager.swift  # UNUserNotificationCenter wrapper
│   │   └── FeatureFlags.swift         # Remote + local flags
│   │
│   └── Analytics/
│       ├── AnalyticsEvent.swift       # Event definitions
│       └── AnalyticsService.swift     # Telemetry (privacy-first)
│
├── Data/
│   ├── Models/
│   │   ├── Stop.swift                 # GTFS stop entity
│   │   ├── Route.swift                # GTFS route entity
│   │   ├── Trip.swift                 # GTFS trip entity
│   │   ├── Departure.swift            # Real-time departure
│   │   ├── Alert.swift                # Service alert
│   │   └── Favorite.swift             # User favorite
│   │
│   ├── Network/
│   │   ├── APIClient.swift            # Base HTTP client (URLSession async)
│   │   ├── Endpoints/
│   │   │   ├── StopsEndpoint.swift
│   │   │   ├── RoutesEndpoint.swift
│   │   │   ├── TripsEndpoint.swift
│   │   │   └── AlertsEndpoint.swift
│   │   ├── DTOs/                      # Data Transfer Objects (Codable)
│   │   │   ├── StopDTO.swift
│   │   │   └── DepartureDTO.swift
│   │   └── NetworkError.swift
│   │
│   ├── Persistence/
│   │   ├── Database.swift             # GRDB database manager
│   │   ├── Migrations/
│   │   │   └── V1_InitialSchema.swift
│   │   ├── Queries/
│   │   │   ├── StopQueries.swift      # SQL queries (type-safe)
│   │   │   └── RouteQueries.swift
│   │   └── Keychain/
│   │       └── KeychainService.swift  # Secure storage (tokens)
│   │
│   └── Repositories/
│       ├── StopsRepository.swift      # Protocol + implementation
│       ├── RoutesRepository.swift
│       ├── TripsRepository.swift
│       ├── FavoritesRepository.swift
│       └── AlertsRepository.swift
│
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   ├── Components/
│   │   │   ├── FavoriteStopCard.swift
│   │   │   └── QuickAccessRow.swift
│   │   └── HomeCoordinator.swift
│   │
│   ├── Search/
│   │   ├── SearchView.swift
│   │   ├── SearchViewModel.swift
│   │   ├── Components/
│   │   │   ├── SearchBar.swift
│   │   │   ├── StopResultRow.swift
│   │   │   └── NearbyStopsMap.swift
│   │   └── SearchCoordinator.swift
│   │
│   ├── Departures/
│   │   ├── DeparturesView.swift       # Real-time departures for a stop
│   │   ├── DeparturesViewModel.swift
│   │   ├── Components/
│   │   │   ├── DepartureRow.swift     # Countdown timer
│   │   │   └── PlatformSection.swift
│   │   └── DeparturesCoordinator.swift
│   │
│   ├── TripPlanner/
│   │   ├── TripPlannerView.swift
│   │   ├── TripPlannerViewModel.swift
│   │   ├── Components/
│   │   │   ├── LocationInput.swift
│   │   │   ├── TripOptionCard.swift
│   │   │   └── TripDetailView.swift
│   │   └── TripPlannerCoordinator.swift
│   │
│   ├── Favorites/
│   │   ├── FavoritesView.swift
│   │   ├── FavoritesViewModel.swift
│   │   └── FavoritesCoordinator.swift
│   │
│   ├── Alerts/
│   │   ├── AlertsView.swift
│   │   ├── AlertsViewModel.swift
│   │   ├── Components/
│   │   │   └── AlertCard.swift
│   │   └── AlertsCoordinator.swift
│   │
│   ├── Maps/
│   │   ├── MapView.swift              # MapKit + live vehicles
│   │   ├── MapViewModel.swift
│   │   └── Components/
│   │       ├── VehicleAnnotation.swift
│   │       └── RouteOverlay.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       ├── SettingsViewModel.swift
│       └── Components/
│           └── SettingRow.swift
│
├── Widgets/                           # WidgetKit (Phase 1.5)
│   ├── FavoriteStopWidget/
│   │   ├── FavoriteStopWidget.swift
│   │   ├── FavoriteStopEntry.swift
│   │   └── FavoriteStopProvider.swift
│   └── NearbyStopsWidget/
│
├── LiveActivities/                    # ActivityKit (Phase 1.5)
│   └── TripTrackingActivity/
│       ├── TripTrackingAttributes.swift
│       └── TripTrackingLiveActivity.swift
│
├── Resources/
│   ├── Assets.xcassets/               # Images, colors, icons
│   ├── Localizable.xcstrings           # Localization (English AU)
│   └── Info.plist
│
└── Tests/
    ├── UnitTests/
    │   ├── ViewModelTests/
    │   ├── RepositoryTests/
    │   └── ServiceTests/
    ├── IntegrationTests/
    │   └── DatabaseTests/
    └── UITests/
        └── CriticalFlowTests/
```

---

## 4. Data Layer Architecture

### 4.1 Three-Tier Data Strategy

```
┌─────────────────────────────────────────────────┐
│              ViewModel Layer                    │
│  - Requests data via Repository protocols       │
│  - Observes changes (Combine/AsyncStream)       │
└──────────────────┬──────────────────────────────┘
                   │
        ┌──────────▼──────────┐
        │  Repository Layer   │
        │  (Single source of  │
        │   truth logic)      │
        └──────────┬──────────┘
                   │
     ┌─────────────┼─────────────┐
     │             │             │
┌────▼────┐   ┌───▼────┐   ┌────▼────┐
│ Network │   │  GRDB  │   │Supabase │
│ (Remote)│   │(Local) │   │ (Sync)  │
└─────────┘   └────────┘   └─────────┘
```

**Repository decides:**
- Serve from local SQLite (fast, offline)
- Fetch from network (fresh, real-time)
- Sync to Supabase (favorites, settings)

### 4.2 GRDB SQLite Schema

Based on DATA_ARCHITECTURE.md Section 6 (Oracle-validated pattern model):

```swift
// Migrations/V1_InitialSchema.swift
import GRDB

struct V1_InitialSchema: Migration {
    static let identifier = "v1"

    static func migrate(_ db: Database) throws {
        // Stops (from GTFS, compact)
        try db.create(table: "stops") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("stop_id", .text).notNull().unique()
            t.column("stop_name", .text).notNull()
            t.column("stop_lat", .double).notNull()
            t.column("stop_lon", .double).notNull()
            t.column("location_type", .integer).notNull().defaults(to: 0)
            t.column("wheelchair_boarding", .integer).notNull().defaults(to: 0)
        }
        try db.create(index: "idx_stops_location", on: "stops", columns: ["stop_lat", "stop_lon"])

        // Routes (from GTFS)
        try db.create(table: "routes") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("route_id", .text).notNull().unique()
            t.column("route_short_name", .text)
            t.column("route_long_name", .text).notNull()
            t.column("route_type", .integer).notNull()
            t.column("route_color", .text)
            t.column("route_text_color", .text)
        }

        // Patterns (Oracle pattern model from DATA_ARCHITECTURE.md)
        try db.create(table: "patterns") { t in
            t.autoIncrementedPrimaryKey("pattern_id")
            t.column("route_id", .text).notNull()
                .references("routes", column: "route_id", onDelete: .cascade)
            t.column("direction_id", .integer)
            t.column("shape_id", .text)
        }

        // Pattern stops (compressed stop_times)
        try db.create(table: "pattern_stops") { t in
            t.column("pattern_id", .integer).notNull()
                .references("patterns", onDelete: .cascade)
            t.column("seq", .integer).notNull()
            t.column("stop_id", .text).notNull()
                .references("stops", column: "stop_id")
            t.column("offset_secs", .integer).notNull()
            t.primaryKey(["pattern_id", "seq"])
        }
        try db.create(index: "idx_pattern_stops_stop", on: "pattern_stops", columns: ["stop_id"])

        // Trips (compact with pattern reference)
        try db.create(table: "trips") { t in
            t.column("trip_id", .text).primaryKey()
            t.column("pattern_id", .integer).notNull()
                .references("patterns", onDelete: .cascade)
            t.column("service_id", .text).notNull()
            t.column("start_time_secs", .integer).notNull()
            t.column("headsign", .text)
        }
        try db.create(index: "idx_trips_pattern", on: "trips", columns: ["pattern_id"])

        // Calendar (service dates)
        try db.create(table: "calendar") { t in
            t.column("service_id", .text).primaryKey()
            t.column("monday", .boolean).notNull()
            t.column("tuesday", .boolean).notNull()
            t.column("wednesday", .boolean).notNull()
            t.column("thursday", .boolean).notNull()
            t.column("friday", .boolean).notNull()
            t.column("saturday", .boolean).notNull()
            t.column("sunday", .boolean).notNull()
            t.column("start_date", .text).notNull()
            t.column("end_date", .text).notNull()
        }

        // Favorites (user data, synced to Supabase)
        try db.create(table: "favorites") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("stop_id", .text).notNull()
                .references("stops", column: "stop_id", onDelete: .cascade)
            t.column("label", .text)  // User-defined name
            t.column("created_at", .datetime).notNull()
            t.column("sort_order", .integer).notNull().defaults(to: 0)
            t.column("synced_to_cloud", .boolean).notNull().defaults(to: false)
        }
        try db.create(index: "idx_favorites_stop", on: "favorites", columns: ["stop_id"])
    }
}
```

**Size estimate:** ~15-20 MB for Sydney GTFS (Oracle-validated pattern compression from DATA_ARCHITECTURE.md)

### 4.3 Repository Pattern (Example: StopsRepository)

```swift
// Data/Repositories/StopsRepository.swift
import Foundation
import GRDB

protocol StopsRepositoryProtocol {
    func nearbyStops(latitude: Double, longitude: Double, radius: Int) async throws -> [Stop]
    func stop(id: String) async throws -> Stop?
    func search(query: String) async throws -> [Stop]
}

actor StopsRepository: StopsRepositoryProtocol {
    private let database: DatabaseQueue
    private let apiClient: APIClient

    init(database: DatabaseQueue, apiClient: APIClient) {
        self.database = database
        self.apiClient = apiClient
    }

    func nearbyStops(latitude: Double, longitude: Double, radius: Int) async throws -> [Stop] {
        // Strategy: Query local SQLite first (fast, offline-capable)
        // Network fallback only if local DB empty (first run)

        let localStops = try await database.read { db in
            // Haversine approximation for nearby stops
            try Stop.fetchAll(db, sql: """
                SELECT *,
                    (6371000 * acos(
                        cos(radians(?)) * cos(radians(stop_lat)) *
                        cos(radians(stop_lon) - radians(?)) +
                        sin(radians(?)) * sin(radians(stop_lat))
                    )) AS distance
                FROM stops
                HAVING distance < ?
                ORDER BY distance
                LIMIT 20
                """,
                arguments: [latitude, longitude, latitude, radius]
            )
        }

        if !localStops.isEmpty {
            return localStops
        }

        // Fallback: fetch from API (shouldn't happen after initial sync)
        let dto = try await apiClient.request(StopsEndpoint.nearby(lat: latitude, lon: longitude, radius: radius))
        return dto.map { $0.toDomain() }
    }

    func stop(id: String) async throws -> Stop? {
        try await database.read { db in
            try Stop.fetchOne(db, key: id)
        }
    }

    func search(query: String) async throws -> [Stop] {
        // FTS (Full-Text Search) via GRDB if needed, or simple LIKE query
        try await database.read { db in
            try Stop.filter(Column("stop_name").like("%\(query)%"))
                .limit(20)
                .fetchAll(db)
        }
    }
}
```

### 4.4 Network Layer (Example: APIClient)

```swift
// Data/Network/APIClient.swift
import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let rateLimiter: RateLimiter  // Client-side throttle

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.rateLimiter = RateLimiter(maxRequests: 60, per: 60)  // 60/min local limit
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        // Wait for rate limiter
        await rateLimiter.wait()

        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.headers

        if let body = endpoint.body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        case 429:
            // Respect Retry-After if present
            if let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After"),
               let seconds = Double(retryAfter) {
                try await Task.sleep(for: .seconds(seconds))
                return try await request(endpoint)  // Retry once
            }
            throw NetworkError.rateLimited
        case 401:
            throw NetworkError.unauthorized
        default:
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
}

enum NetworkError: LocalizedError {
    case invalidResponse
    case rateLimited
    case unauthorized
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .rateLimited: return "Too many requests. Please try again later."
        case .unauthorized: return "Session expired. Please sign in again."
        case .httpError(let code): return "Server error: \(code)"
        }
    }
}
```

---

## 5. Feature Implementation Examples

### 5.1 Home Screen (Favorites + Quick Access)

```swift
// Features/Home/HomeViewModel.swift
import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let favoritesRepo: FavoritesRepositoryProtocol
    private let departuresRepo: DeparturesRepositoryProtocol

    var favorites: [FavoriteStop] = []
    var isLoading = false
    var error: Error?

    init(favoritesRepo: FavoritesRepositoryProtocol, departuresRepo: DeparturesRepositoryProtocol) {
        self.favoritesRepo = favoritesRepo
        self.departuresRepo = departuresRepo
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let favs = try await favoritesRepo.getFavorites()

            // Fetch next departures for each favorite (parallel)
            let enriched = try await withThrowingTaskGroup(of: FavoriteStop.self) { group in
                for fav in favs {
                    group.addTask {
                        let departures = try await self.departuresRepo.nextDepartures(stopID: fav.stopID, limit: 3)
                        return FavoriteStop(
                            id: fav.id,
                            stopID: fav.stopID,
                            stopName: fav.stopName,
                            label: fav.label,
                            nextDepartures: departures
                        )
                    }
                }

                var results: [FavoriteStop] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }

            favorites = enriched
        } catch {
            self.error = error
        }
    }

    func refresh() async {
        await load()
    }
}
```

```swift
// Features/Home/HomeView.swift
import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if let error = viewModel.error {
                        TTEmptyState(
                            title: "Unable to load favorites",
                            message: error.localizedDescription,
                            action: { Task { await viewModel.refresh() } }
                        )
                    } else if viewModel.favorites.isEmpty {
                        TTEmptyState(
                            title: "No favorites yet",
                            message: "Add your frequently used stops for quick access",
                            systemImage: "star"
                        )
                    } else {
                        ForEach(viewModel.favorites) { favorite in
                            FavoriteStopCard(favorite: favorite)
                                .onTapGesture {
                                    // Navigate to stop details
                                }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.load()
            }
        }
    }
}
```

### 5.2 Real-Time Departures (Countdown Timers)

```swift
// Features/Departures/DeparturesViewModel.swift
import Foundation
import Observation

@MainActor
@Observable
final class DeparturesViewModel {
    private let departuresRepo: DeparturesRepositoryProtocol
    private let stopID: String

    var departures: [Departure] = []
    var isLoading = false
    var lastUpdated: Date?

    private var refreshTask: Task<Void, Never>?

    init(stopID: String, departuresRepo: DeparturesRepositoryProtocol) {
        self.stopID = stopID
        self.departuresRepo = departuresRepo
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(30))  // Refresh every 30s
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            departures = try await departuresRepo.nextDepartures(stopID: stopID, limit: 10)
            lastUpdated = Date()
        } catch {
            // Handle error
        }
    }
}

struct Departure: Identifiable {
    let id: String
    let routeName: String
    let headsign: String
    let scheduledTime: Date
    let realtimeTime: Date?
    let platform: String?
    let isWheelchairAccessible: Bool

    var countdown: Int {
        let target = realtimeTime ?? scheduledTime
        return Int(target.timeIntervalSinceNow / 60)  // Minutes
    }

    var isDelayed: Bool {
        guard let rt = realtimeTime else { return false }
        return rt > scheduledTime.addingTimeInterval(60)  // >1 min late
    }
}
```

---

## 6. Native iOS Integrations

### 6.1 MapKit (Live Vehicle Positions)

```swift
// Features/Maps/MapViewModel.swift
import MapKit
import Observation

@MainActor
@Observable
final class MapViewModel {
    private let vehiclesRepo: VehiclesRepositoryProtocol

    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),  // Sydney
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var vehicles: [VehicleAnnotation] = []

    func load() async {
        do {
            let liveVehicles = try await vehiclesRepo.liveVehicles(in: region)
            vehicles = liveVehicles.map { VehicleAnnotation(vehicle: $0) }
        } catch {
            // Handle error
        }
    }
}

struct VehicleAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let routeName: String
    let bearing: Double
    let vehicleType: VehicleType
}
```

### 6.2 Push Notifications (APNs)

```swift
// Core/Utilities/NotificationManager.swift
import UserNotifications

@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ALERT",
            title: "View Details",
            options: .foreground
        )

        let delayCategory = UNNotificationCategory(
            identifier: "DELAY_ALERT",
            actions: [viewAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([delayCategory])
    }
}

// AppDelegate.swift
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerCategories()
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Send token to backend
        Task {
            try? await APIClient.shared.registerDevice(apnsToken: token)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // Handle notification tap (deep link to stop/route)
        let userInfo = response.notification.request.content.userInfo
        if let stopID = userInfo["stop_id"] as? String {
            // Navigate to stop details
        }
    }
}
```

### 6.3 Widgets (WidgetKit - Phase 1.5)

```swift
// Widgets/FavoriteStopWidget/FavoriteStopWidget.swift
import WidgetKit
import SwiftUI

struct FavoriteStopEntry: TimelineEntry {
    let date: Date
    let stop: Stop
    let nextDepartures: [Departure]
}

struct FavoriteStopProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoriteStopEntry {
        FavoriteStopEntry(date: Date(), stop: .placeholder, nextDepartures: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoriteStopEntry) -> Void) {
        // Fetch current data
        Task {
            let entry = try await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoriteStopEntry>) -> Void) {
        Task {
            let entry = try await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry() async throws -> FavoriteStopEntry {
        // Fetch from shared App Group container (GRDB database)
        // OR make lightweight API call
        fatalError("Implement data fetching")
    }
}

struct FavoriteStopWidgetView: View {
    let entry: FavoriteStopEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.stop.stopName)
                .font(.headline)

            ForEach(entry.nextDepartures.prefix(3)) { dep in
                HStack {
                    Text(dep.routeName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(dep.countdown) min")
                        .font(.caption)
                        .foregroundColor(dep.isDelayed ? .red : .secondary)
                }
            }
        }
        .padding()
    }
}
```

### 6.4 Live Activities (Phase 1.5)

```swift
// LiveActivities/TripTrackingActivity/TripTrackingAttributes.swift
import ActivityKit

struct TripTrackingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentStopIndex: Int
        var estimatedArrival: Date
        var nextStopName: String
    }

    var routeName: String
    var destination: String
    var totalStops: Int
}

// Start activity when user begins trip
func startTripTracking(trip: Trip) {
    let attributes = TripTrackingAttributes(
        routeName: trip.routeName,
        destination: trip.destination,
        totalStops: trip.stops.count
    )

    let initialState = TripTrackingAttributes.ContentState(
        currentStopIndex: 0,
        estimatedArrival: trip.estimatedArrival,
        nextStopName: trip.stops.first?.name ?? ""
    )

    do {
        let activity = try Activity<TripTrackingAttributes>.request(
            attributes: attributes,
            contentState: initialState,
            pushType: .token
        )
        // Send push token to backend for updates
    } catch {
        // Handle error
    }
}
```

---

## 7. Performance Optimization

### 7.1 App Launch Performance

**Target:** <2s cold launch, <1s warm launch

**Strategy:**
- Lazy load features (not all on launch)
- Database opened asynchronously
- Network calls only after UI renders
- SwiftUI view hierarchy optimized (avoid deep nesting)

```swift
// App/TransitApp.swift
@main
struct TransitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
                .task {
                    // Async initialization (doesn't block UI)
                    await container.initialize()
                }
        }
    }
}
```

### 7.2 Memory Management

**Target:** <150 MB typical, <200 MB peak

**Strategies:**
- Image caching with size limits (NSCache)
- Pagination for large lists (LazyVStack)
- Release resources in `onDisappear`
- Profile with Instruments (Allocations, Leaks)

### 7.3 Battery Optimization

**Target:** <5% drain for 30-minute commute with location

**Strategies:**
- Location updates: `authorizedWhenInUse` only, pause when not needed
- Network: batch requests, avoid polling when app backgrounded
- Background refresh: opportunistic (15-minute intervals), low power mode aware

---

## 8. Offline Strategy

### 8.1 What Works Offline

✅ **Fully offline:**
- Browse stops/routes (local GRDB)
- Search stops by name
- View static schedules
- View favorites

❌ **Requires network:**
- Real-time departures
- Trip planning
- Live vehicle positions
- Service alerts

### 8.2 Offline UI Indicators

```swift
struct OfflineBanner: View {
    @Environment(\.networkStatus) var networkStatus

    var body: some View {
        if !networkStatus.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                Text("You're offline. Showing cached data.")
            }
            .padding()
            .background(Color.orange.opacity(0.2))
        }
    }
}
```

---

## 9. Build Configuration

### 9.1 Targets & Schemes

| Target               | Bundle ID                        | Environment | Purpose                |
| -------------------- | -------------------------------- | ----------- | ---------------------- |
| **TransitApp**       | `com.yourco.transitapp`          | Production  | App Store release      |
| **TransitApp (Dev)** | `com.yourco.transitapp.dev`      | Development | Local testing          |
| **TransitApp (Stg)** | `com.yourco.transitapp.staging`  | Staging     | TestFlight beta        |
| **TransitAppWidget** | `com.yourco.transitapp.widget`   | Production  | Widget extension       |
| **TTLiveActivity**   | `com.yourco.transitapp.activity` | Production  | Live Activity          |

### 9.2 Configuration Files (.xcconfig)

```
// Config/Dev.xcconfig
API_BASE_URL = https:/​/dev-api.yourdomain.com
SUPABASE_URL = https:/​/yourproject.supabase.co
SUPABASE_ANON_KEY = eyJ... (dev key)

// Config/Production.xcconfig
API_BASE_URL = https:/​/api.yourdomain.com
SUPABASE_URL = https:/​/yourproject.supabase.co
SUPABASE_ANON_KEY = eyJ... (prod key)
```

### 9.3 App Size Optimization

**Target:** <50 MB download size

**Techniques:**
- Bitcode enabled (automatic optimization)
- Asset catalog optimization (compress images)
- Unused code stripping (`DEAD_CODE_STRIPPING = YES`)
- On-demand resources for optional offline data
- No bundled GTFS data (download on first launch)

---

## 10. Testing Strategy

### 10.1 Unit Tests

**Coverage target:** 80% for business logic

```swift
// Tests/UnitTests/ViewModelTests/DeparturesViewModelTests.swift
@Test
func testLoadDepartures() async throws {
    let mockRepo = MockDeparturesRepository()
    let vm = DeparturesViewModel(stopID: "123", departuresRepo: mockRepo)

    await vm.load()

    #expect(vm.departures.count == 5)
    #expect(vm.isLoading == false)
}
```

### 10.2 UI Tests

**Critical flows:**
- Search stop → view departures → favorite
- Plan trip → view results → select option
- Receive push notification → tap → navigate to stop

```swift
// Tests/UITests/CriticalFlowTests.swift
@Test
func testSearchAndFavoriteFlow() async throws {
    let app = XCUIApplication()
    app.launch()

    app.tabBars.buttons["Search"].tap()
    app.searchFields.firstMatch.tap()
    app.searchFields.firstMatch.typeText("Central Station")
    app.tables.cells.firstMatch.tap()
    app.buttons["Add to Favorites"].tap()

    #expect(app.staticTexts["Favorite added"].exists)
}
```

---

## 11. Deployment

### 11.1 Versioning

**Semantic versioning:** MAJOR.MINOR.PATCH
- **MAJOR:** Breaking changes (rare)
- **MINOR:** New features
- **PATCH:** Bug fixes

**Build number:** Auto-incremented via fastlane

### 11.2 Release Process

```
Developer → PR → CI (lint, test, build) → Merge → TestFlight → Production
```

**Fastlane lanes:**

```ruby
# fastlane/Fastfile
lane :test do
  run_tests(scheme: "TransitApp")
end

lane :beta do
  increment_build_number
  build_app(scheme: "TransitApp", export_method: "app-store")
  upload_to_testflight
end

lane :release do
  build_app(scheme: "TransitApp", export_method: "app-store")
  upload_to_app_store
end
```

---

## 12. Accessibility

### 12.1 VoiceOver Support

**Requirements:**
- All interactive elements have accessibility labels
- Meaningful hints for complex interactions
- Logical focus order

```swift
Button("Add to Favorites") { }
    .accessibilityLabel("Add Central Station to favorites")
    .accessibilityHint("Double tap to save this stop for quick access")
```

### 12.2 Dynamic Type

**All text must scale:**

```swift
Text("Route 333")
    .font(.headline)  // Scales automatically with Dynamic Type
```

### 12.3 Color Contrast

**WCAG 2.1 AA compliance:**
- Text: 4.5:1 contrast ratio
- Interactive elements: 3:1 contrast ratio

---

## 13. Analytics & Privacy

### 13.1 Event Tracking (Privacy-First)

**Events to track:**
- `app_launch`
- `stop_search` (no query text, just count)
- `trip_planned` (origin/destination hashed)
- `favorite_added`
- `push_notification_received`

**No PII:** No user identifiers, locations, search terms

```swift
// Core/Analytics/AnalyticsService.swift
struct AnalyticsService {
    func track(_ event: AnalyticsEvent) {
        // Send to privacy-friendly service (e.g., Plausible, not Google Analytics)
    }
}
```

### 13.2 App Privacy Nutrition Label

**Data Collected:**
- Location (only when app in use, for nearby stops)
- Favorites (synced to Supabase, deletable)

**Not Collected:**
- Search history
- Usage patterns
- Identifiers

---

## 14. Summary

**iOS App Specification Complete:**

✅ **Architecture:** MVVM + Coordinator, Repository pattern
✅ **Data Layer:** GRDB SQLite (Oracle-validated pattern model), Network (async/await), Supabase sync
✅ **Features:** Home, Search, Departures, Trip Planner, Favorites, Alerts, Maps, Settings
✅ **Native Integrations:** MapKit, APNs, Widgets, Live Activities
✅ **Performance:** <2s launch, <150 MB memory, <5% battery
✅ **Offline:** Full stop/route browsing, graceful degradation
✅ **Testing:** 80% unit coverage, critical flow UI tests
✅ **Accessibility:** VoiceOver, Dynamic Type, WCAG 2.1 AA
✅ **Privacy:** Minimal data collection, no PII

**No Oracle consultations required** - this follows industry-standard iOS patterns.

**Next:** INTEGRATION_CONTRACTS.md (API contracts + 1 Oracle consultation for APNs architecture)
