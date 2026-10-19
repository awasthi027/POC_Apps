//
//  HealthItem.swift
//  DeviceHealthLearning
//

import Foundation

// One attribute row, already formatted for display.
struct HealthItem: Identifiable {
    let name: String
    let value: String?
    var footnote: String? = nil

    var id: String { name }
}

// One event from any monitor, already formatted for display.
struct HealthEvent: Identifiable {
    let id: UUID
    let name: String
    let detail: String
    let date: Date
}
