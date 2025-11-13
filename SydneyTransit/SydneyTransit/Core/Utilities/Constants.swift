import Foundation

enum Config {
    private static let config: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("Config.plist not found. Copy Config-Example.plist to Config.plist and fill in your values.")
        }
        return dict
    }()

    static var apiBaseURL: String {
        guard let url = config["API_BASE_URL"] as? String else {
            fatalError("API_BASE_URL not found in Config.plist")
        }
        return url
    }

    static var supabaseURL: String {
        guard let url = config["SUPABASE_URL"] as? String else {
            fatalError("SUPABASE_URL not found in Config.plist")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = config["SUPABASE_ANON_KEY"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Config.plist")
        }
        return key
    }

    static var logLevel: String {
        return config["LOG_LEVEL"] as? String ?? "info"
    }
}
