//
//  ProcessMetrics.swift
//  DeviceHealthLearning
//
//  Not part of TelemetrySDK. Low-level, public Mach/os calls that read how this process is doing:
//  - this app's own memory footprint (the same "phys_footprint" number Xcode's memory gauge shows)
//  - how much headroom iOS thinks this app has before it would be killed for memory pressure
//  - this app's own CPU usage, summed across its threads
//  None of this can see what OTHER apps are doing — the sandbox does not allow that. But a shrinking
//  memory headroom, while this app itself is doing nothing new, is usually a sign that something
//  else on the device — another app, a system service — is consuming more RAM.
//

import Foundation
import Darwin
import os

nonisolated enum ProcessMetrics {

    // This app's resident memory footprint in MB — the same number Xcode's memory gauge shows.
    static func memoryFootprintMB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        return Double(info.phys_footprint) / 1024 / 1024
    }

    // Approximate MB of headroom before iOS would terminate this app for memory pressure.
    static func availableMemoryBeforeTerminationMB() -> Double {
        Double(os_proc_available_memory()) / 1024 / 1024
    }

    // This app's own CPU usage, summed across its threads. Can exceed 100% on a multi-core device.
    // nil if the thread list could not be read.
    static func cpuUsagePercent() -> Double? {
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)

        guard task_threads(mach_task_self_, &threadsList, &threadsCount) == KERN_SUCCESS, let threadsList else {
            return nil
        }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)),
                         vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }

        var totalUsage: Double = 0
        for index in 0..<Int(threadsCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let result = withUnsafeMutablePointer(to: &threadInfo) { pointer -> kern_return_t in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) { intPointer in
                    thread_info(threadsList[index], thread_flavor_t(THREAD_BASIC_INFO), intPointer, &threadInfoCount)
                }
            }

            guard result == KERN_SUCCESS, threadInfo.flags & TH_FLAGS_IDLE == 0 else { continue }
            totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100
        }
        return totalUsage
    }

    // Free / total space on the data volume, in GB. nil on failure.
    static func diskSpaceGB() -> (free: Double, total: Double)? {
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]),
            let free = values.volumeAvailableCapacityForImportantUsage,
            let total = values.volumeTotalCapacity else {
            return nil
        }
        let gb = 1024.0 * 1024.0 * 1024.0
        return (Double(free) / gb, Double(total) / gb)
    }
}
