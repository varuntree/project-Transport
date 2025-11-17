import SwiftUI

struct DeparturesView: View {
    let stop: Stop
    @StateObject private var viewModel = DeparturesViewModel()

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.departures.isEmpty {
                ProgressView("Loading departures...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.departures) { departure in
                    NavigationLink(value: departure) {
                        DepartureRow(departure: departure)
                    }
                }
            }
        }
        .navigationTitle("Departures")
        .navigationDestination(for: Departure.self) { departure in
            TripDetailsView(tripId: departure.tripId)
        }
        .refreshable {
            await viewModel.loadDepartures(stopId: String(stop.sid))
        }
        .onAppear {
            Task {
                await viewModel.loadDepartures(stopId: String(stop.sid))
            }
            viewModel.startAutoRefresh(stopId: String(stop.sid))
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
            // Route badge (blue circle with route number)
            Text(departure.routeShortName)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.blue)
                .clipShape(Circle())

            // Headsign + platform + delay text
            VStack(alignment: .leading, spacing: 4) {
                Text(departure.headsign)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let platform = departure.platform {
                        Text("Platform \(platform)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let delayText = departure.delayText {
                        Text(delayText)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            // Wheelchair icon (if accessible)
            if departure.wheelchairAccessible == 1 {
                Image(systemName: "figure.roll")
                    .foregroundColor(.blue)
                    .font(.body)
                    .accessibilityLabel("Wheelchair accessible")
            }

            // Countdown + departure time
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(departure.minutesUntil) min")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(departure.departureTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
