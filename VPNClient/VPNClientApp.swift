import SwiftUI

@main
struct VPNClientApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showStartup = true

    var body: some Scene {
        WindowGroup {
            ZStack {
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

                if showStartup {
                    MvpnStartupAnimation {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showStartup = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .background(PanelColor.bg.ignoresSafeArea())
            .task {
                // Hard fallback: never stay on splash longer than 2.5s (fixes black screen on simulator).
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if showStartup {
                    showStartup = false
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
            case .splitTunnel:
                SplitTunnelView()
            case .backup:
                BackupView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelColor.bg)
    }
}
