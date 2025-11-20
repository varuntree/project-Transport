import SwiftUI
import MapKit
import Logging

struct TripDetailsView: View {
    let tripId: String
    @StateObject private var viewModel = TripDetailsViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            mapBackground

            bottomSheet
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.loadTrip(id: tripId)
            }
        }
    }

    @ViewBuilder
    private var mapBackground: some View {
        if let trip = viewModel.trip {
            let stopsWithCoords = trip.stops.filter { $0.lat != nil && $0.lon != nil }
            if stopsWithCoords.count >= 2 {
                TripMapView(stops: stopsWithCoords)
                    .accessibilityLabel("Route Map")
                    .ignoresSafeArea()
            } else {
                Color.black.opacity(0.9).ignoresSafeArea()
            }
        } else {
            Color.black.opacity(0.9).ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var bottomSheet: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            if let trip = viewModel.trip {
                header(for: trip)
            } else {
                // Title placeholder while loading
                Text("Trip Details")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            content
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
        .shadow(radius: 10)
    }

    @ViewBuilder
    private func header(for trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(trip.route.shortName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("to \(trip.headsign)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let firstStop = trip.stops.first {
                        Text("Commences from \(firstStop.stopName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            if !trip.stops.isEmpty {
                Text("\(trip.stops.count) stops")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading trip details...")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else if let trip = viewModel.trip {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(trip.stops.enumerated()), id: \.1.id) { index, tripStop in
                        TripStopRow(
                            tripStop: tripStop,
                            isFirst: index == 0,
                            isLast: index == trip.stops.count - 1
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 8)
            }
        } else {
            Text("No trip details available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
    }
}

struct TripStopRow: View {
    let tripStop: TripStop
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator (circle + vertical line)
            VStack(spacing: 0) {
                Circle()
                    .strokeBorder(Color.blue, lineWidth: 2)
                    .background(Circle().fill(Color.blue.opacity(0.9)))
                    .frame(width: 10, height: 10)
                    .padding(.top, isFirst ? 4 : 0)

                if !isLast {
                    Rectangle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Stop details
            VStack(alignment: .leading, spacing: 4) {
                Text(tripStop.stopName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let platform = tripStop.platform {
                        Text("Platform \(platform)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if tripStop.wheelchairAccessible == 1 {
                        Image(systemName: "figure.roll")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .accessibilityLabel("Wheelchair accessible")
                    }
                }
            }

            Spacer()

            // Arrival time + status
            VStack(alignment: .trailing, spacing: 4) {
                Text(tripStop.arrivalTime)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Scheduled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
