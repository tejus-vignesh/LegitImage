//
//  CheckResult.swift
//  LegitImage
//

import Foundation

/// Identifies one of the three detection passes.
enum CheckKind: String, CaseIterable, Identifiable {
    case c2pa
    case synthID
    case sightengine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .c2pa:        return "Content Credentials"
        case .synthID:     return "SynthID Watermark"
        case .sightengine: return "AI Pattern Analysis"
        }
    }

    var subtitle: String {
        switch self {
        case .c2pa:        return "Embedded provenance (C2PA)"
        case .synthID:     return "Google watermark detection"
        case .sightengine: return "Visual pixel pattern check"
        }
    }

    var symbol: String {
        switch self {
        case .c2pa:        return "seal"
        case .synthID:     return "drop"
        case .sightengine: return "sparkle.magnifyingglass"
        }
    }
}

/// Per-check verdict. Aggregated by the `VerdictAggregator` into an
/// overall verdict at the end of analysis.
enum CheckVerdict: Equatable {
    case aiGenerated
    case real
    case uncertain
}

/// Lifecycle of a single check.
enum CheckStatus: Equatable {
    case pending
    case running
    case skipped(reason: String)
    case unreliable(verdict: CheckVerdict, reason: String)
    case completed(verdict: CheckVerdict)
    case failed(message: String)

    var verdict: CheckVerdict? {
        switch self {
        case .completed(let v):       return v
        case .unreliable(let v, _):   return v
        default:                      return nil
        }
    }

    var isTerminal: Bool {
        switch self {
        case .pending, .running: return false
        default:                 return true
        }
    }
}

/// A single check's result, ready for the UI.
struct CheckResult: Identifiable, Equatable {
    let kind: CheckKind
    var status: CheckStatus
    /// Plain-language sentence explaining what the check found.
    var explanation: String
    /// Optional 0...1 confidence; used by the weighted aggregator.
    var confidence: Double?

    var id: String { kind.id }
}
