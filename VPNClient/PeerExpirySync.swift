import Foundation

enum PeerExpirySync {
    struct Result {
        var found: Bool
        var expiresAtMillis: Int64?
    }

    static func fetch(key: ImportedKey) async -> Result? {
        let address = key.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, address != "—" else { return nil }
        for base in panelBases(key) {
            if let result = try? await request(base: base, address: address) {
                return result
            }
        }
        return nil
    }

    static func panelBases(_ key: ImportedKey) -> [String] {
        var bases: [String] = []
        if let panel = key.panelUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
           !panel.isEmpty {
            bases.append(panel)
        }
        let host = key.endpoint
            .split(separator: "%").first
            .map(String.init)?
            .split(separator: ":").first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !host.isEmpty, !["vpn.example.com", "127.0.0.1", "localhost"].contains(host) {
            bases.append(contentsOf: [
                "https://\(host)",
                "http://\(host)",
                "http://\(host):8000",
                "http://\(host):8080",
                "https://\(host):8443",
            ])
        }
        return bases
    }

    private static func request(base: String, address: String) async throws -> Result {
        var components = URLComponents(string: "\(base)/api/public/peer-expiry")
        components?.queryItems = [URLQueryItem(name: "address", value: address)]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mvpn-iOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 {
            return Result(found: false, expiresAtMillis: nil)
        }
        guard (200...299).contains(code) else {
            throw URLError(.badServerResponse)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        if json["expires_at"] is NSNull || json["expires_at"] == nil {
            return Result(found: true, expiresAtMillis: nil)
        }
        let raw: String
        if let text = json["expires_at"] as? String {
            raw = text
        } else if let number = json["expires_at"] as? Int64 {
            raw = String(number)
        } else if let number = json["expires_at"] as? Int {
            raw = String(number)
        } else {
            throw URLError(.cannotParseResponse)
        }
        guard let millis = SubscriptionExpiry.parseIsoToMillis(raw) else {
            throw URLError(.cannotParseResponse)
        }
        return Result(found: true, expiresAtMillis: millis)
    }
}
