import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                TopBar(title: "Настройки", action: "Назад") {
                    model.show(.home)
                }
                if let key = model.active?.key {
                    SettingRow(label: "Сервер", value: key.title)
                    SettingRow(label: "Адрес", value: key.endpoint)
                    if let expires = key.expiresAtMillis, expires > 0 {
                        SettingRow(label: "Подписка до", value: SubscriptionExpiry.formatDate(expires))
                    }
                } else {
                    Text("Сервер не выбран.")
                        .foregroundStyle(PanelColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                SettingRow(label: "Версия", value: model.appVersion)
                PanelCard {
                    model.show(.splitTunnel)
                } content: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Раздельное туннелирование")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(PanelColor.text)
                            Text("Сайты в обход VPN")
                                .font(.system(size: 13))
                                .foregroundStyle(PanelColor.muted)
                        }
                        Spacer()
                        Text("›")
                            .font(.system(size: 22))
                            .foregroundStyle(PanelColor.muted)
                    }
                }
                PanelCard {
                    model.show(.backup)
                } content: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Конфигурация")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(PanelColor.text)
                            Text("Резервное копирование")
                                .font(.system(size: 13))
                                .foregroundStyle(PanelColor.muted)
                        }
                        Spacer()
                        Text("›")
                            .font(.system(size: 22))
                            .foregroundStyle(PanelColor.muted)
                    }
                }
                if let notice = model.notice {
                    Text(notice)
                        .font(.system(size: 13))
                        .foregroundStyle(PanelColor.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let error = model.error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(PanelColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    _ = SupportChat.open()
                } label: {
                    Text("Чат поддержки")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PanelColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(PanelColor.panel)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PanelColor.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
