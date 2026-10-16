import XCTest
@testable import VPNClientLogic

final class SiteDomainTests: XCTestCase {
    func testAcceptsUrlAndKeepsOnlyNormalizedHost() throws {
        XCTAssertEqual(try SiteDomain.normalize(" HTTPS://Example.COM:443/path?q=1 "), "example.com")
        XCTAssertEqual(try SiteDomain.normalize("example.com/section"), "example.com")
        XCTAssertEqual(try SiteDomain.normalize("example.com."), "example.com")
    }

    func testConvertsInternationalDomainToAscii() throws {
        XCTAssertEqual(try SiteDomain.normalize("пример.рф"), "xn--e1afmkfd.xn--p1ai")
    }

    func testRejectsIpAddressesAndUnsupportedSchemes() {
        XCTAssertThrowsError(try SiteDomain.normalize("https://192.168.1.10"))
        XCTAssertThrowsError(try SiteDomain.normalize("ftp://example.com"))
    }

    func testRejectsEmptyAndSingleLabelAndCredentials() {
        XCTAssertThrowsError(try SiteDomain.normalize("   "))
        XCTAssertThrowsError(try SiteDomain.normalize("localhost"))
        XCTAssertThrowsError(try SiteDomain.normalize("https://user:pass@example.com"))
        XCTAssertThrowsError(try SiteDomain.normalize("bad_label.example.com"))
    }
}