import Compression
import Foundation

struct ImportedKey: Equatable {
    var title: String
    var conf: String
    var endpoint: String
    var address: String
    var dns: String
    var protocolName: String
    var expiresAtMillis: Int64? = nil
    var panelUrl: String? = nil
}

enum KeyImportError: Error {
    case empty
    case unrecognized
    case damaged
    case unsupported
    case incomplete
    case tooLarge
}

extension KeyImportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .empty:
            return "Вставьте ключ"
        case .unrecognized:
            return "Ключ не распознан"
        case .damaged:
            return "Ключ повреждён"
        case .unsupported:
            return "Этот ключ не поддерживается"
        case .incomplete:
            return "В ключе не хватает данных"
        case .tooLarge:
            return "Ключ слишком большой"
        }
    }
}

enum KeyImport {
    private static let uriPattern = try! NSRegularExpression(pattern: "vpn://[A-Za-z0-9_\\-=]+")
    private static let obfuscation = ["Jc", "Jmin", "Jmax", "S1", "S2", "H1", "I1"]
    private static let maxImportChars = 512 * 1024

    static func parse(_ raw: String) throws -> ImportedKey {
        if raw.count > maxImportChars {
            throw KeyImportError.tooLarge
        }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{FEFF}", with: "")
        if text.isEmpty {
            throw KeyImportError.empty
        }
        let uri = firstURI(in: text)
        let decoded = try uri.map { try decodeVPNURI($0) }
        var conf = (decoded?.conf ?? text).replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard conf.range(of: "[Interface]", options: .caseInsensitive) != nil,
              conf.range(of: "[Peer]", options: .caseInsensitive) != nil else {
            throw KeyImportError.unrecognized
        }
        try requireField(conf, "PrivateKey")
        try requireField(conf, "Address")
        try requireField(conf, "PublicKey")
        try requireField(conf, "Endpoint")
        if !conf.hasSuffix("\n") {
            conf += "\n"
        }
        let title = decoded?.title.nilIfBlank ?? titleFromConf(conf)
        let address = field(conf, "Address").split(separator: "/").first.map(String.init)?
            .split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let expiresAt = decoded?.expiresAtMillis ?? expiresAtFromConf(conf)
        return ImportedKey(
            title: title,
            conf: conf,
            endpoint: field(conf, "Endpoint"),
            address: address,
            dns: field(conf, "DNS").nilIfBlank ?? "—",
            protocolName: obfuscation.contains(where: { !field(conf, $0).isEmpty }) ? "AmneziaWG" : "WireGuard",
            expiresAtMillis: expiresAt,
            panelUrl: decoded?.panelUrl
        )
    }

    static func looksLikeVPNKey(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.contains("vpn://") {
            return true
        }
        return value.range(of: "[Interface]", options: .caseInsensitive) != nil
            && value.range(of: "[Peer]", options: .caseInsensitive) != nil
    }

    private static func firstURI(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = uriPattern.firstMatch(in: text, range: range), let span = Range(match.range, in: text) else {
            return nil
        }
        return String(text[span])
    }

    private static func decodeVPNURI(_ uri: String) throws -> (title: String, conf: String, expiresAtMillis: Int64?, panelUrl: String?) {
        var payload = String(uri.dropFirst("vpn://".count))
        let remainder = payload.count % 4
        if remainder != 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        let normalized = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let bytes = Data(base64Encoded: normalized), bytes.count >= 5 else {
            throw KeyImportError.damaged
        }
        let rawLen = (Int(bytes[0]) << 24) | (Int(bytes[1]) << 16) | (Int(bytes[2]) << 8) | Int(bytes[3])
        guard (1...1_000_000).contains(rawLen) else {
            throw KeyImportError.damaged
        }
        let compressed = bytes.subdata(in: 4..<bytes.count)
        let inflated = try inflate(compressed, rawLen: rawLen)
        guard let json = String(data: inflated, encoding: .utf8) else {
            throw KeyImportError.damaged
        }
        return try extractConf(json)
    }

    private static func inflate(_ data: Data, rawLen: Int) throws -> Data {
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: rawLen)
        defer { destination.deallocate() }
        let written = data.withUnsafeBytes { raw -> Int in
            guard let source = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(destination, rawLen, source, data.count, nil, COMPRESSION_ZLIB)
        }
        guard written == rawLen else {
            throw KeyImportError.damaged
        }
        return Data(bytes: destination, count: written)
    }

    private static func extractConf(_ json: String) throws -> (title: String, conf: String, expiresAtMillis: Int64?, panelUrl: String?) {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyImportError.damaged
        }
        let description = (root["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = (root["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = description.nilIfBlank ?? name
        let expiresRaw = (root["expiresAt"] as? String)?.nilIfBlank ?? (root["expires_at"] as? String)
        let expiresAt = SubscriptionExpiry.parseIsoToMillis(expiresRaw)
        let panelRaw = ((root["panelUrl"] as? String) ?? (root["panel_url"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let panelUrl = panelRaw.nilIfBlank
        guard let containers = root["containers"] as? [Any] else {
            throw KeyImportError.unrecognized
        }
        var bestRank = Int.max
        var bestConf = ""
        for item in containers {
            guard let container = item as? [String: Any] else { continue }
            for (key, value) in container {
                guard let block = value as? [String: Any],
                      let conf = block["last_config"] as? String,
                      conf.range(of: "[Interface]", options: .caseInsensitive) != nil else {
                    continue
                }
                let rank: Int
                switch key {
                case "amneziawg": rank = 0
                case "wireguard": rank = 1
                default: rank = 5
                }
                if rank < bestRank {
                    bestRank = rank
                    bestConf = conf
                }
            }
        }
        if bestConf.isEmpty || bestRank > 1 {
            throw KeyImportError.unsupported
        }
        return (title, bestConf, expiresAt ?? expiresAtFromConf(bestConf), panelUrl)
    }

    private static func expiresAtFromConf(_ conf: String) -> Int64? {
        for raw in conf.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let body = line.hasPrefix("#") ? String(line.dropFirst()).trimmingCharacters(in: .whitespaces) : line
            guard let eq = body.firstIndex(of: "="), eq != body.startIndex else { continue }
            let name = body[..<eq].trimmingCharacters(in: .whitespaces)
            if name.caseInsensitiveCompare("ExpiresAt") != .orderedSame { continue }
            return SubscriptionExpiry.parseIsoToMillis(String(body[body.index(after: eq)...]).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func requireField(_ conf: String, _ name: String) throws {
        if field(conf, name).isEmpty {
            throw KeyImportError.incomplete
        }
    }

    private static func titleFromConf(_ conf: String) -> String {
        let comment = conf.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("#") && $0.count > 1 }
        let title = comment.map { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }
        return title?.nilIfBlank ?? "VPN"
    }

    static func field(_ conf: String, _ name: String) -> String {
        let wanted = name.lowercased()
        for raw in conf.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("[") {
                continue
            }
            guard let eq = line.firstIndex(of: "="), eq != line.startIndex else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            if key == wanted {
                return line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
