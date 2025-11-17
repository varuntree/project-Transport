import SwiftUI
import Logging

struct DeparturesView: View {
    let stop: Stop
    @StateObject private var viewModel = DeparturesViewModel()
    @State private var stopId: String?
    @State private var lastTopSentinelTrigger: Date?

    var body: some View {
        ScrollView {
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
                    if viewModel.isLoadingPast {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                // Debounce sentinel triggers during scroll bounce
                                // Prevents race condition where multiple loadPastDepartures() execute in parallel
                                let now = Date()
                                if let lastTrigger = lastTopSentinelTrigger,
                                   now.timeIntervalSince(lastTrigger) < 0.3 {
                                    // Triggered within 300ms, ignore
                                    return
                                }
                                lastTopSentinelTrigger = now

                                Task {
                                    await viewModel.loadPastDepartures()
                                }
                            }
                    }

                    // Departures list
                    ForEach(viewModel.departures) { departure in
                        VStack(spacing: 0) {
                            NavigationLink(value: departure) {
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
                    } else {
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
        .navigationTitle("Departures")
        .onAppear {
            Task {
                // Get GTFS stop_id from dict_stop table
                do {
                    if let gtfsStopId = try stop.getStopID() {
                        stopId = gtfsStopId
                        Logger.database.info("Fetching departures", metadata: [
                            "sid": "\(stop.sid)",
                            "stop_id": "\(gtfsStopId)",
                            "stop_name": "\(stop.stopName)"
                        ])
                        await viewModel.loadInitialDepartures(stopId: gtfsStopId)
                        viewModel.startAutoRefresh(stopId: gtfsStopId)
                    } else {
                        Logger.database.error("No stop_id mapping found", metadata: [
                            "sid": "\(stop.sid)",
                            "stop_name": "\(stop.stopName)"
                        ])
                        viewModel.errorMessage = "Stop ID mapping not found"
                    }
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
                Text("\(departure.minutesUntil) min")
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
                Image(systemName: occupancy.symbolName)
                    .foregroundColor(occupancy.color)
                    .font(.body)
                    .accessibilityLabel(occupancy.label)
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
