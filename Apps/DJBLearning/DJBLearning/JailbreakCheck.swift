//
//  JailbreakCheck.swift
//  DJBLearning
//
//  Common protocol for injectable jailbreak detection heuristics.
//

/// Common protocol that every jailbreak detection heuristic must conform to.
/// Implementations are injected into `JailbreakDetector` from outside the
/// engine - the detector itself has zero knowledge of concrete checks.
protocol JailbreakCheck {
    /// Executes this single check and returns its result.
    func execute() -> JailbreakIndicator
}
