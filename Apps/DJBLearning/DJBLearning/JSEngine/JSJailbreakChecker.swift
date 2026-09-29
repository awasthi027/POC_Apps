//
//  JSJailbreakChecker.swift
//  DJBLearning
//
//  Loads and executes `decoded_payload.js` inside a sandboxed
//  JavaScriptCore context, bridging the `native_*` calls it makes to real
//  implementations (see JSNativeBridge / NativeChecks), and returns a
//  structured, UI-friendly result.
//
//  This is intentionally kept completely separate from the hardcoded native
//  Swift checks (see JailbreakDetector.swift + JailbreakChecks/) - the two
//  verification paths never share state or logic, so they can be compared
//  side by side.
//

import Foundation
import JavaScriptCore

final class JSJailbreakChecker {
    static let shared = JSJailbreakChecker()

    private init() {}

    enum CheckerError: LocalizedError {
        case scriptNotFound
        case scriptLoadFailed(String)
        case contextCreationFailed
        case evaluationFailed(String)
        case entryPointMissing

        var errorDescription: String? {
            switch self {
            case .scriptNotFound:
                return "decoded_payload.js was not found in the app bundle."
            case .scriptLoadFailed(let reason):
                return "Failed to read decoded_payload.js: \(reason)"
            case .contextCreationFailed:
                return "Failed to create a JavaScriptCore context."
            case .evaluationFailed(let reason):
                return "JavaScript evaluation failed: \(reason)"
            case .entryPointMissing:
                return "dynamicJailbreakDetection.start() was not found after evaluating the script."
            }
        }
    }

    /// Runs the JS-based rule set synchronously. Call from a background
    /// queue - some of the underlying native checks (e.g. the fork() probe)
    /// are blocking.
    func run() -> Result<JSJailbreakResult, CheckerError> {
        guard let url = Bundle.main.url(forResource: "decoded_payload", withExtension: "js") else {
            return .failure(.scriptNotFound)
        }

        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch {
            return .failure(.scriptLoadFailed(error.localizedDescription))
        }

        guard let context = JSContext() else {
            return .failure(.contextCreationFailed)
        }

        let log = JSRunLog()
        context.exceptionHandler = { _, exception in
            log.reportException(exception?.toString() ?? "Unknown JS exception")
        }

        JSNativeBridge.install(context: context, logger: log)

        context.evaluateScript(source)
        if let exception = context.exception {
            return .failure(.evaluationFailed(exception.toString() ?? "Unknown error"))
        }

        guard let detector = context.objectForKeyedSubscript("dynamicJailbreakDetection"),
              !detector.isUndefined else {
            return .failure(.entryPointMissing)
        }

        // Use invokeMethod (not calling the fetched function value directly)
        // so `this` inside `start()`/its helpers correctly resolves to the
        // `dynamicJailbreakDetection` object, matching `detector.start()`
        // semantics in JS.
        let rawResult = detector.invokeMethod("start", withArguments: [])
        if let exception = context.exception {
            return .failure(.evaluationFailed(exception.toString() ?? "Unknown error"))
        }

        return .success(JSJailbreakResult.parse(rawResult, log: log))
    }
}
