import SwiftUI

struct ServersView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            TopBar(title: "Серверы", action: "Назад") {
                model.show(.home)
            }
            ScrollView {
                VStack(spacing: 10) {
                    if model.servers.isEmpty {
                        Text("Список пуст")
                            .foregroundStyle(PanelColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(model.servers) { server in
                        let selected = server.id == model.activeId
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(server.key.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(PanelColor.text)
                                    .lineLimit(1)
                                Spacer()
                                if selected {
                                    Text("выбран")
                                        .font(.system(size: 12))
                                        .foregroundStyle(PanelColor.accent)
                                }
                            }
                            Text(server.key.endpoint)
                                .font(.system(size: 13))
                                .foregroundStyle(PanelColor.muted)
                            if let expires = server.key.expiresAtMillis, expires > 0 {
                                Text("до \(SubscriptionExpiry.formatDate(expires))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(
                                        SubscriptionExpiry.shouldWarn(expiresAtMillis: expires)
                                            ? PanelColor.danger
                                            : PanelColor.muted
                                    )
                            }
                            Button("Удалить") {
                                model.delete(server.id)
                            }
                            .font(.system(size: 17))
                            .foregroundStyle(PanelColor.danger)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(PanelColor.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? PanelColor.accent : PanelColor.line, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            model.select(server.id)
                        }
                    }
                }
            }
            PrimaryButton(title: "Добавить сервер") {
                model.show(.importKey)
            }
            GhostButton(title: model.claimingTrial ? "Получаем тестовый сервер…" : "Тестовый сервер на 1 день") {
                model.claimTrial()
            }
            .disabled(model.claimingTrial)
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
