import Foundation

enum SiteDomain {
    private static let labelPattern = try! NSRegularExpression(pattern: "^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")

    static func normalize(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw SiteDomainError.message("Введите домен сайта")
        }

        let components = URLComponents(string: value.contains("://") ? value : "https://\(value)")
        guard let components, let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw SiteDomainError.message("Укажите домен, например example.com")
        }
        if components.user != nil || components.password != nil {
            throw SiteDomainError.message("Вместо ссылки укажите только домен сайта")
        }

        let rawHost = components.host
            ?? components.percentEncodedHost
            ?? value.split(separator: "/").first.map(String.init)
        guard var host = rawHost?.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased(), !host.isEmpty else {
            throw SiteDomainError.message("Не удалось определить домен")
        }
        guard let ascii = host.idnaEncoded else {
            throw SiteDomainError.message("Некорректный домен сайта")
        }
        host = ascii.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()

        guard (1...253).contains(host.count), host.contains(".") else {
            throw SiteDomainError.message("Укажите полное доменное имя")
        }
        let labels = host.split(separator: ".").map(String.init)
        for label in labels {
            let range = NSRange(label.startIndex..., in: label)
            guard labelPattern.firstMatch(in: label, range: range) != nil else {
                throw SiteDomainError.message("Некорректный домен сайта")
            }
        }
        if isIpv4Literal(host) {
            throw SiteDomainError.message("Укажите домен, а не IP-адрес")
        }
        return host
    }

    private static func isIpv4Literal(_ host: String) -> Bool {
        let labels = host.split(separator: ".")
        guard labels.count == 4 else { return false }
        return labels.allSatisfy { part in
            guard let value = Int(part) else { return false }
            return (0...255).contains(value)
        }
    }
}

enum SiteDomainError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

private extension String {
    /// Minimal IDNA/punycode fallback: ASCII hosts pass through; non-ASCII rejected.
    var idnaEncoded: String? {
        if allSatisfy({ $0.isASCII }) { return lowercased() }
        // Prefer Foundation's URL host normalization when available.
        if let url = URL(string: "https://\(self)"), let host = url.host, host.allSatisfy({ $0.isASCII }) {
            return host.lowercased()
        }
        return nil
    }
}
