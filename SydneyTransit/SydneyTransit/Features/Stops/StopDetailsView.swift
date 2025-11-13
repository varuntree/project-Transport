import SwiftUI
import MapKit

struct StopDetailsView: View {
    let stop: Stop

    @State private var region: MKCoordinateRegion

    init(stop: Stop) {
        self.stop = stop
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: stop.stopLat, longitude: stop.stopLon),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Stop info section
                VStack(alignment: .leading, spacing: 8) {
                    Text(stop.stopName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let stopCode = stop.stopCode {
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(.secondary)
                            Text("Stop Code: \(stopCode)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.6f, %.6f", stop.stopLat, stop.stopLon))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let wheelchairBoarding = stop.wheelchairBoarding, wheelchairBoarding == 1 {
                        HStack {
                            Image(systemName: "figure.roll")
                                .foregroundColor(.blue)
                            Text("Wheelchair accessible")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()

                // Map section
                Map(coordinateRegion: .constant(region), annotationItems: [stop]) { stop in
                    MapMarker(coordinate: CLLocationCoordinate2D(
                        latitude: stop.stopLat,
                        longitude: stop.stopLon
                    ), tint: .red)
                }
                .frame(height: 250)
                .cornerRadius(12)
                .padding(.horizontal)

                // Share button
                HStack {
                    Spacer()
                    ShareLink(
                        item: appleMapsURL,
                        subject: Text(stop.stopName),
                        message: Text("Check out \(stop.stopName) at \(String(format: "%.6f, %.6f", stop.stopLat, stop.stopLon))")
                    ) {
                        Label("Share Location", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding()

                // Mock departures section (Phase 2 placeholder)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming Departures")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        Text("Real-time departures coming in Phase 2")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .padding()

                        // Mock departure examples
                        DeparturePlaceholderRow(route: "T1", destination: "Richmond", time: "3 min")
                        DeparturePlaceholderRow(route: "T1", destination: "Emu Plains", time: "8 min")
                        DeparturePlaceholderRow(route: "T2", destination: "Parramatta", time: "12 min")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Stop Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appleMapsURL: URL {
        let query = "\(stop.stopLat),\(stop.stopLon)"
        let urlString = "http://maps.apple.com/?q=\(stop.stopName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&ll=\(query)"
        return URL(string: urlString) ?? URL(string: "http://maps.apple.com")!
    }
}

// Mock departure row
struct DeparturePlaceholderRow: View {
    let route: String
    let destination: String
    let time: String

    var body: some View {
        HStack {
            // Route badge
            Text(route)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray)
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 2) {
                Text(destination)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Platform TBA")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(time)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        StopDetailsView(stop: Stop(
            sid: 1,
            stopCode: "2000001",
            stopName: "Central Station",
            stopLat: -33.8833,
            stopLon: 151.2067,
            wheelchairBoarding: 1
        ))
    }
}
