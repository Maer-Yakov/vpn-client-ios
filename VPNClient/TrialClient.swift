import Foundation
import Security
import UIKit

enum TrialClient {
    static let panelURL = "http://85.137.164.156:8080"
    private static let deviceKey = "mvpn_device_id"
    private static let keychainService = "app.vpnadmin.client.trial"

    /// Идентификатор хранится в Keychain, чтобы переживать удаление приложения
    /// (иначе после переустановки можно было бы снова получить «единственный» тест).
    /// Если Keychain недоступен (например, при установке без подписи), используется UserDefaults.
    static func deviceId() -> String {
        if let saved = keychainRead(), !saved.isEmpty {
            return saved
        }
        if let saved = UserDefaults.standard.string(forKey: deviceKey), !saved.isEmpty {
            keychainWrite(saved)
            return saved
        }
        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceKey)
        keychainWrite(generated)
        return generated
    }

    static func claim(deviceId: String, session: URLSession = .shared) async throws -> String {
        guard let url = URL(string: "\(panelURL)/api/public/trial") else {
            throw TrialResponseError.message(TrialResponse.genericFailure)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mvpn-iOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["device_id": deviceId])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TrialResponseError.message("Нет связи с сервером. Проверьте интернет и повторите попытку")
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try TrialResponse.parse(statusCode: code, body: data)
    }

    // MARK: Keychain

    private static func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: deviceKey,
        ]
    }

    private static func keychainRead() -> String? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainWrite(_ value: String) {
        var attributes = keychainQuery()
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        // Сбой записи не критичен: останется UserDefaults.
        _ = SecItemAdd(attributes as CFDictionary, nil)
    }
}
