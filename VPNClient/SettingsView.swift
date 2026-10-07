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
                } else {
                    Text("Сервер не выбран.")
                        .foregroundStyle(PanelColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                SettingRow(label: "Версия", value: "1.0.0")
                Button {
                    SupportChat.open()
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
