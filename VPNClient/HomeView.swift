import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "VPN", action: "Настройки") {
                model.show(.settings)
            }
            Spacer()
            ConnectControl(
                phase: model.phase,
                enabled: model.active != nil,
                action: {
                    if model.phase == .connected {
                        model.disconnect()
                    } else if model.phase == .idle, model.active != nil {
                        model.connect()
                    }
                }
            )
            Text(statusText)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(model.phase == .connected ? PanelColor.online : PanelColor.text)
                .padding(.top, 22)
            if model.phase == .connected {
                Text(elapsedLabel(since: model.connectedSince, now: model.now))
                    .font(.system(size: 16))
                    .foregroundStyle(PanelColor.accent)
                    .padding(.top, 6)
                HStack(spacing: 10) {
                    StatCard(label: "Получено", value: formatBytes(model.rxBytes))
                    StatCard(label: "Отправлено", value: formatBytes(model.txBytes))
                }
                .padding(.top, 22)
                Text("Рукопожатие \(model.handshake)")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelColor.muted)
                    .padding(.top, 10)
            }
            Spacer()
            if let active = model.active {
                PanelCard {
                    model.show(.servers)
                } content: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(active.key.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(PanelColor.text)
                                .lineLimit(1)
                            Text(active.key.endpoint)
                                .font(.system(size: 13))
                                .foregroundStyle(PanelColor.muted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("›")
                            .font(.system(size: 22))
                            .foregroundStyle(PanelColor.muted)
                    }
                }
            } else {
                PanelCard {
                    model.show(.importKey)
                } content: {
                    Text("Добавить сервер")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PanelColor.text)
                }
            }
            if let error = model.error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(PanelColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
            Button("Чат поддержки") {
                SupportChat.open()
            }
            .font(.system(size: 17))
            .foregroundStyle(PanelColor.accent)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var statusText: String {
        switch model.phase {
        case .idle:
            return model.active == nil ? "Нет сервера" : "Отключено"
        case .connecting:
            return "Подключение"
        case .connected:
            return "Подключено"
        }
    }
}
