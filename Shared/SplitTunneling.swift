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

    /// На iOS работает только обход сайтов. Режим и пакеты хранятся для совместимости с резервными копиями Android.
    var isEnabled: Bool {
        !bypassDomains.isEmpty
    }

    static func isValidPackageName(_ value: String) -> Bool {
        let pattern = try! NSRegularExpression(pattern: "^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+$")
        let range = NSRange(value.startIndex..., in: value)
        return pattern.firstMatch(in: value, range: range) != nil
    }
}
