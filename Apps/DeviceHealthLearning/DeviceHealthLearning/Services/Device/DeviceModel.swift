//
//  DeviceModel.swift
//  DeviceHealthLearning
//
//  Maps the raw hardware identifier (e.g. "iPhone15,3") iOS reports to a friendly name and release
//  year, so a performance reading can be read alongside how old the hardware actually is. This
//  table is best-effort and only covers mainline iPhones through the iPhone 16 family — an
//  unrecognized identifier falls back to showing the raw value, which is always accurate even when
//  the table is not. Extend it as new devices ship.
//

import Foundation

nonisolated enum DeviceModel {
    // "iPhone15,3", or the Simulator's chosen device identifier when running there.
    static var identifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "simulator"
        #else
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
        #endif
    }

    static var friendlyName: String? { table[identifier]?.name }
    static var releaseYear: Int? { table[identifier]?.year }

    // Years since this device launched, or nil when the identifier is not in the table.
    static var ageInYears: Int? {
        releaseYear.map { Calendar.current.component(.year, from: Date()) - $0 }
    }

    private static let table: [String: (name: String, year: Int)] = [
        "iPhone8,1": ("iPhone 6s", 2015), "iPhone8,2": ("iPhone 6s Plus", 2015),
        "iPhone8,4": ("iPhone SE (1st gen)", 2016),
        "iPhone9,1": ("iPhone 7", 2016), "iPhone9,3": ("iPhone 7", 2016),
        "iPhone9,2": ("iPhone 7 Plus", 2016), "iPhone9,4": ("iPhone 7 Plus", 2016),
        "iPhone10,1": ("iPhone 8", 2017), "iPhone10,4": ("iPhone 8", 2017),
        "iPhone10,2": ("iPhone 8 Plus", 2017), "iPhone10,5": ("iPhone 8 Plus", 2017),
        "iPhone10,3": ("iPhone X", 2017), "iPhone10,6": ("iPhone X", 2017),
        "iPhone11,2": ("iPhone XS", 2018), "iPhone11,4": ("iPhone XS Max", 2018), "iPhone11,6": ("iPhone XS Max", 2018),
        "iPhone11,8": ("iPhone XR", 2018),
        "iPhone12,1": ("iPhone 11", 2019), "iPhone12,3": ("iPhone 11 Pro", 2019), "iPhone12,5": ("iPhone 11 Pro Max", 2019),
        "iPhone12,8": ("iPhone SE (2nd gen)", 2020),
        "iPhone13,1": ("iPhone 12 mini", 2020), "iPhone13,2": ("iPhone 12", 2020),
        "iPhone13,3": ("iPhone 12 Pro", 2020), "iPhone13,4": ("iPhone 12 Pro Max", 2020),
        "iPhone14,4": ("iPhone 13 mini", 2021), "iPhone14,5": ("iPhone 13", 2021),
        "iPhone14,2": ("iPhone 13 Pro", 2021), "iPhone14,3": ("iPhone 13 Pro Max", 2021),
        "iPhone14,6": ("iPhone SE (3rd gen)", 2022),
        "iPhone14,7": ("iPhone 14", 2022), "iPhone14,8": ("iPhone 14 Plus", 2022),
        "iPhone15,2": ("iPhone 14 Pro", 2022), "iPhone15,3": ("iPhone 14 Pro Max", 2022),
        "iPhone15,4": ("iPhone 15", 2023), "iPhone15,5": ("iPhone 15 Plus", 2023),
        "iPhone16,1": ("iPhone 15 Pro", 2023), "iPhone16,2": ("iPhone 15 Pro Max", 2023),
        "iPhone17,3": ("iPhone 16", 2024), "iPhone17,4": ("iPhone 16 Plus", 2024),
        "iPhone17,1": ("iPhone 16 Pro", 2024), "iPhone17,2": ("iPhone 16 Pro Max", 2024),
    ]
}
