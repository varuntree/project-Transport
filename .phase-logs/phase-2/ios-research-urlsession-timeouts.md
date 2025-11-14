# iOS Research: URLSession Timeout Configuration

## Key Pattern
URLSessionConfiguration provides two timeout types: `timeoutIntervalForRequest` (time waiting for data between packets) and `timeoutIntervalForResource` (total time for entire request). Default request timeout: 60s, resource timeout: 7 days. Align with backend soft_time_limit (Celery: 10s) to prevent client waiting for dead tasks.

## Code Example
```swift
import Foundation

class APIClient {
    static let shared = APIClient()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0  // Align with NSW API timeout (8s)
        config.timeoutIntervalForResource = 15.0  // Align with Celery hard timeout (15s)
        config.waitsForConnectivity = false  // Fail fast if offline

        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let (data, response) = try await session.data(for: endpoint.request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle timeout errors
        guard httpResponse.statusCode != 408 else {
            throw APIError.timeout
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

## Critical Constraints
- timeoutIntervalForRequest: time between receiving consecutive data packets (not total request time)
- timeoutIntervalForResource: total time for entire request (includes retries, redirects)
- Session copies configuration - changes after session creation have no effect
- URLError.timedOut thrown when timeout exceeded
- Timeout applies per request, not per URLSession

## Common Gotchas
- **Confusion between timeouts**: Request timeout ≠ resource timeout. Request resets on each packet, resource is absolute
- **Immutable config**: Modifying URLSessionConfiguration after URLSession init does nothing - must create new session
- **Default too long**: 60s request timeout unacceptable for real-time apps - set to backend timeout + network overhead (e.g., 10s Celery soft_time_limit → 12s client timeout)
- **waitsForConnectivity**: Default true (iOS 11+) - request queues until network available. Set false for fail-fast behavior

## API Reference
- Apple docs: https://developer.apple.com/documentation/foundation/urlsessionconfiguration
- Related APIs: URLSession, URLRequest, URLError, URLSessionConfiguration.waitsForConnectivity

## Relevance to Phase 2
Checkpoint 6 (DeparturesRepository): Set timeoutIntervalForRequest = 8s (matches NSW API fetch_gtfs_rt timeout), timeoutIntervalForResource = 15s (matches Celery hard timeout). Prevents iOS client waiting 60s for backend task killed at 15s. Graceful timeout handling shows error instead of hang.
