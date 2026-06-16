//
//  C2PADetector.swift
//  LegitImage
//
//  Reads embedded C2PA Content Credentials from the original image bytes
//  using the c2pa-ios Swift package. The detector is built behind a
//  protocol-driven abstraction so the project compiles whether or not
//  the SPM dependency has been added in Xcode — once added, flip
//  `C2PAProvider.live` to wire in the real reader.
//
//  Add the package via Xcode → File ▸ Add Package Dependencies…
//      https://github.com/contentauth/c2pa-ios
//
//  Then implement `LiveC2PAProvider` to call the package's manifest
//  reader and return one of the result enum cases below.
//

import Foundation

/// What the local C2PA reader found.
enum C2PAFinding {
    /// No C2PA manifest embedded in the image.
    case noManifest
    /// A manifest exists; the issuer claims AI generation (e.g. ChatGPT,
    /// Firefly, Designer). The string is the issuer name for display.
    case aiGenerated(issuer: String)
    /// A manifest exists but does not signal AI generation (e.g. a
    /// camera C2PA manifest from a Sony/Canon body).
    case nonAIManifest(issuer: String)
    /// Manifest was present but malformed / signature failed.
    case invalid(reason: String)
}

/// Boundary that lets us swap the real reader in once c2pa-ios is added.
protocol C2PAProvider: Sendable {
    func read(from data: Data, mimeType: String?) throws -> C2PAFinding
}

/// Default provider — returned when the c2pa-ios SPM package hasn't been
/// added yet. Surfaces a clean "unavailable" status in the UI.
struct UnavailableC2PAProvider: C2PAProvider {
    func read(from data: Data, mimeType: String?) throws -> C2PAFinding {
        throw C2PAUnavailable()
    }
}

struct C2PAUnavailable: LocalizedError {
    var errorDescription: String? {
        "C2PA reader not installed. Add the c2pa-ios Swift package to enable this check."
    }
}

/// Active provider. Replace with the real implementation once the
/// c2pa-ios package is in the project:
///
///     static let live: C2PAProvider = LiveC2PAProvider()
///
enum C2PAProviderRegistry {
    static let live: C2PAProvider = UnavailableC2PAProvider()
}

struct C2PADetector: Detector {
    let kind: CheckKind = .c2pa
    let provider: C2PAProvider

    init(provider: C2PAProvider = C2PAProviderRegistry.live) {
        self.provider = provider
    }

    func run(on input: ImageInput) async -> CheckResult {
        guard APIConfig.Features.c2paEnabled else {
            return .skipped(kind, reason: "C2PA check is disabled in configuration.")
        }
        guard input.source.runsC2PA else {
            return .skipped(kind, reason: "Skipped — screenshots strip the metadata C2PA relies on.")
        }

        do {
            let finding = try provider.read(from: input.data, mimeType: input.mimeType)
            return interpret(finding)
        } catch {
            return .failed(kind, message: error.localizedDescription)
        }
    }

    private func interpret(_ finding: C2PAFinding) -> CheckResult {
        switch finding {
        case .noManifest:
            return CheckResult(
                kind: kind,
                status: .completed(verdict: .uncertain),
                explanation: "No Content Credentials embedded. Absence does not prove a photo is real — most cameras and edits strip the manifest.",
                confidence: 0.4
            )
        case .aiGenerated(let issuer):
            return CheckResult(
                kind: kind,
                status: .completed(verdict: .aiGenerated),
                explanation: "Content Credentials present and signed by \(issuer), which signals AI generation.",
                confidence: 0.95
            )
        case .nonAIManifest(let issuer):
            return CheckResult(
                kind: kind,
                status: .completed(verdict: .real),
                explanation: "Content Credentials present from \(issuer); no AI generation claim found.",
                confidence: 0.75
            )
        case .invalid(let reason):
            return CheckResult(
                kind: kind,
                status: .completed(verdict: .uncertain),
                explanation: "Content Credentials were present but couldn't be verified: \(reason).",
                confidence: 0.3
            )
        }
    }
}
