import SwiftUI
import Logging

/// Bottom drawer showing stop details and static departures
/// Supports 3 detent states: collapsed (.fraction(0.15)), half (.medium), full (.large)
struct StopDetailsDrawer: View {
    let stop: Stop
    let departures: [Departure]
    let isLoading: Bool
    let errorMessage: String?

    @Environment(\.presentationDetent) private var detent

    var body: some View {
        VStack(spacing: 0) {
            // Header - Always visible at top
            header
                .padding(.top, 20) // Space for grabber
                .padding(.bottom, 12)
                .background(Color.clear) // Interactive drag area

            // Content adapts to detent state
            content
        }
    }

    // MARK: - Header (Collapsed State)

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            // Transport icon
            Image(systemName: stop.transportIcon)
                .foregroundColor(iconColor)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.2))
                .clipShape(Circle())
                .accessibilityLabel(stop.routeTypeDisplayName)

            // Stop name
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.stopName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // Route type badge (only show at collapsed state for compactness)
                if detent == .fraction(0.15) {
                    Text(stop.routeTypeDisplayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Content (Detent-Adaptive)

    @ViewBuilder
    private var content: some View {
        if detent == .fraction(0.15) {
            // Collapsed: header only, no additional content
            Spacer()
        } else if detent == .medium {
            // Half: next 3 departures (non-scrollable)
            halfDetentContent
        } else {
            // Full: scrollable 20 departures
            fullDetentContent
        }
    }

    // MARK: - Half Detent Content

    @ViewBuilder
    private var halfDetentContent: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading departures...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if departures.isEmpty {
                emptyStateView
            } else {
                // Fixed-height content: next 3 departures
                VStack(spacing: 0) {
                    ForEach(departures.prefix(3)) { departure in
                        DepartureCompactRow(departure: departure)

                        if departure.id != departures.prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Full Detent Content

    @ViewBuilder
    private var fullDetentContent: some View {
        if isLoading {
            ProgressView("Loading departures...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else if let errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else if departures.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(departures.prefix(20)) { departure in
                        VStack(spacing: 0) {
                            DepartureCompactRow(departure: departure)
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.xmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No upcoming departures")
                .font(.headline)
                .foregroundColor(.primary)

            Text("No services scheduled at this time")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private var iconColor: Color {
        switch stop.primaryRouteType {
        case 2: return .yellow           // Train
        case 401, 1: return .red         // Metro
        case 0, 900: return .green       // Light Rail
        case 4: return .teal             // Ferry
        case 3, 700, 712, 714: return .blue  // Bus
        default: return .gray            // Unknown
        }
    }
}

/// Compact departure row for drawer (smaller than full DepartureRow)
struct DepartureCompactRow: View {
    let departure: Departure

    var body: some View {
        HStack(spacing: 12) {
            // Minutes countdown
            VStack(alignment: .leading, spacing: 2) {
                Text(departure.minutesUntilText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(departure.departureTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 65, alignment: .leading)

            // Route badge
            Text(departure.routeShortName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue)
                .cornerRadius(6)

            // Headsign
            VStack(alignment: .leading, spacing: 2) {
                Text("to \(departure.headsign)")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                // Always show "Scheduled" for offline mode
                Text("Scheduled")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Wheelchair icon
            if departure.wheelchairAccessible == 1 {
                Image(systemName: "figure.roll")
                    .foregroundColor(.blue)
                    .font(.caption)
                    .accessibilityLabel("Wheelchair accessible")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    // Mock data
    let mockStop = Stop(
        sid: 1,
        stopCode: "200060",
        stopName: "Central Station",
        stopLat: -33.8831,
        stopLon: 151.2065,
        wheelchairBoarding: 1
    )

    let mockDepartures = [
        Departure(
            tripId: "trip1",
            routeShortName: "T2",
            headsign: "Parramatta",
            scheduledTimeSecs: 36000,
            realtimeTimeSecs: 36000,
            delayS: 0,
            realtime: false,
            platform: "1",
            wheelchairAccessible: 1,
            occupancy_status: nil
        ),
        Departure(
            tripId: "trip2",
            routeShortName: "T4",
            headsign: "Bondi Junction",
            scheduledTimeSecs: 36300,
            realtimeTimeSecs: 36300,
            delayS: 0,
            realtime: false,
            platform: "2",
            wheelchairAccessible: 1,
            occupancy_status: nil
        )
    ]

    return StopDetailsDrawer(
        stop: mockStop,
        departures: mockDepartures,
        isLoading: false,
        errorMessage: nil
    )
}
