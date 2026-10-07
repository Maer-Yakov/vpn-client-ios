import Foundation
import NetworkExtension

enum Phase {
    case idle
    case connecting
    case connected
}

enum Screen {
    case home
    case servers
    case importKey
    case scan
    case settings
}

@MainActor
final class AppModel: ObservableObject {
    @Published var servers: [StoredServer] = []
    @Published var activeId: String?
    @Published var screen: Screen = .home
    @Published var draft = ""
    @Published var phase: Phase = .idle
    @Published var error: String?
    @Published var rxBytes: Int64 = 0
    @Published var txBytes: Int64 = 0
    @Published var handshake = "—"
    @Published var connectedSince: Date?
    @Published var now = Date()

    let tunnels = TunnelController()
    private let store = ProfileStore()
    private let sinceKey = "connected_since"
    private var tick = 0

    var active: StoredServer? {
        servers.first { $0.id == activeId }
    }

    init() {
        let library = store.load()
        servers = library.servers
        activeId = library.activeId
        tunnels.onStatus = { [weak self] status in
            Task { @MainActor in
                self?.apply(status)
            }
        }
        tunnels.prepare()
    }

    func show(_ screen: Screen) {
        error = nil
        if screen == .importKey {
            draft = ""
        }
        self.screen = screen
    }

    func updateDraft(_ value: String) {
        draft = value
        error = nil
    }

    func report(_ message: String) {
        error = message
    }

    func refreshConnection() {
        if phase == .connecting { return }
        if tunnels.isUp(), phase != .connected {
            phase = .connected
            connectedSince = storedSince()
            now = Date()
            error = nil
        } else if !tunnels.isUp(), phase == .connected {
            rememberSince(nil)
            phase = .idle
            rxBytes = 0
            txBytes = 0
            handshake = "—"
            connectedSince = nil
        }
    }

    func tickClock() async {
        tick += 1
        guard phase == .connected else { return }
        now = Date()
        if tick % 2 == 0 {
            let snapshot = await tunnels.snapshot()
            guard phase == .connected else { return }
            rxBytes = snapshot.rxBytes
            txBytes = snapshot.txBytes
            handshake = formatHandshake(snapshot.handshakeEpochMillis)
        }
    }

    func importText(_ raw: String) {
        Task {
            do {
                let key = try KeyImport.parse(raw)
                if phase != .idle {
                    tunnels.disconnect()
                }
                let library = store.add(key)
                rememberSince(nil)
                servers = library.servers
                activeId = library.activeId
                screen = .home
                draft = ""
                phase = .idle
                error = nil
                rxBytes = 0
                txBytes = 0
                handshake = "—"
                connectedSince = nil
            } catch {
                screen = .importKey
                draft = raw
                self.error = (error as? LocalizedError)?.errorDescription ?? "Ключ не распознан"
            }
        }
    }

    func select(_ id: String) {
        if phase != .idle, activeId != id {
            tunnels.disconnect()
            rememberSince(nil)
            phase = .idle
            rxBytes = 0
            txBytes = 0
            handshake = "—"
            connectedSince = nil
        }
        let library = store.setActive(id)
        servers = library.servers
        activeId = library.activeId
        screen = .home
        error = nil
    }

    func delete(_ id: String) {
        if phase != .idle, activeId == id {
            report("Сначала отключите VPN")
            return
        }
        let library = store.delete(id)
        servers = library.servers
        activeId = library.activeId
        error = nil
    }

    func connect() {
        guard let profile = active, phase == .idle else { return }
        phase = .connecting
        error = nil
        screen = .home
        Task {
            do {
                try await tunnels.connect(conf: profile.key.conf, endpoint: profile.key.endpoint)
            } catch {
                rememberSince(nil)
                phase = .idle
                connectedSince = nil
                self.error = TunnelMessage.userText(error)
            }
        }
    }

    func disconnect() {
        guard phase != .idle else { return }
        tunnels.disconnect()
        rememberSince(nil)
        phase = .idle
        rxBytes = 0
        txBytes = 0
        handshake = "—"
        connectedSince = nil
    }

    private func apply(_ status: NEVPNStatus) {
        switch status {
        case .connected:
            if phase != .connected {
                phase = .connected
                connectedSince = storedSince()
                error = nil
            }
            now = Date()
        case .connecting, .reasserting:
            phase = .connecting
        case .disconnecting:
            break
        default:
            let failed = phase == .connecting
            if phase != .idle {
                rememberSince(nil)
                rxBytes = 0
                txBytes = 0
                handshake = "—"
                connectedSince = nil
            }
            phase = .idle
            if failed, error == nil {
                error = "Не удалось подключиться"
            }
        }
    }

    private func storedSince() -> Date {
        let saved = UserDefaults.standard.double(forKey: sinceKey)
        if saved > 0 {
            return Date(timeIntervalSince1970: saved)
        }
        let date = Date()
        rememberSince(date)
        return date
    }

    private func rememberSince(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: sinceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sinceKey)
        }
    }

    private func formatHandshake(_ epochMillis: Int64) -> String {
        guard epochMillis > 0 else { return "ещё нет" }
        let seconds = max(0, Int(Date().timeIntervalSince1970 * 1000) - Int(epochMillis)) / 1000
        if seconds < 60 { return "\(seconds) с назад" }
        if seconds < 3600 { return "\(seconds / 60) мин назад" }
        return "\(seconds / 3600) ч назад"
    }
}

func elapsedLabel(since: Date?, now: Date) -> String {
    guard let since else { return "00:00:00" }
    let total = max(0, Int(now.timeIntervalSince(since)))
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}

func formatBytes(_ value: Int64) -> String {
    let units = ["Б", "КБ", "МБ", "ГБ"]
    var size = Double(value)
    var index = 0
    while size >= 1024, index < units.count - 1 {
        size /= 1024
        index += 1
    }
    if index == 0 {
        return "\(Int(size)) \(units[index])"
    }
    return String(format: "%.1f %@", size, units[index])
}
