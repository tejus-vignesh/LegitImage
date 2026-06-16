//
//  ImageAnalyzer.swift
//  LegitImage
//
//  Orchestrates the three detection checks. Owns the lifecycle of an
//  AnalysisReport: starts with all results in `.running`, streams each
//  individual result back as the corresponding network/local call
//  finishes, and finally calls the active VerdictAggregator to compute
//  the overall verdict and reasoning.
//

import Foundation
import UIKit

@MainActor
@Observable
final class ImageAnalyzer {

    /// Live report. The UI observes this; it mutates as checks complete.
    private(set) var report: AnalysisReport
    private(set) var isRunning: Bool = false

    private let detectors: [Detector]
    private let aggregator: VerdictAggregator
    private let input: ImageInput

    init(
        input: ImageInput,
        detectors: [Detector] = [
            C2PADetector(),
            SynthIDDetector(),
            SightengineDetector(),
        ],
        aggregator: VerdictAggregator = VerdictAggregatorRegistry.current
    ) {
        self.input = input
        self.detectors = detectors
        self.aggregator = aggregator
        self.report = AnalysisReport(
            image: input.image,
            source: input.source,
            results: detectors.map { detector in
                CheckResult(
                    kind: detector.kind,
                    status: .running,
                    explanation: "Running…",
                    confidence: nil
                )
            },
            verdict: .uncertain,
            reasoning: "Running checks…"
        )
    }

    /// Kicks off all enabled detectors concurrently. Per-detector results
    /// land in `report.results` as soon as they finish, so the UI shows
    /// progressive disclosure rather than a final reveal.
    func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        await withTaskGroup(of: CheckResult.self) { group in
            for detector in detectors {
                let captured = input
                group.addTask {
                    await detector.run(on: captured)
                }
            }
            for await result in group {
                updateResult(result)
            }
        }

        let outcome = aggregator.aggregate(results: report.results, source: input.source)
        report.verdict = outcome.verdict
        report.reasoning = outcome.reasoning
    }

    private func updateResult(_ result: CheckResult) {
        guard let index = report.results.firstIndex(where: { $0.kind == result.kind }) else { return }
        report.results[index] = result
    }
}
