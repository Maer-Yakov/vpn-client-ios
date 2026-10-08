import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var showExporter = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                TopBar(title: "Конфигурация", action: "Назад") {
                    model.show(.settings)
                }
                Text("Сохраняются серверы, режимы раздельного туннелирования, списки приложений и сайтов. В файле есть ключи VPN — храните его только у себя.")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SettingRow(label: "Серверов сейчас", value: "\(model.servers.count)")
                PrimaryButton(title: "Сохранить на телефон", enabled: !model.servers.isEmpty) {
                    exportBackup()
                }
                GhostButton(title: "Загрузить с телефона") {
                    showImporter = true
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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .text, .data, .plainText]) { result in
            switch result {
            case .success(let url):
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else {
                    model.report("Не удалось прочитать файл")
                    return
                }
                guard data.count <= 2 * 1024 * 1024 else {
                    model.report("Файл слишком большой")
                    return
                }
                model.importBackupText(String(decoding: data, as: UTF8.self))
            case .failure:
                break
            }
        }
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ActivityView(items: [exportURL])
            }
        }
    }

    private func exportBackup() {
        guard let text = model.exportBackupText() else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let name = "mvpn-backup-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
            exportURL = url
            showExporter = true
            model.onBackupSaved()
        } catch {
            model.report("Не удалось сохранить конфигурацию")
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
