import Logging

extension Logger {
    /// App-wide logger instance
    static let app = Logger(label: "com.sydneytransit.app")

    /// Networking logger instance
    static let network = Logger(label: "com.sydneytransit.network")

    /// Database logger instance
    static let database = Logger(label: "com.sydneytransit.database")
}
