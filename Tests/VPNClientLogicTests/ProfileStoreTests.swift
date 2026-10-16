import XCTest
@testable import VPNClientLogic

final class ProfileStoreTests: XCTestCase {
    private var file: URL!

    override func setUp() {
        super.setUp()
        file = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpn-store-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file)
        super.tearDown()
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
        let library = ProfileStore(file: file).load()
        XCTAssertTrue(library.servers.isEmpty)
        XCTAssertNil(library.activeId)
    }

    func testAddMakesNewServerActiveAndPersists() {
        let store = ProfileStore(file: file)
        let first = store.add(key("A"))
        let second = store.add(key("B"))
        XCTAssertEqual(second.servers.count, 2)
        XCTAssertEqual(second.activeId, second.servers.last?.id)
        XCTAssertNotEqual(first.activeId, second.activeId)

        let reloaded = ProfileStore(file: file).load()
        XCTAssertEqual(reloaded.servers.map(\.key.title), ["A", "B"])
        XCTAssertEqual(reloaded.activeId, second.activeId)
        XCTAssertEqual(reloaded.servers.first?.key.protocolName, "AmneziaWG")
    }

    func testSetActiveIgnoresUnknownId() {
        let store = ProfileStore(file: file)
        let library = store.add(key("A"))
        XCTAssertEqual(store.setActive("missing").activeId, library.activeId)
    }

    func testDeleteActiveFallsBackToFirst() {
        let store = ProfileStore(file: file)
        _ = store.add(key("A"))
        let library = store.add(key("B"))
        let result = store.delete(library.activeId!)
        XCTAssertEqual(result.servers.map(\.key.title), ["A"])
        XCTAssertEqual(result.activeId, result.servers.first?.id)
    }

    func testDeleteLastServerClearsActive() {
        let store = ProfileStore(file: file)
        let library = store.add(key("A"))
        let result = store.delete(library.activeId!)
        XCTAssertTrue(result.servers.isEmpty)
        XCTAssertNil(result.activeId)
    }

    func testBrokenFileIsTreatedAsEmpty() throws {
        try Data("not json".utf8).write(to: file)
        XCTAssertTrue(ProfileStore(file: file).load().servers.isEmpty)
    }
}
