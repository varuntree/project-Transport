import SwiftUI
import MapKit

struct TripDetailsView: View {
    let tripId: String
    @StateObject private var viewModel = TripDetailsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Show map if coordinates are available
            if let trip = viewModel.trip, trip.stops.allSatisfy({ $0.lat != nil && $0.lon != nil }) {
                TripMapView(stops: trip.stops)
                    .frame(height: 200)
                    .accessibilityLabel("Route Map")
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
