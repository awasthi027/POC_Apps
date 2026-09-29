//
//  StandardJailbreakChecks.swift
//  DJBLearning
//

/// Convenience factory that produces the standard set of checks. This is
/// intentionally NOT used automatically by `JailbreakDetector` - it must be
/// explicitly injected by the caller:
///
/// ```swift
/// JailbreakDetector.shared.register(StandardJailbreakChecks.all)
/// ```
///
/// Consumers are free to register a custom subset, add their own
/// `JailbreakCheck` types, or omit this factory entirely and inject only
/// hand-picked checks.
enum StandardJailbreakChecks {
    static var all: [JailbreakCheck] {
        [
            SandboxIntegrityCheck(),
            DylibInjectionCheck(),
            SymbolicLinkCheck(),
            JailbreakEnvironmentCheck(),
            ApplicationRestrictionsCheck(),
            CydiaPresenceCheck(),
            ProcessNameIntegrityCheck(),
            JailbreakBundleCheck()
        ]
    }
}
