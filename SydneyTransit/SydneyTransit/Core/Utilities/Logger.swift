import Logging

extension Logger {
    /// App-wide logger instance
    static let app = Logger(label: "com.sydneytransit.app")

    /// Networking logger instance
    static let network = Logger(label: "com.sydneytransit.network")

    /// Database logger instance
    static let database = Logger(label: "com.sydneytransit.database")
}

extension Logger.Metadata {
    /// Convenience to build metadata from string-convertible values without verbose `.stringConvertible` calls.
    static func from(_ values: [String: CustomStringConvertible]) -> Logger.Metadata {
        values.reduce(into: Logger.Metadata()) { result, entry in
            result[entry.key] = .stringConvertible(entry.value)
        }
    }
}
