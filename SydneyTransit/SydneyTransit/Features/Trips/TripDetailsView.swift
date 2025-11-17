import SwiftUI
import MapKit
import Logging

struct TripDetailsView: View {
    let tripId: String
    @StateObject private var viewModel = TripDetailsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Show map if at least 2 stops have coordinates (graceful degradation)
            if let trip = viewModel.trip {
                let stopsWithCoords = trip.stops.filter { $0.lat != nil && $0.lon != nil }
                if stopsWithCoords.count >= 2 {
                    VStack(spacing: 0) {
                        TripMapView(stops: stopsWithCoords)
                            .frame(height: 200)
                            .accessibilityLabel("Route Map")

                        // Warning if partial route
                        if stopsWithCoords.count < trip.stops.count {
                            Text("Showing partial route (\(stopsWithCoords.count) of \(trip.stops.count) stops)")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color.orange.opacity(0.1))
                        }
                    }
                    .onAppear {
                        Logger.app.debug("Map visibility", metadata: [
                            "trip_id": "\(tripId)",
                            "stops_count": "\(trip.stops.count)",
                            "stops_with_coords": "\(stopsWithCoords.count)"
                        ])
                    }
                }
            }

            List {
                if viewModel.isLoading {
                    ProgressView("Loading trip details...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let trip = viewModel.trip {
                    ForEach(trip.stops) { tripStop in
                        TripStopRow(tripStop: tripStop)
                    }
                }
            }
        }
        .navigationTitle(viewModel.trip?.headsign ?? "Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.loadTrip(id: tripId)
            }
        }
    }
}

struct TripStopRow: View {
    let tripStop: TripStop

    var body: some View {
        HStack(spacing: 12) {
            // Stop name + platform
            VStack(alignment: .leading, spacing: 4) {
                Text(tripStop.stopName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let platform = tripStop.platform {
                    Text("Platform \(platform)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Wheelchair icon (if accessible)
            if tripStop.wheelchairAccessible == 1 {
                Image(systemName: "figure.roll")
                    .foregroundColor(.blue)
                    .font(.body)
                    .accessibilityLabel("Wheelchair accessible")
            }

            // Arrival time
            Text(tripStop.arrivalTime)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}
