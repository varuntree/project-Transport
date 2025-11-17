import SwiftUI
import Logging

struct RouteListView: View {
    @State private var routesByType: [RouteType: [Route]] = [:]
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var selectedMode: RouteType? = nil // nil = "All"

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
                VStack(spacing: 0) {
                    // Modality filter segmented control
                    Picker("Transport Mode", selection: $selectedMode) {
                        Text("All").tag(RouteType?.none)
                        ForEach(visibleRouteTypes(), id: \.self) { type in
                            Text(type.displayName).tag(type as RouteType?)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // Filtered route list with alphabetical sections
                    let sections = alphabeticalSections()
                    let sortedLetters = sections.keys.sorted()

                    if #available(iOS 26, *) {
                        List {
                            ForEach(sortedLetters, id: \.self) { letter in
                                Section {
                                    ForEach(sections[letter]!) { route in
                                        RouteRow(route: route)
                                    }
                                } header: {
                                    Text(letter)
                                        .font(.headline)
                                }
                                .sectionIndexLabel(letter)
                            }
                        }
                        .listSectionIndexVisibility(.automatic)
                    } else {
                        // iOS <26 fallback: sections without index
                        List {
                            ForEach(sortedLetters, id: \.self) { letter in
                                Section {
                                    ForEach(sections[letter]!) { route in
                                        RouteRow(route: route)
                                    }
                                } header: {
                                    Text(letter)
                                        .font(.headline)
                                }
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

    // Returns route types to show in segmented control (only types with actual routes)
    private func visibleRouteTypes() -> [RouteType] {
        let priority: [RouteType] = [.rail, .metro, .bus, .ferry, .tram]
        return priority.filter { routesByType[$0]?.isEmpty == false }
    }

    // Returns filtered routes based on selected mode
    private func filteredRoutes() -> [Route] {
        if let selectedMode = selectedMode {
            // Show only routes of selected type
            return routesByType[selectedMode] ?? []
        } else {
            // Show all routes
            return routesByType.values.flatMap { $0 }
        }
    }

    // Groups filtered routes alphabetically by first letter
    private func alphabeticalSections() -> [String: [Route]] {
        let routes = filteredRoutes()

        // Sort routes alphabetically
        let sortedRoutes = routes.sorted { $0.displayName < $1.displayName }

        // Group by first letter (uppercase)
        let sections = Dictionary(grouping: sortedRoutes) { route in
            let firstChar = route.displayName.prefix(1).uppercased()
            // Check if first character is a letter
            if firstChar.rangeOfCharacter(from: .letters) != nil {
                return firstChar
            } else {
                // Numeric or symbol routes go under "#"
                return "#"
            }
        }

        return sections
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
