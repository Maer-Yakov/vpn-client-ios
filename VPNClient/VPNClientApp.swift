import SwiftUI

@main
struct VPNClientApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showStartup = !Self.isSimulator

    /// Network Extension / splash quirks are unreliable in Simulator (incl. iOS 26.x).
    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

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
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        model.refreshConnection()
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PanelColor.bg.ignoresSafeArea())
            .task {
                guard showStartup else { return }
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
