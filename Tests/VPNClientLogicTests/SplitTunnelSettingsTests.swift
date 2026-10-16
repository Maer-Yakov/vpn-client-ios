import XCTest
@testable import VPNClientLogic

final class SplitTunnelSettingsTests: XCTestCase {
    func testOnlyBypassSitesEnableSplitTunnelOnIos() {
        XCTAssertFalse(SplitTunnelSettings().isEnabled)
        // Режимы по приложениям — только для Android; на iOS они ничего не включают.
        XCTAssertFalse(SplitTunnelSettings(mode: .selectedBypassVpn, packages: ["com.example.app"]).isEnabled)
        XCTAssertTrue(SplitTunnelSettings(bypassDomains: ["example.com"]).isEnabled)
    }

    func testUnknownModeFallsBackToAllTraffic() {
        XCTAssertEqual(AppRouteMode.parse(nil), .allTraffic)
        XCTAssertEqual(AppRouteMode.parse("Nonsense"), .allTraffic)
        XCTAssertEqual(AppRouteMode.parse("SelectedBypassVpn"), .selectedBypassVpn)
    }

    func testPackageNameValidation() {
        XCTAssertTrue(SplitTunnelSettings.isValidPackageName("com.example.mail"))
        XCTAssertFalse(SplitTunnelSettings.isValidPackageName("not a package"))
        XCTAssertFalse(SplitTunnelSettings.isValidPackageName("single"))
    }

    func testSettingsSurviveStoreAndBackup() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpn-split-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ProfileStore(folder: folder)
        let key = ImportedKey(
            title: "A",
            conf: "[Interface]\nPrivateKey = x\n[Peer]\nPublicKey = y\n",
            endpoint: "203.0.113.7:51820",
            address: "10.8.1.5",
            dns: "1.1.1.1",
            protocolName: "AmneziaWG"
        )
        let id = try store.add(key).activeId!
        let settings = SplitTunnelSettings(mode: .selectedBypassVpn, packages: ["com.example.mail"], bypassDomains: ["example.com", "example.org"])
        _ = try store.setSplitTunnel(id: id, settings: settings)

        XCTAssertEqual(store.load().servers.first?.splitTunnel, settings)

        let other = ProfileStore(folder: folder.appendingPathComponent("restored", isDirectory: true))
        let restored = try other.importBackup(try store.exportBackup())
        XCTAssertEqual(restored.servers.first?.splitTunnel, settings)
    }
}