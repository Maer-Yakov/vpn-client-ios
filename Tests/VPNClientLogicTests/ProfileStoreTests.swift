import XCTest
@testable import VPNClientLogic

final class ProfileStoreTests: XCTestCase {
    private var folder: URL!

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpn-store-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    private func store() -> ProfileStore {
        ProfileStore(folder: folder)
    }

    private func key(_ title: String) -> ImportedKey {
        ImportedKey(
            title: title,
            conf: "[Interface]\nPrivateKey = x\n[Peer]\nPublicKey = y\n",
            endpoint: "203.0.113.7:51820",
            address: "10.8.1.5",
            dns: "1.1.1.1",
            protocolName: "AmneziaWG"
        )
    }

    func testEmptyStoreHasNoServers() {
        let library = store().load()
        XCTAssertTrue(library.servers.isEmpty)
        XCTAssertNil(library.activeId)
        XCTAssertNil(library.warning)
    }

    func testAddMakesNewServerActiveAndPersists() throws {
        let store = store()
        let first = try store.add(key("A"))
        let second = try store.add(key("B"))
        XCTAssertEqual(second.servers.count, 2)
        XCTAssertEqual(second.activeId, second.servers.last?.id)
        XCTAssertNotEqual(first.activeId, second.activeId)

        let reloaded = self.store().load()
        XCTAssertEqual(reloaded.servers.map(\.key.title), ["A", "B"])
        XCTAssertEqual(reloaded.activeId, second.activeId)
        XCTAssertEqual(reloaded.servers.first?.key.protocolName, "AmneziaWG")
    }

    func testSetActiveIgnoresUnknownId() throws {
        let store = store()
        let library = try store.add(key("A"))
        XCTAssertEqual(try store.setActive("missing").activeId, library.activeId)
    }

    func testDeleteActiveFallsBackToFirst() throws {
        let store = store()
        _ = try store.add(key("A"))
        let library = try store.add(key("B"))
        let result = try store.delete(library.activeId!)
        XCTAssertEqual(result.servers.map(\.key.title), ["A"])
        XCTAssertEqual(result.activeId, result.servers.first?.id)
    }

    func testDeleteLastServerClearsActive() throws {
        let store = store()
        let library = try store.add(key("A"))
        let result = try store.delete(library.activeId!)
        XCTAssertTrue(result.servers.isEmpty)
        XCTAssertNil(result.activeId)
    }

    func testBackupRoundTrip() throws {
        let store = store()
        _ = try store.add(key("A"))
        _ = try store.add(key("B"))
        let backup = try store.exportBackup()

        let other = ProfileStore(folder: folder.appendingPathComponent("other", isDirectory: true))
        let restored = try other.importBackup(backup)
        XCTAssertEqual(restored.servers.map(\.key.title), ["A", "B"])
    }

    func testBrokenFileIsReportedAndPreserved() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: folder.appendingPathComponent("servers.json"))
        let library = store().load()
        XCTAssertTrue(library.servers.isEmpty)
        XCTAssertNotNil(library.warning)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("servers.json.corrupt").path))
    }
}
