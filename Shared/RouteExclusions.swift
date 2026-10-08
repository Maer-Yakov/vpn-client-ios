import Foundation

/// Subtracts exclusion prefixes from AllowedIPs so site-bypass works with WireGuardKit.
enum RouteExclusions {
    static let maxLegacyRoutes = 180

    static func subtract(routes: [InetNetwork], exclusions: [InetNetwork]) throws -> [InetNetwork] {
        var result: [InetNetwork] = []
        for route in routes {
            var remaining = [route]
            for exclusion in exclusions {
                var next: [InetNetwork] = []
                for candidate in remaining {
                    next.append(contentsOf: try subtractOne(candidate, exclusion))
                }
                remaining = next
                if result.count + remaining.count > maxLegacyRoutes {
                    throw SiteDomainError.message("Слишком много IP-маршрутов для обхода сайтов")
                }
            }
            result.append(contentsOf: remaining)
            if result.count > maxLegacyRoutes {
                throw SiteDomainError.message("Слишком много IP-маршрутов для обхода сайтов")
            }
        }
        return result
    }

    /// Rewrites peer AllowedIPs in a WireGuard/Amnezia conf so excluded CIDRs leave the tunnel.
    static func apply(exclusions: [InetNetwork], to conf: String) throws -> String {
        guard !exclusions.isEmpty else { return conf }
        var lines = conf.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("allowedips") {
                guard let eq = trimmed.firstIndex(of: "=") else {
                    index += 1
                    continue
                }
                let raw = trimmed[trimmed.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                let networks = try raw.split(separator: ",").map {
                    try InetNetwork.parse($0.trimmingCharacters(in: .whitespaces))
                }
                let rewritten = try subtract(routes: networks, exclusions: exclusions)
                if rewritten.isEmpty {
                    throw SiteDomainError.message("После обхода сайтов не осталось маршрутов VPN")
                }
                lines[index] = "AllowedIPs = " + rewritten.map(\.cidr).joined(separator: ", ")
            }
            index += 1
        }
        return lines.joined(separator: "\n")
    }

    private static func subtractOne(_ route: InetNetwork, _ exclusion: InetNetwork) throws -> [InetNetwork] {
        guard let routeBytes = ipBytes(route.address),
              let excludedBytes = ipBytes(exclusion.address),
              routeBytes.count == excludedBytes.count,
              contains(network: routeBytes, prefix: route.prefix, address: excludedBytes) else {
            return [route]
        }
        if exclusion.prefix <= route.prefix {
            return []
        }
        let excludedPrefix = min(exclusion.prefix, excludedBytes.count * 8)
        var siblings: [InetNetwork] = []
        var bit = route.prefix
        while bit < excludedPrefix {
            var sibling = excludedBytes
            setBit(&sibling, bit, !getBit(excludedBytes, bit))
            var trailing = bit + 1
            while trailing < sibling.count * 8 {
                setBit(&sibling, trailing, false)
                trailing += 1
            }
            guard let address = hostAddress(sibling) else {
                throw SiteDomainError.message("Не удалось построить IP-маршрут")
            }
            siblings.append(InetNetwork(address: address, prefix: bit + 1))
            bit += 1
        }
        return siblings
    }

    private static func contains(network: [UInt8], prefix: Int, address: [UInt8]) -> Bool {
        guard network.count == address.count else { return false }
        let fullBytes = prefix / 8
        for index in 0..<fullBytes where network[index] != address[index] {
            return false
        }
        let remainingBits = prefix % 8
        if remainingBits == 0 { return true }
        let mask = UInt8(0xff << (8 - remainingBits))
        return (network[fullBytes] & mask) == (address[fullBytes] & mask)
    }

    private static func getBit(_ bytes: [UInt8], _ bit: Int) -> Bool {
        let byteIndex = bit / 8
        let bitIndex = 7 - (bit % 8)
        return ((bytes[byteIndex] >> bitIndex) & 1) == 1
    }

    private static func setBit(_ bytes: inout [UInt8], _ bit: Int, _ value: Bool) {
        let byteIndex = bit / 8
        let bitIndex = 7 - (bit % 8)
        if value {
            bytes[byteIndex] |= (1 << bitIndex)
        } else {
            bytes[byteIndex] &= ~(1 << bitIndex)
        }
    }

    private static func ipBytes(_ value: String) -> [UInt8]? {
        var addr = in6_addr()
        if value.contains(":") {
            guard inet_pton(AF_INET6, value, &addr) == 1 else { return nil }
            return withUnsafeBytes(of: addr) { Array($0) }
        }
        var addr4 = in_addr()
        guard inet_pton(AF_INET, value, &addr4) == 1 else { return nil }
        return withUnsafeBytes(of: addr4) { Array($0) }
    }

    private static func hostAddress(_ bytes: [UInt8]) -> String? {
        if bytes.count == 4 {
            var addr = in_addr()
            _ = bytes.withUnsafeBytes { raw in
                memcpy(&addr, raw.baseAddress, 4)
            }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(buffer.count)) != nil else { return nil }
            return String(cString: buffer)
        }
        if bytes.count == 16 {
            var addr = in6_addr()
            _ = bytes.withUnsafeBytes { raw in
                memcpy(&addr, raw.baseAddress, 16)
            }
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &addr, &buffer, socklen_t(buffer.count)) != nil else { return nil }
            return String(cString: buffer)
        }
        return nil
    }
}
