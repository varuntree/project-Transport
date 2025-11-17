import SwiftUI
import Logging

struct RouteListView: View {
    @State private var routesByType: [RouteType: [Route]] = [:]
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading routes...")
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(sortedRouteTypes(), id: \.self) { routeType in
                        if let routes = routesByType[routeType], !routes.isEmpty {
                            Section {
                                ForEach(routes) { route in
                                    RouteRow(route: route)
                                }
                            } header: {
                                HStack(spacing: 8) {
                                    // Route type badge
                                    Text(routeType.displayName.uppercased())
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(routeType.color)
                                        .cornerRadius(4)

                                    Text("(\(routes.count))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("All Routes")
        .task {
            await loadRoutes()
        }
    }

    private func sortedRouteTypes() -> [RouteType] {
        // Sort by display priority (rail, metro, bus, ferry, tram, others)
        let priority: [RouteType] = [.rail, .metro, .bus, .ferry, .tram]
        var types = Array(routesByType.keys)
        types.sort { type1, type2 in
            let index1 = priority.firstIndex(of: type1) ?? Int.max
            let index2 = priority.firstIndex(of: type2) ?? Int.max
            return index1 < index2
        }
        return types
    }

    @MainActor
    private func loadRoutes() async {
        isLoading = true
        errorMessage = nil

        let startTime = Date()

        do {
            let routes = try DatabaseManager.shared.read { db in
                try Route.fetchAll(db)
            }

            // Group routes by type
            routesByType = Dictionary(grouping: routes, by: \.type)

            let duration = Date().timeIntervalSince(startTime) * 1000 // ms

            Logger.database.info("routes_loaded", metadata: [
                "total_count": "\(routes.count)",
                "types_count": "\(routesByType.keys.count)",
                "duration_ms": "\(Int(duration))"
            ])

            isLoading = false

        } catch {
            Logger.database.error("routes_load_failed", metadata: [
                "error": "\(error.localizedDescription)"
            ])

            errorMessage = "Failed to load routes: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

struct RouteRow: View {
    let route: Route

    var body: some View {
        HStack(spacing: 12) {
            // Route type color indicator
            Circle()
                .fill(route.type.color)
                .frame(width: 12, height: 12)

            // Route short name badge
            Text(route.displayName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(routeColor)
                .cornerRadius(4)

            // Route long name
            VStack(alignment: .leading, spacing: 2) {
                Text(route.displayLongName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(route.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var routeColor: Color {
        if let colorHex = route.routeColor, !colorHex.isEmpty {
            return Color(hex: colorHex) ?? route.type.color
        }
        return route.type.color
    }
}

// Color hex extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

#Preview {
    NavigationStack {
        RouteListView()
    }
}
