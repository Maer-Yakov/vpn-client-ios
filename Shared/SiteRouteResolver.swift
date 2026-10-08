import Foundation

struct InetNetwork: Hashable {
    var address: String
    var prefix: Int

    var cidr: String { "\(address)/\(prefix)" }

    static func parse(_ value: String) throws -> InetNetwork {
        let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
        let address = parts[0]
        let prefix: Int
        if parts.count == 2 {
            guard let parsed = Int(parts[1]) else {
                throw SiteDomainError.message("Некорректный IP-маршрут")
            }
            prefix = parsed
        } else if address.contains(":") {
            prefix = 128
        } else {
            prefix = 32
        }
        return InetNetwork(address: address, prefix: prefix)
    }
}

enum SiteRouteResolver {
    static let maxSites = 64
    static let maxResolvedAddresses = 128

    static func resolve(
        domains: Set<String>,
        lookup: (String) throws -> [String] = { host in
            try dnsLookup(host)
        }
    ) throws -> [InetNetwork] {
        guard domains.count <= maxSites else {
            throw SiteDomainError.message("Можно добавить не более \(maxSites) сайтов")
        }
        var routes: [InetNetwork] = []
        var seen = Set<String>()
        for value in domains.sorted() {
            let domain = try SiteDomain.normalize(value)
            let addresses: [String]
            do {
                addresses = try lookup(domain)
            } catch {
                throw SiteDomainError.message("Не удалось определить IP сайта \(domain)")
            }
            guard !addresses.isEmpty else {
                throw SiteDomainError.message("Не удалось определить IP сайта \(domain)")
            }
            for address in addresses {
                let prefix = address.contains(":") ? 128 : 32
                let route = InetNetwork(address: address, prefix: prefix)
                if seen.insert(route.cidr).inserted {
                    routes.append(route)
                }
                if routes.count > maxResolvedAddresses {
                    throw SiteDomainError.message("Список сайтов разрешается в слишком много IP-адресов")
                }
            }
        }
        return routes
    }

    private static func dnsLookup(_ host: String) throws -> [String] {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &result)
        guard status == 0, let first = result else {
            throw SiteDomainError.message("Не удалось определить IP сайта \(host)")
        }
        defer { freeaddrinfo(first) }
        var addresses: [String] = []
        var pointer: UnsafeMutablePointer<addrinfo>? = first
        while let info = pointer {
            if let addr = info.pointee.ai_addr {
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(info.pointee.ai_addrlen), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let value = String(cString: hostBuffer)
                    if !value.isEmpty, !addresses.contains(value) {
                        addresses.append(value)
                    }
                }
            }
            pointer = info.pointee.ai_next
        }
        return addresses
    }
}
