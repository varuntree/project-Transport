# Checkpoint 11: Integration Test (iOS → Backend)

## Goal
iOS app fetches data from local backend GET / endpoint, displays "Sydney Transit API" message in HomeView.

## Approach

### Backend Implementation
None (backend must be running from checkpoint 5)

### iOS Implementation

**Update `SydneyTransit/Features/Home/HomeView.swift`:**

```swift
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
```

**Critical patterns:**
- Use async/await URLSession (not completion handlers)
- Parse API envelope: `{"data": {"message": "..."}, "meta": {}}`
- Handle errors gracefully (display error message)
- Log network requests with metadata
- Use .task modifier (runs on view appear, iOS 15+)

### iOS Implementation
Update HomeView.swift as described above.

## Design Constraints
- Use URLSession with async/await (iOS 15+)
- Parse JSON manually (no Codable for simple test)
- Handle errors: display error message if backend unreachable
- Log requests/errors with Logger.network
- Root endpoint is `/` (not `/api/v1`)

## Risks
- Backend not running → "Backend unreachable" error
  - Mitigation: Instructions say "Start backend first"
- Wrong URL format → Check Config.apiBaseURL
  - Mitigation: Strip /api/v1 suffix to get root URL
- CORS blocks request → Backend CORS allows localhost
  - Mitigation: Checkpoint 5 configured CORS correctly

## Validation
```bash
# 1. Start backend:
cd backend
uvicorn app.main:app --reload

# 2. Run iOS app (Cmd+R in Xcode)

# Expected:
# - HomeView displays "Sydney Transit API" (fetched from GET / endpoint)
# - Xcode console shows:
#   - "Fetching backend status" log
#   - "Backend status fetched" log with message metadata
# - No errors in console
```

## References for Subagent
- Integration: INTEGRATION_CONTRACTS.md:Section 1 (REST API)
- API envelope: DEVELOPMENT_STANDARDS.md:L360-411

## Estimated Complexity
**moderate** - Async networking, JSON parsing, error handling, logging

## Previous Checkpoint Context
Checkpoint 10 created HomeView with static UI. This checkpoint adds network fetch on view appear.
