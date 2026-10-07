import SwiftUI

@main
struct VPNClientApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .background(PanelColor.bg.ignoresSafeArea())
                .onOpenURL { url in
                    model.importText(url.absoluteString)
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        model.refreshConnection()
                    }
                }
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await model.tickClock()
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            switch model.screen {
            case .home:
                HomeView()
            case .servers:
                ServersView()
            case .importKey:
                ImportView()
            case .scan:
                QrScanView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelColor.bg)
    }
}
