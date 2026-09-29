//
//  JSJailbreakResult.swift
//  DJBLearning
//
//  Swift-friendly representation of the array `dynamicJailbreakDetection
//  .start()` returns, e.g.:
//  [{id:"UploadedRules_SDK_..."},
//   {name:"deviceJailBreakCheck", passed:<bool>},
//   {name:"mountCheck", passed:<bool>}, ...
//   {failedReasonCodes:[...]}]
//
//  Note: for every entry EXCEPT "deviceJailBreakCheck", `passed == true`
//  means the sub-check found nothing wrong (good). For
//  "deviceJailBreakCheck" specifically, `passed == true` means the overall
//  verdict is "device IS compromised" (the JS names it confusingly as
//  `passed:H` where `H = !allChecksOK`).
//

import Foundation
import JavaScriptCore

struct JSCheckEntry: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
}

struct JSJailbreakResult {
    let ruleSetId: String?
    let isJailbroken: Bool
    let checks: [JSCheckEntry]
    let failedReasonCodes: [Int]
    let logLines: [JSLogLine]
    let exceptions: [String]

    static func parse(_ value: JSValue?, log: JSRunLog) -> JSJailbreakResult {
        var ruleSetId: String?
        var isJailbroken = false
        var checks: [JSCheckEntry] = []
        var failedReasonCodes: [Int] = []

        if let array = value?.toArray() {
            for element in array {
                guard let dict = element as? [String: Any] else { continue }

                if let id = dict["id"] as? String {
                    ruleSetId = id
                }

                if let name = dict["name"] as? String, let passed = dict["passed"] as? Bool {
                    if name == "deviceJailBreakCheck" {
                        isJailbroken = passed
                    } else {
                        checks.append(JSCheckEntry(name: name, passed: passed))
                    }
                }

                if let codes = dict["failedReasonCodes"] as? [Any] {
                    failedReasonCodes = codes.compactMap { ($0 as? NSNumber)?.intValue }
                }
            }
        }

        return JSJailbreakResult(
            ruleSetId: ruleSetId,
            isJailbroken: isJailbroken,
            checks: checks,
            failedReasonCodes: failedReasonCodes,
            logLines: log.lines,
            exceptions: log.exceptions
        )
    }
}
