//
//  AnalysisReport.swift
//  LegitImage
//

import Foundation
import UIKit

/// Final verdict shown at the top of the results screen.
enum OverallVerdict: Equatable {
    case aiGenerated
    case real
    case uncertain

    var title: String {
        switch self {
        case .aiGenerated: return "Likely AI-Generated"
        case .real:        return "Likely Real"
        case .uncertain:   return "Inconclusive"
        }
    }

    var symbol: String {
        switch self {
        case .aiGenerated: return "exclamationmark.triangle.fill"
        case .real:        return "checkmark.seal.fill"
        case .uncertain:   return "questionmark.circle.fill"
        }
    }
}

/// A snapshot of one full analysis run.
struct AnalysisReport: Equatable {
    let image: UIImage
    let source: ImageSource
    var results: [CheckResult]
    var verdict: OverallVerdict
    /// One-sentence reasoning shown beneath the verdict.
    var reasoning: String

    static func == (lhs: AnalysisReport, rhs: AnalysisReport) -> Bool {
        lhs.source == rhs.source &&
        lhs.results == rhs.results &&
        lhs.verdict == rhs.verdict &&
        lhs.reasoning == rhs.reasoning
    }
}
