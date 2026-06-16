//
//  VerdictAggregator.swift
//  LegitImage
//
//  Strategy seam for combining the three per-check verdicts into one
//  overall verdict + reasoning sentence. Multiple implementations live
//  here so we can swap strategies in one line (see
//  `VerdictAggregator.current`) while we evaluate which feels right.
//

import Foundation

/// Output of an aggregation pass.
struct AggregationOutcome: Equatable {
    let verdict: OverallVerdict
    let reasoning: String
}

protocol VerdictAggregator: Sendable {
    func aggregate(results: [CheckResult], source: ImageSource) -> AggregationOutcome
}

// MARK: - Strategies

/// Source-weighted weighted vote.
///
/// - For uploads, all three checks contribute. C2PA carries the most
///   weight (signed provenance), Sightengine next, SynthID last.
/// - For screenshots, Sightengine dominates because it's the only check
///   that actually examines pixels.
struct WeightedVerdictAggregator: VerdictAggregator {

    func aggregate(results: [CheckResult], source: ImageSource) -> AggregationOutcome {
        var aiWeight: Double = 0
        var realWeight: Double = 0
        var uncertainWeight: Double = 0
        var contributing: [String] = []

        for result in results {
            let weight = weight(for: result.kind, source: source, status: result.status)
            guard weight > 0, let verdict = result.status.verdict else { continue }

            switch verdict {
            case .aiGenerated: aiWeight += weight
            case .real:        realWeight += weight
            case .uncertain:   uncertainWeight += weight
            }
            contributing.append(label(for: result))
        }

        let total = aiWeight + realWeight + uncertainWeight
        guard total > 0 else {
            return AggregationOutcome(
                verdict: .uncertain,
                reasoning: "None of the checks produced a usable signal."
            )
        }

        let verdict: OverallVerdict
        if aiWeight >= realWeight && aiWeight >= uncertainWeight && aiWeight / total >= 0.4 {
            verdict = .aiGenerated
        } else if realWeight > aiWeight && realWeight / total >= 0.5 {
            verdict = .real
        } else {
            verdict = .uncertain
        }

        let reasoning = buildReasoning(verdict: verdict, contributing: contributing, source: source)
        return AggregationOutcome(verdict: verdict, reasoning: reasoning)
    }

    // MARK: weights

    private func weight(for kind: CheckKind, source: ImageSource, status: CheckStatus) -> Double {
        // Unreliable checks contribute, but at a fraction.
        let isUnreliable: Bool
        if case .unreliable = status { isUnreliable = true } else { isUnreliable = false }

        let base: Double = {
            switch (kind, source) {
            case (.c2pa, .fileUpload):        return 1.0
            case (.c2pa, .screenshot):        return 0.0
            case (.sightengine, .fileUpload): return 0.8
            case (.sightengine, .screenshot): return 1.0
            case (.synthID, .fileUpload):     return 0.6
            case (.synthID, .screenshot):     return 0.3
            }
        }()

        return isUnreliable ? base * 0.3 : base
    }

    private func label(for result: CheckResult) -> String {
        guard let verdict = result.status.verdict else { return result.kind.title }
        switch verdict {
        case .aiGenerated: return "\(result.kind.title) flagged AI"
        case .real:        return "\(result.kind.title) looked clean"
        case .uncertain:   return "\(result.kind.title) was uncertain"
        }
    }

    private func buildReasoning(verdict: OverallVerdict, contributing: [String], source: ImageSource) -> String {
        let intro: String
        switch verdict {
        case .aiGenerated: intro = "Multiple checks point to AI generation."
        case .real:        intro = "Checks agree this looks like a real photograph."
        case .uncertain:   intro = "Signals disagree — can't say for sure."
        }
        guard !contributing.isEmpty else { return intro }
        let summary = contributing.joined(separator: " · ")
        return "\(intro) \(summary)."
    }
}

/// Unanimous-vote aggregator: AI only if every running check says AI;
/// Real only if every running check says Real; otherwise Uncertain.
/// Useful for very conservative gating.
struct UnanimousVerdictAggregator: VerdictAggregator {
    func aggregate(results: [CheckResult], source: ImageSource) -> AggregationOutcome {
        let usable = results.compactMap { $0.status.verdict }
        guard !usable.isEmpty else {
            return AggregationOutcome(verdict: .uncertain, reasoning: "No checks produced a signal.")
        }
        if usable.allSatisfy({ $0 == .aiGenerated }) {
            return AggregationOutcome(verdict: .aiGenerated, reasoning: "Every check agreed: AI-generated.")
        }
        if usable.allSatisfy({ $0 == .real }) {
            return AggregationOutcome(verdict: .real, reasoning: "Every check agreed: real photograph.")
        }
        return AggregationOutcome(verdict: .uncertain, reasoning: "Checks disagreed; result is inconclusive.")
    }
}

/// Highest-confidence-wins aggregator: pick whichever check has the
/// largest weight × confidence and use its verdict. Quick to reason
/// about, easy to break with one noisy signal.
struct HighestConfidenceAggregator: VerdictAggregator {
    private let weighted = WeightedVerdictAggregator()

    func aggregate(results: [CheckResult], source: ImageSource) -> AggregationOutcome {
        let scored = results.compactMap { result -> (CheckResult, Double)? in
            guard let verdict = result.status.verdict else { return nil }
            _ = verdict
            let confidence = result.confidence ?? 0.5
            return (result, confidence)
        }
        guard let top = scored.max(by: { $0.1 < $1.1 }),
              let verdict = top.0.status.verdict else {
            return AggregationOutcome(verdict: .uncertain, reasoning: "No usable check results.")
        }
        let overall: OverallVerdict = {
            switch verdict {
            case .aiGenerated: return .aiGenerated
            case .real:        return .real
            case .uncertain:   return .uncertain
            }
        }()
        return AggregationOutcome(
            verdict: overall,
            reasoning: "Driven by \(top.0.kind.title) with the strongest signal."
        )
    }
}

// MARK: - Active strategy
//
// Swap the strategy here to evaluate behavior. No other file needs to
// change.
enum VerdictAggregatorRegistry {
    static let current: VerdictAggregator = WeightedVerdictAggregator()
}
