import Foundation
import NetworkExtension

final class TunnelController: ObservableObject {
    static let providerBundle = "app.vpnadmin.client.tunnel"

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    var onStatus: ((NEVPNStatus) -> Void)?

    func prepare() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            guard let self else { return }
            self.manager = managers?.first ?? NETunnelProviderManager()
            self.observe()
            DispatchQueue.main.async {
                self.onStatus?(self.manager?.connection.status ?? .invalid)
            }
        }
    }

    func isUp() -> Bool {
        manager?.connection.status == .connected
    }

    func connect(conf: String, endpoint: String, splitTunnel: SplitTunnelSettings = SplitTunnelSettings()) async throws {
        let routedConf = try splitTunnel.applyTo(conf)
        let exclusions = try SiteRouteResolver.resolve(domains: splitTunnel.bypassDomains)
        let finalConf = try RouteExclusions.apply(exclusions: exclusions, to: routedConf)
        try AppGroup.saveConfig(finalConf)
        try AppGroup.saveBypassRoutes(exclusions)
        let manager = try await loadOrCreate()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = Self.providerBundle
        proto.serverAddress = endpoint.isEmpty ? "VPN" : endpoint
        proto.providerConfiguration = ["hasConfig": NSNumber(value: true)]
        manager.protocolConfiguration = proto
        manager.localizedDescription = "Mvpn"
        manager.isEnabled = true
        try await save(manager)
        try await reload(manager)
        self.manager = manager
        observe()
        try manager.connection.startVPNTunnel()
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    func snapshot() async -> TrafficSnapshot {
        guard let session = manager?.connection as? NETunnelProviderSession else {
            return TrafficSnapshot(rxBytes: 0, txBytes: 0, handshakeEpochMillis: 0)
        }
        return await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(Data("stats".utf8)) { data in
                    continuation.resume(returning: TrafficSnapshot.parse(data))
                }
            } catch {
                continuation.resume(returning: TrafficSnapshot(rxBytes: 0, txBytes: 0, handshakeEpochMillis: 0))
            }
        }
    }

    private func observe() {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        guard let connection = manager?.connection else { return }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: .main
        ) { [weak self] _ in
            self?.onStatus?(connection.status)
        }
    }

    private func loadOrCreate() async throws -> NETunnelProviderManager {
        try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: managers?.first ?? NETunnelProviderManager())
            }
        }
    }

    private func save(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func reload(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

struct TrafficSnapshot {
    var rxBytes: Int64
    var txBytes: Int64
    var handshakeEpochMillis: Int64

    static func parse(_ data: Data?) -> TrafficSnapshot {
        guard let data, let text = String(data: data, encoding: .utf8) else {
            return TrafficSnapshot(rxBytes: 0, txBytes: 0, handshakeEpochMillis: 0)
        }
        var rx: Int64 = 0
        var tx: Int64 = 0
        var handshake: Int64 = 0
        for raw in text.split(separator: "\n") {
            let line = raw.split(separator: "=", maxSplits: 1)
            guard line.count == 2 else { continue }
            let value = Int64(line[1].trimmingCharacters(in: .whitespaces)) ?? 0
            switch line[0].trimmingCharacters(in: .whitespaces) {
            case "rx_bytes": rx += value
            case "tx_bytes": tx += value
            case "last_handshake_time_sec": handshake = max(handshake, value * 1000)
            default: break
            }
        }
        return TrafficSnapshot(rxBytes: rx, txBytes: tx, handshakeEpochMillis: handshake)
    }
}

enum TunnelMessage {
    static func userText(_ error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized
        }
        if error is AppGroupError {
            return "Не удалось подготовить подключение"
        }
        let ns = error as NSError
        if ns.domain == NEVPNErrorDomain {
            return "Разрешите создание VPN-подключения"
        }
        return "Не удалось подключиться"
    }
}
