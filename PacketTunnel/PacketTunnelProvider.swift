import NetworkExtension
import os

#if canImport(WireGuardKit)
import WireGuardKit
#endif

final class PacketTunnelProvider: NEPacketTunnelProvider {
    #if canImport(WireGuardKit)
    private var adapter: WireGuardAdapter?
    #endif

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let conf = AppGroup.readConfig(), !conf.isEmpty else {
            completionHandler(PacketTunnelError.missingConfig)
            return
        }
        #if canImport(WireGuardKit)
        do {
            let configuration = try TunnelConfiguration(fromWgQuickConfig: conf)
            let adapter = WireGuardAdapter(with: self) { _, message in
                os_log("%{public}@", message)
            }
            self.adapter = adapter
            adapter.start(tunnelConfiguration: configuration) { error in
                completionHandler(error)
            }
        } catch {
            completionHandler(error)
        }
        #else
        completionHandler(PacketTunnelError.backendMissing)
        #endif
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        #if canImport(WireGuardKit)
        if let adapter {
            adapter.stop { _ in
                completionHandler()
            }
            self.adapter = nil
        } else {
            completionHandler()
        }
        #else
        completionHandler()
        #endif
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        #if canImport(WireGuardKit)
        adapter?.getRuntimeConfiguration { text in
            completionHandler?(text?.data(using: .utf8))
        } ?? completionHandler?(nil)
        #else
        completionHandler?(nil)
        #endif
    }
}

enum PacketTunnelError: Error {
    case missingConfig
    case backendMissing
}
