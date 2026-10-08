import Foundation

enum SubscriptionExpiry {
    static let warningDays = 2

    struct ConnectedStatus {
        var title: String
        var date: String?
        var warning: Bool
    }

    static func daysRemaining(expiresAtMillis: Int64?, nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> Int? {
        guard let expiresAtMillis, expiresAtMillis > 0 else { return nil }
        let seconds = Double(expiresAtMillis - nowMillis) / 1000.0
        if seconds <= 0 { return -1 }
        return max(1, Int(ceil(seconds / 86_400.0)))
    }

    static func shouldWarn(expiresAtMillis: Int64?, nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> Bool {
        guard let remaining = daysRemaining(expiresAtMillis: expiresAtMillis, nowMillis: nowMillis) else { return false }
        return (0...warningDays).contains(remaining) || remaining == -1
    }

    static func formatDate(_ expiresAtMillis: Int64) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = .current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expiresAtMillis) / 1000))
    }

    static func connectedStatus(expiresAtMillis: Int64?, nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> ConnectedStatus {
        guard shouldWarn(expiresAtMillis: expiresAtMillis, nowMillis: nowMillis), let expiresAtMillis else {
            return ConnectedStatus(title: "Подключено", date: nil, warning: false)
        }
        let remaining = daysRemaining(expiresAtMillis: expiresAtMillis, nowMillis: nowMillis)
        let title = (remaining != nil && remaining! < 0) ? "Подписка истекла" : "Истекает подписка"
        return ConnectedStatus(title: title, date: formatDate(expiresAtMillis), warning: true)
    }

    static func parseIsoToMillis(_ raw: String?) -> Int64? {
        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty { return nil }

        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
        ]
        for pattern in patterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = pattern
            if pattern.contains("XXXXX") || pattern.contains("'Z'") {
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
            }
            if let date = formatter.date(from: value) {
                return Int64(date.timeIntervalSince1970 * 1000)
            }
        }
        if let millis = Int64(value), millis > 1_000_000_000_000 { return millis }
        if let seconds = Int64(value), seconds > 1_000_000_000 { return seconds * 1000 }
        return nil
    }
}
