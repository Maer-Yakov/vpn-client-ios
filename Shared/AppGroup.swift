import Foundation

enum AppGroup {
    static let identifier = "group.app.vpnadmin.client"
    static let configName = "active.conf"
    static let bypassName = "bypass-routes.json"

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

    static func saveBypassRoutes(_ routes: [InetNetwork]) throws {
        guard let url = container?.appendingPathComponent(bypassName) else {
            throw AppGroupError.unavailable
        }
        let payload = routes.map(\.cidr)
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    static func readBypassRoutes() -> [InetNetwork] {
        guard let url = container?.appendingPathComponent(bypassName),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return rows.compactMap { try? InetNetwork.parse($0) }
    }
}

enum AppGroupError: Error {
    case unavailable
}
