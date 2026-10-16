import Foundation

enum TrialResponseError: Error, LocalizedError, Equatable {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

/// Разбор ответа панели на `POST /api/public/trial` (без сетевого кода, чтобы тестировать отдельно).
enum TrialResponse {
    static let genericFailure = "Не удалось получить тестовый сервер"
    static let alreadyClaimed = "Тестовый сервер можно получить только один раз"
    static let noKey = "Сервер не прислал ключ"

    static func parse(statusCode: Int, body: Data) throws -> String {
        guard (200...299).contains(statusCode) else {
            throw TrialResponseError.message(failureMessage(statusCode: statusCode, body: body))
        }
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let config = json["config"] as? String,
              config.hasPrefix("vpn://") else {
            throw TrialResponseError.message(noKey)
        }
        return config
    }

    static func failureMessage(statusCode: Int, body: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let detail = json["detail"] as? String,
           !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return detail
        }
        return statusCode == 409 ? alreadyClaimed : genericFailure
    }
}
