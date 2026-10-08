import Foundation
import UIKit

enum TrialClient {
    static let panelURL = "http://85.137.164.156:8080"
    private static let deviceKey = "mvpn_device_id"

    static func deviceId() -> String {
        if let saved = UserDefaults.standard.string(forKey: deviceKey), !saved.isEmpty {
            return saved
        }
        let generated = UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceKey)
        return generated
    }

    static func claim(deviceId: String) async throws -> String {
        guard let url = URL(string: "\(panelURL)/api/public/trial") else {
            throw TrialClientError.message("Не удалось получить тестовый сервер")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mvpn-iOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["device_id": deviceId])

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(decoding: data, as: UTF8.self)
        guard (200...299).contains(code) else {
            throw TrialClientError.message(messageOf(body: body, code: code))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let config = json["config"] as? String,
              config.hasPrefix("vpn://") else {
            throw TrialClientError.message("Сервер не прислал ключ")
        }
        return config
    }

    private static func messageOf(body: String, code: Int) -> String {
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = json["detail"] as? String,
           !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return detail
        }
        if code == 409 {
            return "Тестовый сервер можно получить только один раз"
        }
        return "Не удалось получить тестовый сервер"
    }
}

enum TrialClientError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
