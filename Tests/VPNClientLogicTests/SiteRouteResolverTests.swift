import XCTest
@testable import VPNClientLogic

final class SiteRouteResolverTests: XCTestCase {
    func testResolvesIpv4AndIpv6AsHostRoutes() throws {
        let routes = try SiteRouteResolver.resolve(domains: ["example.com"]) { _ in
            ["203.0.113.10", "2001:db8::10"]
        }
        XCTAssertEqual(routes.map(\.cidr).sorted(), ["2001:db8::10/128", "203.0.113.10/32"])
    }

    func testDeduplicatesAddressesAcrossSites() throws {
        let routes = try SiteRouteResolver.resolve(domains: ["a.example.com", "b.example.com"]) { _ in
            ["203.0.113.10"]
        }
        XCTAssertEqual(routes.count, 1)
    }

    func testReportsDnsFailureBeforeConnecting() {
        XCTAssertThrowsError(try SiteRouteResolver.resolve(domains: ["example.com"]) { _ in
            throw URLError(.cannotFindHost)
        }) { error in
            XCTAssertTrue((error as? LocalizedError)?.errorDescription?.contains("example.com") == true)
        }
    }

    func testEmptyLookupResultIsAnError() {
        XCTAssertThrowsError(try SiteRouteResolver.resolve(domains: ["example.com"]) { _ in [] })
    }

    func testTooManySitesAreRejected() {
        let domains = Set((0...SiteRouteResolver.maxSites).map { "site\($0).example.com" })
        XCTAssertThrowsError(try SiteRouteResolver.resolve(domains: domains) { _ in ["203.0.113.1"] })
    }

    func testTooManyAddressesAreRejected() {
        XCTAssertThrowsError(try SiteRouteResolver.resolve(domains: ["example.com"]) { _ in
            (0...SiteRouteResolver.maxResolvedAddresses).map { "10.1.\($0 / 250).\($0 % 250 + 1)" }
        })
    }

    func testNoDomainsMeansNoRoutes() throws {
        XCTAssertTrue(try SiteRouteResolver.resolve(domains: []) { _ in ["203.0.113.1"] }.isEmpty)
    }

    func testInetNetworkParsing() throws {
        XCTAssertEqual(try InetNetwork.parse("203.0.113.10").cidr, "203.0.113.10/32")
        XCTAssertEqual(try InetNetwork.parse("2001:db8::1").cidr, "2001:db8::1/128")
        XCTAssertEqual(try InetNetwork.parse("10.0.0.0/8").prefix, 8)
        XCTAssertThrowsError(try InetNetwork.parse("10.0.0.0/x"))
    }
}