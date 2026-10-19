//
//  NetworkUtilities.swift
//  DeviceHealthLearning
//
//  Ported from TelemetrySDK NetworkAdapter, VPNMonitor and
//  NetworkInformationProvider+MobileNetworkInformation.
//

import Foundation
import Network
import CoreTelephony

// MARK: - IP addresses (SDK: NetworkAdapter)

nonisolated struct NetworkInterface {
    let flags: UInt32
    let family: sa_family_t
    let name: String
    let address: String
}

nonisolated enum NetworkAdapter {
    // First IPv4 address on en0 (Wi-Fi).
    static var ipV4Address: String? {
        all.first { $0.name == "en0" && $0.family == sa_family_t(AF_INET) }?.address
    }

    // First IPv6 address on en0 (Wi-Fi).
    static var ipV6Address: String? {
        all.first { $0.name == "en0" && $0.family == sa_family_t(AF_INET6) }?.address
    }

    // Comma separated IPv4/IPv6, or nil when neither is available. Same shape as the SDK `ip_address` attribute.
    static var ipAddress: String? {
        let joined = [ipV4Address, ipV6Address]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ",")
        return joined.isEmpty ? nil : joined
    }

    static var all: [NetworkInterface] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        defer { pointer.flatMap(freeifaddrs) }

        guard getifaddrs(&pointer) == noErr, let first = pointer?.pointee else { return [] }

        return sequence(first: first) { $0.ifa_next?.pointee }.compactMap { interface in
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard let address = interface.ifa_addr,
                  getnameinfo(address, socklen_t(address.pointee.sa_len), &hostname, socklen_t(hostname.count),
                              nil, 0, NI_NUMERICHOST) == noErr else {
                return nil
            }
            return NetworkInterface(flags: interface.ifa_flags,
                                    family: address.pointee.sa_family,
                                    name: String(cString: interface.ifa_name),
                                    address: String(cString: hostname))
        }
    }
}

// MARK: - VPN (SDK: VPNMonitor)

nonisolated enum VPNMonitor {
    // Real third-party/NEPacketTunnelProvider VPNs and native IKEv2 VPN profiles create a
    // "utunN" interface. "ipsecN" is intentionally excluded: on iPhones it is the carrier's
    // VoLTE/VoWiFi (IMS) calling tunnel, which is up on essentially every cellular device
    // regardless of any user VPN, so treating it as a VPN signal would be a false positive.
    private static let vpnInterfacePrefixes = ["tap", "tun", "ppp", "utun"]

    static func isActive() -> Bool? {
        let interfaces = NetworkAdapter.all
        guard !interfaces.isEmpty else { return nil }
        return !matchingInterfaces(in: interfaces).isEmpty
    }

    // Addresses are reported one-per-row by getifaddrs, so the same interface name can appear
    // multiple times (once per address family). Group by name first so each interface's full set
    // of addresses can be inspected together.
    private static func matchingInterfaces(in interfaces: [NetworkInterface]) -> [String] {
        let byName = Dictionary(grouping: interfaces, by: \.name)

        // The IMS stack also keeps a "utunN" interface alive for the actual VoLTE/VoWiFi data
        // path, which shares its exact link-local address with the paired "ipsecN" control
        // interface(s) (a coincidence unique to that stack — a real VPN's link-local address is
        // its own). Collect those to exclude the paired utun interface too.
        let imsLinkLocalHosts = Set(byName.compactMap { name, group -> String? in
            guard name.hasPrefix("ipsec") else { return nil }
            return group.compactMap { linkLocalHost($0.address) }.first
        })

        return byName.compactMap { name, group -> String? in
            guard !name.hasPrefix("ipsec") else { return nil }
            guard vpnInterfacePrefixes.contains(where: { name.starts(with: $0) }) else { return nil }
            guard group.contains(where: { $0.flags & UInt32(IFF_UP) != 0 }) else { return nil }

            // A real tunnel has a usable address beyond just the auto-assigned link-local one:
            // a point-to-point IPv4 address, or a global (non-link-local) IPv6 address.
            guard group.contains(where: { !$0.address.isEmpty && !$0.address.lowercased().hasPrefix("fe80") })
            else { return nil }

            if let host = group.compactMap({ linkLocalHost($0.address) }).first, imsLinkLocalHosts.contains(host) {
                return nil
            }
            return name
        }
    }

    // The link-local address without its "%scope" suffix, so the same address on two different
    // interface names can be compared.
    private static func linkLocalHost(_ address: String) -> String? {
        let lower = address.lowercased()
        guard lower.hasPrefix("fe80") else { return nil }
        return lower.split(separator: "%").first.map(String.init)
    }
}

// MARK: - Mobile network type (SDK: fetchMobileNetworkTypes)

nonisolated enum MobileNetworkInfo {
    private static let telephony = CTTelephonyNetworkInfo()

    // CSV of mapped network types for every active SIM, or nil.
    static func fetchMobileNetworkTypes() -> String? {
        guard let technologies = telephony.serviceCurrentRadioAccessTechnology?.values, !technologies.isEmpty else {
            return nil
        }
        return technologies.map(mappedNetworkType).joined(separator: ",")
    }

    static func mappedNetworkType(_ technology: String) -> String {
        switch technology {
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
            return "2G"
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
            return "3G"
        case CTRadioAccessTechnologyLTE:
            return "4G"
        case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
            return "5G"
        default:
            return "unknown"
        }
    }
}

// MARK: - Interface type description (SDK: NWInterface.InterfaceType description)

extension NWInterface.InterfaceType {
    var name: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "cellular"
        case .loopback: return "loopback"
        case .wiredEthernet: return "wiredEthernet"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}
