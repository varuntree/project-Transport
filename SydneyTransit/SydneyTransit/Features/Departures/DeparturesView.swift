import SwiftUI
import Logging

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct OccupancyIconView: View {
    let occupancy: (symbolName: String, color: Color, label: String)
    let departure: Departure

    init(occupancy: (symbolName: String, color: Color, label: String), departure: Departure) {
        self.occupancy = occupancy
        self.departure = departure
        Logger.app.debug("Occupancy check", metadata: [
            "trip_id": "\(departure.tripId)",
            "occupancy_status": "\(departure.occupancy_status?.description ?? "nil")"
        ])
    }

    var body: some View {
        Image(systemName: occupancy.symbolName)
            .foregroundColor(occupancy.color)
            .font(.body)
            .accessibilityLabel(occupancy.label)
    }
}

struct DeparturesView: View {
    let stop: Stop
    @StateObject private var viewModel = DeparturesViewModel()
    @State private var stopId: String?
    @State private var lastTopSentinelTrigger: Date?
    @State private var hasLoadedInitial = false  // Track if initial load complete
    @State private var hasScrolledDown = false

    var body: some View {
        ScrollView {
            GeometryReader { proxy in
                Color.clear
                    .frame(height: 0)
                    .preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("departuresScroll")).minY
                    )
            }
            .frame(height: 0)

            LazyVStack(spacing: 0) {
                if viewModel.isLoading && viewModel.departures.isEmpty {
                    ProgressView("Loading departures...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if viewModel.departures.isEmpty {
                    Text("No upcoming departures")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    // Top sentinel for loading past departures
                    // CRITICAL FIX: Only trigger if initial load complete (prevents immediate trigger)
                    if viewModel.isLoadingPast {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if hasLoadedInitial && viewModel.hasMorePast {
                        // Only show sentinel after initial load (prevents auto-trigger)
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                guard hasScrolledDown else { return }
                                // Debounce sentinel triggers during scroll bounce
                                // Prevents race condition where multiple loadPastDepartures() execute in parallel
                                let now = Date()
                                if let lastTrigger = lastTopSentinelTrigger,
                                   now.timeIntervalSince(lastTrigger) < 0.3 {
                                    // Triggered within 300ms, ignore
                                    return
                                }
                                lastTopSentinelTrigger = now
                                hasScrolledDown = false

                                Task {
                                    await viewModel.loadPastDepartures()
                                }
                            }
                    }

                    // Departures list
                    ForEach(viewModel.departures) { departure in
                        VStack(spacing: 0) {
                            NavigationLink(destination: TripDetailsView(tripId: departure.tripId)) {
                                DepartureRow(departure: departure)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)

                            Divider()
                        }
                    }

                    // Bottom sentinel for loading future departures
                    if viewModel.isLoadingFuture {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if viewModel.hasMoreFuture {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task {
                                    await viewModel.loadFutureDepartures()
                                }
                            }
                    }
                }
            }
        }
        .coordinateSpace(name: "departuresScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            if value < -10 {
                hasScrolledDown = true
            }
        }
        .navigationTitle("Departures")
        .onAppear {
            Task {
                // Get GTFS stop_id from dict_stop table
                do {
                    let gtfsStopId = try stop.getStopID()

                    // Enhanced diagnostic logging
                    Logger.database.info("departures_request", metadata: [
                        "sid": "\(stop.sid)",
                        "stop_id": gtfsStopId ?? "nil",
                        "stop_name": "\(stop.stopName)"
                    ])

                    guard let stopID = gtfsStopId else {
                        // Handle missing stop_id gracefully
                        viewModel.errorMessage = "Unable to fetch departures: stop ID mapping missing"
                        Logger.database.error("departures_missing_stop_id", metadata: [
                            "sid": "\(stop.sid)",
                            "stop_name": "\(stop.stopName)"
                        ])
                        return
                    }

                    stopId = stopID
                    await viewModel.loadInitialDepartures(stopId: stopID)
                    hasLoadedInitial = true  // Mark initial load complete
                    viewModel.startAutoRefresh(stopId: stopID)
                } catch {
                    Logger.database.error("Failed to get stop_id", metadata: [
                        "sid": "\(stop.sid)",
                        "error": "\(error.localizedDescription)"
                    ])
                    viewModel.errorMessage = "Failed to load stop information"
                }
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
}

struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        HStack(spacing: 12) {
            // Minutes countdown (large, highlighted) + time subscript
                VStack(alignment: .leading, spacing: 2) {
                    Text(departure.minutesUntilText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(departure.departureTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, alignment: .leading)

            // Route badge (blue rounded rectangle)
            Text(departure.routeShortName)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(8)

            // Headsign + status
            VStack(alignment: .leading, spacing: 4) {
                Text("to \(departure.headsign)")
                    .font(.body)
                    .lineLimit(1)

                // Status text (On time, Early, Late, or Scheduled)
                if let delayText = departure.delayText {
                    Text(delayText)
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if departure.realtime && departure.delayS == 0 {
                    Text("On time")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Scheduled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Occupancy icon (if available)
            if let occupancy = departure.occupancyIcon {
                OccupancyIconView(occupancy: occupancy, departure: departure)
            }

            // Wheelchair icon (if accessible)
            if departure.wheelchairAccessible == 1 {
                Image(systemName: "figure.roll")
                    .foregroundColor(.blue)
                    .font(.body)
                    .accessibilityLabel("Wheelchair accessible")
            }
        }
        .padding(.vertical, 8)
    }
}
