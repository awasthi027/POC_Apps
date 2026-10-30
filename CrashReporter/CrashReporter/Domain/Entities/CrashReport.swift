import Foundation

enum CrashType: String, Codable, CaseIterable, Identifiable {
    case forceUnwrap = "Force Unwrap nil"
    case arrayOutOfBounds = "Array Out Of Bounds"
    case divideByZero = "Divide By Zero"
    case fatalError = "Fatal Error"
    case uncaughtException = "Uncaught NSException"
    case stackOverflow = "Stack Overflow"

    var id: String { rawValue }
}

struct CrashReport: Codable, Identifiable, Hashable {
    let id: String
    let date: Date
    let type: String
    let reason: String
    let appVersion: String
    let osVersion: String
    let stackTrace: [String]
}
