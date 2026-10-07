import Foundation

struct StoredServer: Identifiable, Equatable {
    var id: String
    var key: ImportedKey
}

struct ServerLibrary {
    var servers: [StoredServer]
    var activeId: String?
}

struct ProfileStore {
    private let file: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folder = base.appendingPathComponent("VPNClient", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("servers.json")
    }

    func load() -> ServerLibrary {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ServerLibrary(servers: [], activeId: nil)
        }
        return read(json)
    }

    func add(_ key: ImportedKey) -> ServerLibrary {
        var current = load()
        let server = StoredServer(id: UUID().uuidString, key: key)
        current.servers.append(server)
        return write(current.servers, activeId: server.id)
    }

    func setActive(_ id: String) -> ServerLibrary {
        let current = load()
        guard current.servers.contains(where: { $0.id == id }) else { return current }
        return write(current.servers, activeId: id)
    }

    func delete(_ id: String) -> ServerLibrary {
        let current = load()
        let servers = current.servers.filter { $0.id != id }
        let active = current.activeId == id ? servers.first?.id : current.activeId
        return write(servers, activeId: active)
    }

    private func write(_ servers: [StoredServer], activeId: String?) -> ServerLibrary {
        let chosen = activeId.flatMap { id in servers.contains(where: { $0.id == id }) ? id : nil } ?? servers.first?.id
        let payload: [String: Any] = [
            "active": chosen as Any? ?? NSNull(),
            "servers": servers.map { server in
                [
                    "id": server.id,
                    "title": server.key.title,
                    "endpoint": server.key.endpoint,
                    "address": server.key.address,
                    "dns": server.key.dns,
                    "protocol": server.key.protocolName,
                    "conf": server.key.conf,
                ]
            },
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? data.write(to: file, options: .atomic)
        }
        return ServerLibrary(servers: servers, activeId: chosen)
    }

    private func read(_ json: [String: Any]) -> ServerLibrary {
        let rows = json["servers"] as? [[String: Any]] ?? []
        let servers: [StoredServer] = rows.compactMap { item in
            let conf = item["conf"] as? String ?? ""
            guard !conf.isEmpty else { return nil }
            let id = (item["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString
            let dns = (item["dns"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "—"
            let protocolName = (item["protocol"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "AmneziaWG"
            return StoredServer(
                id: id,
                key: ImportedKey(
                    title: (item["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "VPN",
                    conf: conf,
                    endpoint: item["endpoint"] as? String ?? "",
                    address: item["address"] as? String ?? "",
                    dns: dns,
                    protocolName: protocolName
                )
            )
        }
        let requested = json["active"] as? String
        let active = requested.flatMap { id in servers.contains(where: { $0.id == id }) ? id : nil } ?? servers.first?.id
        return ServerLibrary(servers: servers, activeId: active)
    }
}
