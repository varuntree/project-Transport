import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case timeout
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .timeout:
            return "Request timed out"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        }
    }
}

enum APIEndpoint {
    case getDepartures(stopId: String, timeSecs: Int? = nil, direction: String = "future", limit: Int = 10)
    case getTrip(tripId: String)

    var path: String {
        switch self {
        case .getDepartures(let stopId, _, _, _):
            return "/stops/\(stopId)/departures"
        case .getTrip(let tripId):
            return "/trips/\(tripId)"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .getDepartures(_, let timeSecs, let direction, let limit):
            var items = [
                URLQueryItem(name: "direction", value: direction),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let timeSecs = timeSecs {
                items.append(URLQueryItem(name: "time", value: "\(timeSecs)"))
            }
            return items
        case .getTrip:
            return nil
        }
    }

    var method: String {
        switch self {
        case .getDepartures, .getTrip:
            return "GET"
        }
    }

    func request(baseURL: String) -> URLRequest {
        var components = URLComponents(string: baseURL + path)!
        components.queryItems = queryItems
        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: String

    init(baseURL: String? = nil) {
        // URLSession config with timeouts aligned to backend (8s request, 15s resource)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0  // NSW API timeout
        config.timeoutIntervalForResource = 15.0  // Celery hard timeout
        config.waitsForConnectivity = false  // Fail fast if offline

        self.session = URLSession(configuration: config)
        self.baseURL = baseURL ?? Config.apiBaseURL
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let urlRequest = endpoint.request(baseURL: baseURL)

        #if DEBUG
        print("[APIClient] Request URL: \(urlRequest.url?.absoluteString ?? "nil")")
        assert(!urlRequest.url!.absoluteString.contains("/api/v1/api/v1"), "Double /api/v1 prefix detected!")
        #endif

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Handle timeout
            if httpResponse.statusCode == 408 {
                throw APIError.timeout
            }

            // Handle server errors
            if httpResponse.statusCode >= 400 {
                let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                throw APIError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorMessage?.error.message
                )
            }

            // Decode response
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }

        } catch let error as APIError {
            throw error
        } catch {
            if let urlError = error as? URLError {
                if urlError.code == .timedOut {
                    throw APIError.timeout
                }
            }
            throw APIError.networkError(error)
        }
    }

    /// Generic GET request for custom endpoints
    /// - Parameter path: URL path (e.g., "/stops/123/alerts")
    /// - Returns: Decoded response of type T
    func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        print("[APIClient] GET URL: \(url.absoluteString)")
        #endif

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Handle timeout
            if httpResponse.statusCode == 408 {
                throw APIError.timeout
            }

            // Handle server errors
            if httpResponse.statusCode >= 400 {
                let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                throw APIError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorMessage?.error.message
                )
            }

            // Decode response
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }

        } catch let error as APIError {
            throw error
        } catch {
            if let urlError = error as? URLError {
                if urlError.code == .timedOut {
                    throw APIError.timeout
                }
            }
            throw APIError.networkError(error)
        }
    }
}

// Error response structure (matches backend envelope)
private struct ErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let code: String
        let message: String
        let details: [String: String]?
    }
}
