import Foundation

enum AppRouteMode: String, CaseIterable {
    case allTraffic = "AllTraffic"
    case selectedThroughVpn = "SelectedThroughVpn"
    case selectedBypassVpn = "SelectedBypassVpn"

    static func parse(_ raw: String?) -> AppRouteMode {
        guard let raw, let mode = AppRouteMode(rawValue: raw) else { return .allTraffic }
        return mode
    }
}

struct SplitTunnelSettings: Equatable {
    var mode: AppRouteMode = .allTraffic
    var packages: Set<String> = []
    var bypassDomains: Set<String> = []

    var isEnabled: Bool {
        mode != .allTraffic || !bypassDomains.isEmpty
    }

    /// iOS consumer apps cannot do Android-style per-app routing; packages are kept for backup parity.
    func applyTo(_ configuration: String) throws -> String {
        if mode == .allTraffic { return configuration }
        let selected = packages.filter(Self.isValidPackageName).sorted()
        guard !selected.isEmpty else {
            throw SiteDomainError.message("Выберите хотя бы одно приложение")
        }
        // Per-app directives are Android-only; keep conf unchanged on iOS.
        return configuration
    }

    static func isValidPackageName(_ value: String) -> Bool {
        let pattern = try! NSRegularExpression(pattern: "^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+$")
        let range = NSRange(value.startIndex..., in: value)
        return pattern.firstMatch(in: value, range: range) != nil
    }
}
