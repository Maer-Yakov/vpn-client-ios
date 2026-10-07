import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showFile = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TopBar(title: "Новый сервер", action: "Назад") {
                    model.show(model.servers.isEmpty ? .home : .servers)
                }
                GhostButton(title: "Сканировать QR") {
                    model.show(.scan)
                }
                TextEditor(text: Binding(
                    get: { model.draft },
                    set: { model.updateDraft($0) }
                ))
                .scrollContentBackground(.hidden)
                .foregroundStyle(PanelColor.text)
                .frame(minHeight: 160)
                .padding(8)
                .background(PanelColor.inset)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelColor.line, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if model.draft.isEmpty {
                        Text("Вставьте ключ")
                            .foregroundStyle(PanelColor.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                GhostButton(title: "Вставить из буфера") {
                    let text = UIPasteboard.general.string ?? ""
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        model.report("Буфер обмена пуст")
                    } else {
                        model.updateDraft(text)
                    }
                }
                GhostButton(title: "Открыть файл") {
                    showFile = true
                }
                PrimaryButton(title: "Сохранить", enabled: !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    model.importText(model.draft)
                }
                if let error = model.error {
                    Text(error)
                        .foregroundStyle(PanelColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .fileImporter(isPresented: $showFile, allowedContentTypes: [.text, .data, .plainText]) { result in
            switch result {
            case .success(let url):
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else {
                    model.report("Файл не открылся")
                    return
                }
                guard data.count <= 256 * 1024 else {
                    model.report("Файл слишком большой")
                    return
                }
                model.importText(String(decoding: data, as: UTF8.self))
            case .failure:
                break
            }
        }
    }
}
