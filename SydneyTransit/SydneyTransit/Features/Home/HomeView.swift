import SwiftUI
import Logging

struct HomeView: View {
    @State private var apiStatus: String = "Checking backend..."
    @State private var isLoading: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Sydney Transit")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Phase 0: Foundation")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Divider()
                    .padding(.vertical)

                // Integration test status
                VStack(spacing: 10) {
                    Text("Backend Status:")
                        .font(.headline)

                    if isLoading {
                        ProgressView()
                    } else {
                        Text(apiStatus)
                            .font(.body)
                            .foregroundColor(apiStatus.contains("Sydney Transit API") ? .green : .red)
                    }
                }

                Divider()
                    .padding(.vertical)

                // Phase 1: Search functionality
                NavigationLink {
                    SearchView()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search Stops")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                // Phase 1: Route list
                NavigationLink {
                    RouteListView()
                } label: {
                    HStack {
                        Image(systemName: "tram.fill")
                        Text("All Routes")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Home")
            .task {
                await fetchBackendStatus()
            }
        }
    }

    private func fetchBackendStatus() async {
        isLoading = true

        do {
            // Construct root URL (not /api/v1, just /)
            let baseURL = Config.apiBaseURL
            let rootURL = baseURL.replacingOccurrences(of: "/api/v1", with: "")

            guard let url = URL(string: rootURL) else {
                apiStatus = "Invalid URL"
                isLoading = false
                return
            }

            Logger.network.info("Fetching backend status", metadata: ["url": "\(url)"])

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                apiStatus = "Backend returned error"
                isLoading = false
                return
            }

            // Parse JSON response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let message = dataDict["message"] as? String {
                apiStatus = message // "Sydney Transit API"
                Logger.network.info("Backend status fetched", metadata: ["message": "\(message)"])
            } else {
                apiStatus = "Invalid response format"
            }

        } catch {
            apiStatus = "Backend unreachable: \(error.localizedDescription)"
            Logger.network.error("Failed to fetch backend status", metadata: ["error": "\(error)"])
        }

        isLoading = false
    }
}

#Preview {
    HomeView()
}
