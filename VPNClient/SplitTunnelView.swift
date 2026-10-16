import SwiftUI

struct SplitTunnelView: View {
    @EnvironmentObject private var model: AppModel
    @State private var siteDraft = ""

    private var canEdit: Bool {
        model.phase == .idle && model.active != nil
    }

    private var settings: SplitTunnelSettings {
        model.active?.splitTunnel ?? SplitTunnelSettings()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                TopBar(title: "Раздельное туннелирование", action: "Назад") {
                    model.show(.settings)
                }
                Text("Для сервера: \(model.active?.key.title ?? "не выбран")")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("iOS не позволяет выбирать приложения. Добавленные ниже сайты идут в обход VPN, остальной трафик через VPN.")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !canEdit {
                    Text("Отключите VPN и выберите сервер для изменения настроек.")
                        .font(.system(size: 13))
                        .foregroundStyle(PanelColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Сайты в обход VPN")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PanelColor.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Введите домен или URL. IP-адреса определяются при подключении; сайты с общим CDN-IP тоже могут идти в обход.")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    TextField("example.com", text: $siteDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(PanelColor.inset)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelColor.line, lineWidth: 1))
                        .foregroundStyle(PanelColor.text)
                        .disabled(!canEdit)
                    Button("Добавить") {
                        if model.addBypassDomain(siteDraft) {
                            siteDraft = ""
                        }
                    }
                    .foregroundStyle(PanelColor.accent)
                    .disabled(!canEdit || siteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ForEach(settings.bypassDomains.sorted(), id: \.self) { domain in
                    HStack {
                        Text(domain)
                            .foregroundStyle(PanelColor.text)
                        Spacer()
                        Button("Удалить") {
                            model.removeBypassDomain(domain)
                        }
                        .foregroundStyle(PanelColor.danger)
                        .disabled(!canEdit)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(PanelColor.panel)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelColor.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let error = model.error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(PanelColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
