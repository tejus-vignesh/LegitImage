//
//  ContentView.swift
//  LegitImage
//

import SwiftUI

struct ContentView: View {
    /// Set by the App when a share-extension hand-off arrives.
    /// When non-nil, we push the results screen.
    @Binding var externalInput: ImageInput?

    @State private var pendingInput: ImageInput?

    init(externalInput: Binding<ImageInput?> = .constant(nil)) {
        _externalInput = externalInput
    }

    var body: some View {
        NavigationStack {
            HomeView { input in
                pendingInput = input
            }
            .navigationDestination(item: $pendingInput) { input in
                ResultsView(input: input)
            }
        }
        .onChange(of: externalInput) { _, newValue in
            guard let input = newValue else { return }
            pendingInput = input
            externalInput = nil
        }
    }
}

#Preview {
    ContentView()
}
