//
//  DetectorProtocol.swift
//  LegitImage
//

import Foundation

/// Every detection check conforms to this so the orchestrator can call
/// them uniformly. Implementations are responsible for honoring feature
/// flags in `APIConfig` and for returning a `.skipped` status when the
/// input source makes the check meaningless.
protocol Detector: Sendable {
    var kind: CheckKind { get }
    func run(on input: ImageInput) async -> CheckResult
}

/// Convenience builders to keep call sites readable.
extension CheckResult {
    static func skipped(_ kind: CheckKind, reason: String) -> CheckResult {
        CheckResult(kind: kind, status: .skipped(reason: reason), explanation: reason, confidence: nil)
    }

    static func failed(_ kind: CheckKind, message: String) -> CheckResult {
        CheckResult(kind: kind, status: .failed(message: message), explanation: message, confidence: nil)
    }
}
