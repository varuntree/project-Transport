import SwiftUI
import MapKit
import Logging

struct TripDetailsView: View {
    let tripId: String
    @StateObject private var viewModel = TripDetailsViewModel()
    @State private var isSheetPresented = true

    var body: some View {
        TripMapView(stops: mapStops)
            .ignoresSafeArea()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await viewModel.loadTrip(id: tripId)
                }
            }
            .sheet(isPresented: $isSheetPresented) {
                TripDetailsSheetContent(viewModel: viewModel)
                    .presentationDetents([.fraction(0.15), .medium, .large])
                    .presentationDragIndicator(.visible)
                    .safePresentationBackgroundInteraction()
                    .safePresentationBackground()
                    .safePresentationCornerRadius()
                    .interactiveDismissDisabled()
            }
    }
    
    private var mapStops: [TripStop] {
        guard let trip = viewModel.trip else { return [] }
        return trip.stops.filter { $0.lat != nil && $0.lon != nil }
    }
}

struct TripDetailsSheetContent: View {
    @ObservedObject var viewModel: TripDetailsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if let trip = viewModel.trip {
                // Header - Always visible at top of sheet
                header(for: trip)
                    .padding(.top, 20) // Space for grabber
                    .padding(.bottom, 10)
                    .background(Color.clear) // Interactive drag area
                
                // Scrollable list of stops
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(trip.stops.enumerated()), id: \.element.id) { index, tripStop in
                            TripStopRow(
                                tripStop: tripStop,
                                isFirst: index == 0,
                                isLast: index == trip.stops.count - 1
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 30)
                }
            } else if viewModel.isLoading {
                ProgressView("Loading trip details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                 Text("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
                        .lineLimit(1)

                    if let firstStop = trip.stops.first {
                        Text("Commences from \(firstStop.stopName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            if !trip.stops.isEmpty {
                Text("\(trip.stops.count) stops")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

struct TripStopRow: View {
    let tripStop: TripStop
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        // Content
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(tripStop.stopName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(tripStop.arrivalTime)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(tripStop.realtime == true ? .primary : .secondary)

                        Text(tripStop.realtime == true ? "Actual" : "Scheduled")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Delay badge (if delayed)
                    if tripStop.isDelayed, let delayS = tripStop.delayS {
                        delayBadge(delayS: delayS)
                    }
                }
            }

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
        .padding(.bottom, 20)
        .padding(.leading, 32) // Reserve space for timeline
        .overlay(alignment: .leading) {
            StopTimelineView(isFirst: isFirst, isLast: isLast)
                .frame(width: 32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Computed Properties

    private var accessibilityText: String {
        var text = "\(tripStop.stopName), arrives at \(tripStop.arrivalTime)"

        if let platform = tripStop.platform {
            text += ", platform \(platform)"
        }

        if tripStop.isDelayed, let delayS = tripStop.delayS {
            let delayMin = abs(delayS) / 60
            if delayS < 0 {
                text += ", \(delayMin) minutes early"
            } else {
                text += ", \(delayMin) minutes late"
            }
        }

        if tripStop.wheelchairAccessible == 1 {
            text += ", wheelchair accessible"
        }

        return text
    }

    // MARK: - Delay Badge

    @ViewBuilder
    private func delayBadge(delayS: Int) -> some View {
        let delayMin = abs(delayS) / 60
        let isEarly = delayS < 0

        HStack(spacing: 2) {
            Text(isEarly ? "\(delayMin) min early" : "+\(delayMin) min")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(delayColor(delayS: delayS))
        .foregroundColor(.white)
        .cornerRadius(4)
        .accessibilityHidden(true)  // Already in accessibilityText
    }

    private func delayColor(delayS: Int) -> Color {
        if delayS < -60 {
            return .green  // Early >1 min
        } else if abs(delayS) <= 60 {
            return .gray   // On time ±1 min
        } else if delayS <= 300 {
            return .orange // Late 1-5 min
        } else {
            return .red    // Late >5 min
        }
    }
}

struct StopTimelineView: View {
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                let centerX: CGFloat = 16
                let topPadding: CGFloat = 4 // Approx text baseline offset or padding
                let dotSize: CGFloat = 12
                let dotCenterY = topPadding + (dotSize / 2)
                
                // Connect to previous stop (Line Up)
                if !isFirst {
                    Path { path in
                        path.move(to: CGPoint(x: centerX, y: 0))
                        path.addLine(to: CGPoint(x: centerX, y: dotCenterY))
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
                
                // Connect to next stop (Line Down)
                if !isLast {
                    Path { path in
                        path.move(to: CGPoint(x: centerX, y: dotCenterY))
                        path.addLine(to: CGPoint(x: centerX, y: geo.size.height))
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
                
                // The Dot
                Circle()
                    .fill(Color.blue)
                    .frame(width: dotSize, height: dotSize)
                    .position(x: centerX, y: dotCenterY)
            }
        }
    }
}

// MARK: - Extensions for iOS 16.4+ Compatibility
extension View {
    @ViewBuilder
    func safePresentationBackgroundInteraction() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackgroundInteraction(.enabled(upThrough: .medium))
        } else {
            self
        }
    }

    @ViewBuilder
    func safePresentationBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.ultraThinMaterial)
        } else {
            self
        }
    }

    @ViewBuilder
    func safePresentationCornerRadius() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(16)
        } else {
            self
        }
    }
}
