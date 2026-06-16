//
//  CheckRowView.swift
//  LegitImage
//
//  One row per detection check. Status badge on the right, plain-English
//  explanation underneath the title.
//

import SwiftUI

struct CheckRowView: View {
    let result: CheckResult

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: result.kind.symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(result.kind.title)
                        .font(.body.weight(.semibold))
                    Spacer(minLength: 8)
                    statusBadge
                }
                Text(result.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch result.status {
        case .pending, .running:
            ProgressView().controlSize(.small)
        case .skipped:
            badge(text: "Skipped", color: .secondary)
        case .failed:
            badge(text: "Error", color: .red)
        case .unreliable(let verdict, _):
            badge(text: verdictText(verdict) + " · low signal", color: verdictColor(verdict))
        case .completed(let verdict):
            badge(text: verdictText(verdict), color: verdictColor(verdict))
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func verdictText(_ verdict: CheckVerdict) -> String {
        switch verdict {
        case .aiGenerated: return "AI"
        case .real:        return "Real"
        case .uncertain:   return "Unclear"
        }
    }

    private func verdictColor(_ verdict: CheckVerdict) -> Color {
        switch verdict {
        case .aiGenerated: return .red
        case .real:        return .green
        case .uncertain:   return .orange
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        CheckRowView(result: CheckResult(
            kind: .c2pa,
            status: .completed(verdict: .real),
            explanation: "Content Credentials present from Sony A7. No AI claim.",
            confidence: 0.8
        ))
        CheckRowView(result: CheckResult(
            kind: .synthID,
            status: .unreliable(verdict: .real, reason: "screenshot"),
            explanation: "No SynthID watermark detected. Note: only Google-generated images carry SynthID.",
            confidence: 0.2
        ))
        CheckRowView(result: CheckResult(
            kind: .sightengine,
            status: .completed(verdict: .aiGenerated),
            explanation: "Visual pattern analysis: 97% likelihood of AI generation. Face age estimate ~28.",
            confidence: 0.97
        ))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
