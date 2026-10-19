//
//  HealthCategory.swift
//  DeviceHealthLearning
//
//  Identifies one of the summary rows on BaseView, used as the navigation value to push its detail page.
//

import Foundation

enum HealthCategory: String, Identifiable, Hashable, CaseIterable {
    case battery
    case network
    case networkSpeed
    case networkRestrictions
    case performance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: return "Battery"
        case .network: return "Network"
        case .networkSpeed: return "Network Speed"
        case .networkRestrictions: return "Network Restrictions"
        case .performance: return "Device Performance"
        }
    }
}
