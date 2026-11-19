import Foundation

enum LANAddress {
    static func localIPv4() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var preferEn: String?
        var ptr = ifaddr
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            guard let sa = current.pointee.ifa_addr,
                  sa.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard name == "en0" || name.hasPrefix("en") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(cString: host)
            if name == "en0" { preferEn = text; break }
            if address == nil { address = text }
        }
        return preferEn ?? address
    }

    static func panelURL(port: UInt16) -> URL? {
        guard let ip = localIPv4() else { return nil }
        return URL(string: "http://\(ip):\(port)/panel/")
    }
}
