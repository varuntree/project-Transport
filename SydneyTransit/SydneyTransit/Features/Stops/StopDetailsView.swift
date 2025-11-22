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
                ZStack(alignment: .bottomTrailing) {
                    Map(coordinateRegion: .constant(region), annotationItems: [stop]) { stop in
                        MapMarker(coordinate: CLLocationCoordinate2D(
                            latitude: stop.stopLat,
                            longitude: stop.stopLon
                        ), tint: .red)
                    }
                    .frame(height: 250)
                    .cornerRadius(12)
                    
                    NavigationLink(destination: MapView(selectedStop: stop)) {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("View on Map")
                        }
                        .font(.footnote.bold())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                        .padding(8)
                    }
                }
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

                // Departures section - navigate to DeparturesView
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming Departures")
                        .font(.headline)
                        .padding(.horizontal)

                    NavigationLink {
                        DeparturesView(stop: stop)
                    } label: {
                        HStack {
                            Label("View Departures", systemImage: "clock")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
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
