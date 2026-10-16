import XCTest
@testable import VPNClientLogic

final class KeyImportTests: XCTestCase {
    // Ключи собраны так же, как в Amnezia: 4 байта длины (big-endian) + zlib(JSON), base64url.
    // Все ключи и адрес сервера в них тестовые.
    static let awgURI = "vpn://AAABy3icRY9fT-MwEMS_ysqv9FI7f0qJlIdEgGi5q8JRJLi6OrnJNrgkm2KbFlr1u58MQqd9mflppNk5shptZfTW6Z5YCmyO1oFFs0PDBsBIdfiNva96ckoTGstSWBz_ex9SHeFBqx9q34Q-rPYNS-HIWmXd36qntfaeLSbk0KxVhUtJeV0btBYyEDwYByJIhlEo6XJ271HweQMQAQ94ICSVRu-Uw1v8gAyecjok8-uz9vFx6lDEbqOjQ_tr9nr2XIfm6WHSTIumiNZF95JJmlaQQSxp2mn6rPNSvUMGCZd0LyCDkRchZHDBJd14InjIozCJEyFJ0qJENEtJ5duq1dXXE-_zSZEnZtU_7OgmfnZ9vVmNcHRxfrf5efXbiVlexN2f1-34sskk5W3b77GelH6x38QDPuQDSNMhl3RF9bbX5CCDkEd-sYiC8zQR45BLKtFYbR2Su0Xcqlbv0AcTSex0Wp7-AUvbjTE"
    static let amneziawgURI = "vpn://AAAB0XicRY9fT9tAEMS_yupeCc6d_4RgyQ-2oCKhjdwSJCAXoYu9MZfa63B3TWiifHd00Arty_xGI83OkdVoK6O3TvfEUmBztA4smh0aNgBGqsP_tueqJ6c0obEshcXxi31IdYQHrc7Vvgl9-B_vG5bCkbXKuueqp7X2zBYTcmjWqsKlpLyuDVoLGQgejAMRJMMolHQ1u_NW8HEDEAEPeCAklUbvlMNb_AsZPOZ0SObfztqHh6lDEbuNjg7tj9nr2Usdmsf7STMtmiJaF93vTNK0ggxiSdNO00edl-oNMki4pDsBGYy8CCGDSy7pxjuChzwKkzgRkiQtSkSzlFT-WbW6-nzibT4p8sSs-vsd3cQvrq83qxGOLi9-br5f_3Jilhdx9_S6HV81maS8bfs91pPSL_abeMCHfABpOuSSrqne9pocZBDyyC8WUXCRJmIcckklGqutQ3K3iFvV6h36YCKJnU7L0zujco-1"

    static let plainConf = """
    # Home server
    [Interface]
    Address = 10.8.1.5/32
    DNS = 1.1.1.1
    PrivateKey = YAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=

    [Peer]
    PublicKey = xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=
    AllowedIPs = 0.0.0.0/0
    Endpoint = 203.0.113.7:51820
    """

    func testParsesAwgContainerKey() throws {
        let key = try KeyImport.parse(Self.awgURI)
        XCTAssertEqual(key.title, "Test server")
        XCTAssertEqual(key.endpoint, "203.0.113.7:51820")
        XCTAssertEqual(key.address, "10.8.1.5")
        XCTAssertEqual(key.dns, "1.1.1.1, 1.0.0.1")
        XCTAssertEqual(key.protocolName, "AmneziaWG")
        XCTAssertTrue(key.conf.hasSuffix("\n"))
    }

    func testParsesAmneziawgContainerKey() throws {
        let key = try KeyImport.parse(Self.amneziawgURI)
        XCTAssertEqual(key.endpoint, "203.0.113.7:51820")
        XCTAssertEqual(key.protocolName, "AmneziaWG")
    }

    func testParsesLinkInsideSurroundingText() throws {
        let key = try KeyImport.parse("  мой ключ:\n\(Self.awgURI)\nспасибо ")
        XCTAssertEqual(key.endpoint, "203.0.113.7:51820")
    }

    func testParsesPlainWireGuardConf() throws {
        let key = try KeyImport.parse(Self.plainConf.replacingOccurrences(of: "\n", with: "\r\n"))
        XCTAssertEqual(key.title, "Home server")
        XCTAssertEqual(key.protocolName, "WireGuard")
        XCTAssertEqual(key.endpoint, "203.0.113.7:51820")
        XCTAssertFalse(key.conf.contains("\r"))
    }

    func testRejectsEmptyAndGarbage() {
        XCTAssertThrowsError(try KeyImport.parse("   ")) {
            XCTAssertEqual($0 as? KeyImportError, .empty)
        }
        XCTAssertThrowsError(try KeyImport.parse("hello")) {
            XCTAssertEqual($0 as? KeyImportError, .unrecognized)
        }
    }

    func testRejectsDamagedLink() {
        XCTAssertThrowsError(try KeyImport.parse("vpn://AAAAAAAA")) {
            XCTAssertEqual($0 as? KeyImportError, .damaged)
        }
    }

    func testRejectsIncompleteConf() {
        let conf = "[Interface]\nAddress = 10.0.0.2/32\n[Peer]\nEndpoint = 1.2.3.4:1\n"
        XCTAssertThrowsError(try KeyImport.parse(conf)) {
            XCTAssertEqual($0 as? KeyImportError, .incomplete)
        }
    }

    func testRejectsHugeInput() {
        let huge = String(repeating: "a", count: KeyImport.maxImportChars + 1)
        XCTAssertThrowsError(try KeyImport.parse(huge)) {
            XCTAssertEqual($0 as? KeyImportError, .tooLarge)
        }
    }

    func testLooksLikeVPNKey() {
        XCTAssertTrue(KeyImport.looksLikeVPNKey(Self.awgURI))
        XCTAssertTrue(KeyImport.looksLikeVPNKey(Self.plainConf))
        XCTAssertFalse(KeyImport.looksLikeVPNKey("https://example.com"))
    }

    func testDeflateBodyStripsZlibWrapper() {
        // 78 9C — заголовок zlib, последние 4 байта — Adler-32.
        let wrapped = Data([0x78, 0x9C, 1, 2, 3, 4, 5, 0xAA, 0xBB, 0xCC, 0xDD])
        XCTAssertEqual(KeyImport.deflateBody(wrapped), Data([1, 2, 3, 4, 5]))
    }

    func testDeflateBodyKeepsRawDeflate() {
        let raw = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        XCTAssertEqual(KeyImport.deflateBody(raw), raw)
    }
}
