//
//  ResultsView.swift
//  LegitImage
//
//  Single-screen verdict view. Shape, from top to bottom:
//    • Thumbnail of the analyzed image
//    • Banner explaining which checks ran (and why)
//    • One CheckRowView per detection pass
//    • The overall verdict card with a one-sentence reasoning line
//

import SwiftUI

struct ResultsView: View {

    @State private var analyzer: ImageAnalyzer
    @State private var hasStarted = false

    init(input: ImageInput) {
        _analyzer = State(initialValue: ImageAnalyzer(input: input))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                thumbnail
                sourceBanner
                checkList
                verdictCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await analyzer.run()
        }
    }

    // MARK: - Sections

    private var thumbnail: some View {
        Image(uiImage: analyzer.report.image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 220)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sourceBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: analyzer.report.source == .screenshot ? "rectangle.dashed" : "doc")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(bannerTitle)
                    .font(.subheadline.weight(.semibold))
                Text(bannerSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var checkList: some View {
        VStack(spacing: 12) {
            ForEach(analyzer.report.results) { result in
                CheckRowView(result: result)
            }
        }
    }

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: analyzer.report.verdict.symbol)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(verdictColor)
                Text(analyzer.report.verdict.title)
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            Text(analyzer.report.reasoning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(verdictColor.opacity(0.35), lineWidth: 1)
        )
        .opacity(analyzer.isRunning ? 0.55 : 1)
        .animation(.default, value: analyzer.isRunning)
    }

    // MARK: - Computed

    private var bannerTitle: String {
        switch analyzer.report.source {
        case .fileUpload: return "Full check — three passes"
        case .screenshot: return "Screenshot — limited check"
        }
    }

    private var bannerSubtitle: String {
        switch analyzer.report.source {
        case .fileUpload:
            return "C2PA, SynthID, and pattern analysis all run. This is the most accurate combination."
        case .screenshot:
            return "Screenshots strip metadata. C2PA is skipped; SynthID is marked low-signal. The verdict relies on pattern analysis."
        }
    }

    private var verdictColor: Color {
        switch analyzer.report.verdict {
        case .aiGenerated: return .red
        case .real:        return .green
        case .uncertain:   return .orange
        }
    }
}

#Preview {
    NavigationStack {
        ResultsView(input: ImageInput(
            image: UIImage(systemName: "photo") ?? UIImage(),
            data: Data(),
            source: .fileUpload,
            mimeType: "image/jpeg"
        ))
    }
}
