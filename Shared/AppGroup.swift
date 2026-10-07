import Foundation

enum AppGroup {
    static let identifier = "group.app.vpnadmin.client"
    static let configName = "active.conf"

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static func saveConfig(_ conf: String) throws {
        guard let url = container?.appendingPathComponent(configName) else {
            throw AppGroupError.unavailable
        }
        try Data(conf.utf8).write(to: url, options: .atomic)
    }

    static func readConfig() -> String? {
        guard let url = container?.appendingPathComponent(configName) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

enum AppGroupError: Error {
    case unavailable
}
