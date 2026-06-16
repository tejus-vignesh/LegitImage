//
//  ContentView.swift
//  LegitImage
//

import SwiftUI

struct ContentView: View {
    @State private var pendingInput: ImageInput?

    var body: some View {
        NavigationStack {
            HomeView { input in
                pendingInput = input
            }
            .navigationDestination(item: $pendingInput) { input in
                // Placeholder until ResultsView lands in the next milestone.
                ResultsPlaceholderView(input: input)
            }
        }
    }
}

private struct ResultsPlaceholderView: View {
    let input: ImageInput

    var body: some View {
        VStack(spacing: 16) {
            Image(uiImage: input.image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Source: \(input.source.displayName)")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
