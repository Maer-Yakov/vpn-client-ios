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
    case splitTunnel
    case backup
}

@MainActor
final class AppModel: ObservableObject {
    @Published var servers: [StoredServer] = []
    @Published var activeId: String?
    @Published var screen: Screen = .home
    @Published var draft = ""
    @Published var phase: Phase = .idle
    @Published var error: String?
    @Published var notice: String?
    @Published var claimingTrial = false
    @Published var rxBytes: Int64 = 0
    @Published var txBytes: Int64 = 0
    @Published var handshake = "—"
    @Published var connectedSince: Date?
    @Published var now = Date()
    @Published var storeWarning: String?

    let tunnels = TunnelController()
    private let store = ProfileStore()
    private let sinceKey = "connected_since"
    private var tick = 0

    var active: StoredServer? {
        servers.first { $0.id == activeId }
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.0"
    }

    init() {
        let library = store.load()
        servers = library.servers
        activeId = library.activeId
        storeWarning = library.warning
        if let warning = library.warning {
            error = warning
        }
        tunnels.onStatus = { [weak self] status in
            Task { @MainActor in
                self?.apply(status)
            }
        }
        #if !targetEnvironment(simulator)
        tunnels.prepare()
        refreshPeerExpiry()
        #endif
    }

    func show(_ screen: Screen) {
        error = nil
        notice = nil
        if screen == .importKey {
            draft = ""
        }
        self.screen = screen
    }

    func updateDraft(_ value: String) {
        draft = value
        error = nil
        notice = nil
    }

    func report(_ message: String) {
        error = message
        notice = nil
    }

    func refreshConnection() {
        if phase == .connecting { return }
        if tunnels.isUp(), phase != .connected {
            phase = .connected
            connectedSince = storedSince()
            now = Date()
            error = nil
            refreshPeerExpiry()
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
                let library = try store.add(key)
                rememberSince(nil)
                servers = library.servers
                activeId = library.activeId
                screen = .home
                draft = ""
                phase = .idle
                error = nil
                notice = nil
                rxBytes = 0
                txBytes = 0
                handshake = "—"
                connectedSince = nil
                refreshPeerExpiry()
            } catch {
                screen = .importKey
                draft = raw
                self.error = (error as? LocalizedError)?.errorDescription ?? "Ключ не распознан"
                notice = nil
            }
        }
    }

    func claimTrial() {
        guard !claimingTrial else { return }
        claimingTrial = true
        error = nil
        notice = nil
        Task {
            let deviceId = TrialClient.deviceId()
            guard !deviceId.isEmpty else {
                claimingTrial = false
                error = "Не удалось определить устройство"
                return
            }
            do {
                let raw = try await TrialClient.claim(deviceId: deviceId)
                let key = try KeyImport.parse(raw)
                if phase != .idle {
                    tunnels.disconnect()
                }
                let library = try store.add(key)
                rememberSince(nil)
                servers = library.servers
                activeId = library.activeId
                screen = .home
                draft = ""
                phase = .idle
                error = nil
                notice = "Тестовый сервер на 1 день, скорость 1 Мбит/с"
                rxBytes = 0
                txBytes = 0
                handshake = "—"
                connectedSince = nil
                claimingTrial = false
                refreshPeerExpiry()
            } catch {
                claimingTrial = false
                notice = nil
                let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.error = detail.isEmpty ? "Не удалось получить тестовый сервер" : detail
            }
        }
    }

    func refreshPeerExpiry() {
        guard let active else { return }
        let key = active.key
        let id = active.id
        Task {
            guard let remote = await PeerExpirySync.fetch(key: key), remote.found else { return }
            guard remote.expiresAtMillis != key.expiresAtMillis else { return }
            do {
                let library = try store.setExpiresAt(id: id, expiresAtMillis: remote.expiresAtMillis)
                servers = library.servers
                activeId = library.activeId
            } catch {
                // Keep local expiry if panel sync fails after a successful fetch parse.
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
        do {
            let library = try store.setActive(id)
            servers = library.servers
            activeId = library.activeId
            screen = .home
            error = nil
            notice = nil
            refreshPeerExpiry()
        } catch {
            report((error as? LocalizedError)?.errorDescription ?? "Не удалось выбрать сервер")
        }
    }

    func delete(_ id: String) {
        if phase != .idle, activeId == id {
            report("Сначала отключите VPN")
            return
        }
        do {
            let library = try store.delete(id)
            servers = library.servers
            activeId = library.activeId
            error = nil
            notice = nil
        } catch {
            report((error as? LocalizedError)?.errorDescription ?? "Не удалось удалить сервер")
        }
    }

    func setSplitMode(_ mode: AppRouteMode) {
        guard let active else {
            report("Сначала выберите сервер")
            return
        }
        guard phase == .idle else {
            report("Отключите VPN, чтобы изменить раздельное туннелирование")
            return
        }
        saveSplit(active.id, active.splitTunnel.copy(mode: mode))
    }

    func addBypassDomain(_ input: String) -> Bool {
        guard let active else {
            report("Сначала выберите сервер")
            return false
        }
        guard phase == .idle else {
            report("Отключите VPN, чтобы изменить список сайтов")
            return false
        }
        let domain: String
        do {
            domain = try SiteDomain.normalize(input)
        } catch {
            report((error as? LocalizedError)?.errorDescription ?? "Некорректный домен сайта")
            return false
        }
        if active.splitTunnel.bypassDomains.contains(domain) {
            report("Этот сайт уже добавлен")
            return false
        }
        var domains = active.splitTunnel.bypassDomains
        domains.insert(domain)
        saveSplit(active.id, active.splitTunnel.copy(bypassDomains: domains))
        return true
    }

    func removeBypassDomain(_ domain: String) {
        guard let active else { return }
        guard phase == .idle else {
            report("Отключите VPN, чтобы изменить список сайтов")
            return
        }
        var domains = active.splitTunnel.bypassDomains
        domains.remove(domain)
        saveSplit(active.id, active.splitTunnel.copy(bypassDomains: domains))
    }

    func exportBackupText() -> String? {
        guard !servers.isEmpty else {
            report("Нет серверов для сохранения")
            return nil
        }
        do {
            return try store.exportBackup()
        } catch {
            report((error as? LocalizedError)?.errorDescription ?? "Не удалось сохранить конфигурацию")
            return nil
        }
    }

    func onBackupSaved() {
        error = nil
        notice = "Конфигурация сохранена на телефон"
    }

    func importBackupText(_ raw: String) {
        Task {
            if phase != .idle {
                tunnels.disconnect()
                rememberSince(nil)
            }
            do {
                let library = try store.importBackup(raw)
                servers = library.servers
                activeId = library.activeId
                phase = .idle
                error = nil
                notice = "Конфигурация загружена (\(library.servers.count))"
                rxBytes = 0
                txBytes = 0
                handshake = "—"
                connectedSince = nil
                screen = .backup
                refreshPeerExpiry()
            } catch {
                notice = nil
                self.error = (error as? LocalizedError)?.errorDescription ?? "Не удалось загрузить конфигурацию"
            }
        }
    }

    func connect() {
        guard let profile = active, phase == .idle else { return }
        phase = .connecting
        error = nil
        notice = nil
        screen = .home
        Task {
            do {
                try await tunnels.connect(
                    conf: profile.key.conf,
                    endpoint: profile.key.endpoint,
                    splitTunnel: profile.splitTunnel
                )
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

    private func saveSplit(_ id: String, _ settings: SplitTunnelSettings) {
        do {
            let library = try store.setSplitTunnel(id: id, settings: settings)
            servers = library.servers
            activeId = library.activeId
            error = nil
            notice = nil
        } catch {
            report((error as? LocalizedError)?.errorDescription ?? "Не удалось сохранить настройки")
        }
    }

    private func apply(_ status: NEVPNStatus) {
        switch status {
        case .connected:
            if phase != .connected {
                phase = .connected
                connectedSince = storedSince()
                error = nil
                refreshPeerExpiry()
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

private extension SplitTunnelSettings {
    func copy(mode: AppRouteMode? = nil, packages: Set<String>? = nil, bypassDomains: Set<String>? = nil) -> SplitTunnelSettings {
        SplitTunnelSettings(
            mode: mode ?? self.mode,
            packages: packages ?? self.packages,
            bypassDomains: bypassDomains ?? self.bypassDomains
        )
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
