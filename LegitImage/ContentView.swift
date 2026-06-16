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
                ResultsView(input: input)
            }
        }
    }
}

#Preview {
    ContentView()
}
