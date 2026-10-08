import Foundation

struct StoredServer: Identifiable, Equatable {
    var id: String
    var key: ImportedKey
    var splitTunnel: SplitTunnelSettings = SplitTunnelSettings()
}

struct ServerLibrary {
    var servers: [StoredServer]
    var activeId: String?
    var warning: String? = nil
}

struct ProfileStore {
    static let backupFormat = "mvpn-backup"
    static let backupVersion = 1

    private let file: URL
    private let temporaryFile: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folder = base.appendingPathComponent("VPNClient", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("servers.json")
        temporaryFile = folder.appendingPathComponent("servers.json.tmp")
    }

    func load() -> ServerLibrary {
        if let recovery = recoverPendingWrite() {
            return ServerLibrary(servers: [], activeId: nil, warning: recovery)
        }
        guard fileManager.fileExists(atPath: file.path) else {
            return ServerLibrary(servers: [], activeId: nil)
        }
        do {
            let data = try Data(contentsOf: file)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ProfileStoreError.corrupt
            }
            return Self.readLibrary(json)
        } catch {
            let backup = file.deletingLastPathComponent().appendingPathComponent("servers.json.corrupt")
            let preserved = (try? fileManager.copyItem(at: file, to: backup)) != nil
            let warning = preserved
                ? "Файл профилей повреждён. Копия сохранена: \(backup.lastPathComponent)"
                : "Файл профилей повреждён и не может быть прочитан"
            return ServerLibrary(servers: [], activeId: nil, warning: warning)
        }
    }

    func add(_ key: ImportedKey) throws -> ServerLibrary {
        let current = try requireWritable(load())
        let server = StoredServer(id: UUID().uuidString, key: key)
        return try write(current.servers + [server], activeId: server.id)
    }

    func setActive(_ id: String) throws -> ServerLibrary {
        let current = try requireWritable(load())
        guard current.servers.contains(where: { $0.id == id }) else { return current }
        return try write(current.servers, activeId: id)
    }

    func setSplitTunnel(id: String, settings: SplitTunnelSettings) throws -> ServerLibrary {
        let current = try requireWritable(load())
        guard current.servers.contains(where: { $0.id == id }) else { return current }
        let servers = current.servers.map { server in
            server.id == id ? StoredServer(id: server.id, key: server.key, splitTunnel: settings) : server
        }
        return try write(servers, activeId: current.activeId)
    }

    func setExpiresAt(id: String, expiresAtMillis: Int64?) throws -> ServerLibrary {
        let current = try requireWritable(load())
        guard current.servers.contains(where: { $0.id == id }) else { return current }
        let servers = current.servers.map { server -> StoredServer in
            guard server.id == id else { return server }
            var key = server.key
            key.expiresAtMillis = (expiresAtMillis ?? 0) > 0 ? expiresAtMillis : nil
            return StoredServer(id: server.id, key: key, splitTunnel: server.splitTunnel)
        }
        return try write(servers, activeId: current.activeId)
    }

    func delete(_ id: String) throws -> ServerLibrary {
        let current = try requireWritable(load())
        let servers = current.servers.filter { $0.id != id }
        let active = current.activeId == id ? servers.first?.id : current.activeId
        return try write(servers, activeId: active)
    }

    func exportBackup() throws -> String {
        let current = try requireWritable(load())
        return Self.encodeBackup(servers: current.servers, activeId: current.activeId)
    }

    func importBackup(_ raw: String) throws -> ServerLibrary {
        _ = try requireWritable(load())
        let parsed = try Self.decodeBackup(raw)
        guard !parsed.servers.isEmpty else {
            throw ProfileStoreError.message("В файле нет серверов")
        }
        return try write(parsed.servers, activeId: parsed.activeId)
    }

    static func encodeBackup(servers: [StoredServer], activeId: String?) -> String {
        let chosen = activeId.flatMap { id in servers.contains(where: { $0.id == id }) ? id : nil } ?? servers.first?.id
        let payload: [String: Any] = [
            "format": backupFormat,
            "version": backupVersion,
            "active": chosen as Any? ?? NSNull(),
            "servers": serversToJSON(servers),
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    static func decodeBackup(_ raw: String) throws -> ServerLibrary {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{FEFF}", with: "")
        guard !text.isEmpty else { throw ProfileStoreError.message("Файл пуст") }
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProfileStoreError.message("Файл конфигурации повреждён")
        }
        let format = json["format"] as? String ?? ""
        if !format.isEmpty, format != backupFormat {
            throw ProfileStoreError.message("Это не файл конфигурации Mvpn")
        }
        let version = json["version"] as? Int ?? 1
        guard (1...backupVersion).contains(version) else {
            throw ProfileStoreError.message("Неподдерживаемая версия файла конфигурации")
        }
        return readLibrary(json)
    }

    private func write(_ servers: [StoredServer], activeId: String?) throws -> ServerLibrary {
        let chosen = activeId.flatMap { id in servers.contains(where: { $0.id == id }) ? id : nil } ?? servers.first?.id
        let payload: [String: Any] = [
            "active": chosen as Any? ?? NSNull(),
            "servers": Self.serversToJSON(servers),
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: temporaryFile, options: .atomic)
        if fileManager.fileExists(atPath: file.path) {
            try fileManager.removeItem(at: file)
        }
        try fileManager.moveItem(at: temporaryFile, to: file)
        return ServerLibrary(servers: servers, activeId: chosen)
    }

    private func recoverPendingWrite() -> String? {
        guard fileManager.fileExists(atPath: temporaryFile.path) else { return nil }
        if fileManager.fileExists(atPath: file.path) {
            try? fileManager.removeItem(at: temporaryFile)
            return nil
        }
        do {
            try fileManager.moveItem(at: temporaryFile, to: file)
            return nil
        } catch {
            return "Не удалось восстановить временный файл профилей"
        }
    }

    private func requireWritable(_ library: ServerLibrary) throws -> ServerLibrary {
        if let warning = library.warning {
            throw ProfileStoreError.message(warning)
        }
        return library
    }

    private static func serversToJSON(_ servers: [StoredServer]) -> [[String: Any]] {
        servers.map { server in
            [
                "id": server.id,
                "title": server.key.title,
                "endpoint": server.key.endpoint,
                "address": server.key.address,
                "dns": server.key.dns,
                "protocol": server.key.protocolName,
                "conf": server.key.conf,
                "expiresAt": server.key.expiresAtMillis as Any? ?? NSNull(),
                "panelUrl": server.key.panelUrl as Any? ?? NSNull(),
                "splitMode": server.splitTunnel.mode.rawValue,
                "splitPackages": server.splitTunnel.packages.sorted(),
                "bypassDomains": server.splitTunnel.bypassDomains.sorted(),
            ]
        }
    }

    private static func readLibrary(_ json: [String: Any]) -> ServerLibrary {
        let rows = json["servers"] as? [[String: Any]] ?? []
        let servers: [StoredServer] = rows.compactMap { item in
            let conf = item["conf"] as? String ?? ""
            guard !conf.isEmpty else { return nil }
            let id = (item["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString
            let dns = (item["dns"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "—"
            let protocolName = (item["protocol"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "AmneziaWG"
            let storedExpiry: Int64?
            if item["expiresAt"] is NSNull || item["expiresAt"] == nil {
                storedExpiry = nil
            } else if let text = item["expiresAt"] as? String {
                storedExpiry = SubscriptionExpiry.parseIsoToMillis(text)
            } else if let number = item["expiresAt"] as? Int64 {
                storedExpiry = number > 0 ? number : nil
            } else if let number = item["expiresAt"] as? Int {
                storedExpiry = number > 0 ? Int64(number) : nil
            } else if let number = item["expiresAt"] as? Double {
                storedExpiry = number > 0 ? Int64(number) : nil
            } else {
                storedExpiry = nil
            }
            let panel = (item["panelUrl"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let packages = Set(((item["splitPackages"] as? [String]) ?? []).filter(SplitTunnelSettings.isValidPackageName))
            let domains = Set(((item["bypassDomains"] as? [String]) ?? []).compactMap { raw in
                try? SiteDomain.normalize(raw)
            })
            return StoredServer(
                id: id,
                key: ImportedKey(
                    title: (item["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "VPN",
                    conf: conf,
                    endpoint: item["endpoint"] as? String ?? "",
                    address: item["address"] as? String ?? "",
                    dns: dns,
                    protocolName: protocolName,
                    expiresAtMillis: storedExpiry ?? SubscriptionExpiry.parseIsoToMillis(expiresLine(from: conf)),
                    panelUrl: (panel?.isEmpty == false) ? panel : nil
                ),
                splitTunnel: SplitTunnelSettings(
                    mode: AppRouteMode.parse(item["splitMode"] as? String),
                    packages: packages,
                    bypassDomains: domains
                )
            )
        }
        let requested = json["active"] as? String
        let active = requested.flatMap { id in servers.contains(where: { $0.id == id }) ? id : nil } ?? servers.first?.id
        return ServerLibrary(servers: servers, activeId: active)
    }

    private static func expiresLine(from conf: String) -> String? {
        for raw in conf.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let body = line.hasPrefix("#") ? String(line.dropFirst()).trimmingCharacters(in: .whitespaces) : line
            if body.lowercased().hasPrefix("expiresat") {
                return body.split(separator: "=", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        return nil
    }
}

enum ProfileStoreError: Error, LocalizedError {
    case corrupt
    case message(String)

    var errorDescription: String? {
        switch self {
        case .corrupt: return "Файл профилей повреждён"
        case .message(let text): return text
        }
    }
}
