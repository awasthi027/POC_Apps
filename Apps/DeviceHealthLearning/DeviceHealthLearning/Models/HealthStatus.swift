//
//  HealthStatus.swift
//  DeviceHealthLearning
//

import Foundation

// Traffic-light health rating. Ordered so the worst status wins with `max()`.
enum HealthStatus: Int, Comparable {
    case green
    case orange
    case red

    var title: String {
        switch self {
        case .green: return "Good"
        case .orange: return "Warning"
        case .red: return "Critical"
        }
    }

    static func < (lhs: HealthStatus, rhs: HealthStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Status of one area plus the reasons behind it.
struct HealthSummary: Identifiable {
    let name: String
    let status: HealthStatus
    let reasons: [String]

    var id: String { name }
}
