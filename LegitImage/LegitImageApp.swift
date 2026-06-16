//
//  LegitImageApp.swift
//  LegitImage
//

import SwiftUI

@main
struct LegitImageApp: App {
    @State private var sharedInput: ImageInput?

    var body: some Scene {
        WindowGroup {
            ContentView(externalInput: $sharedInput)
                .onOpenURL { url in
                    // The Share Extension wakes the app with
                    // `legitimage://verify` after writing the image to
                    // the shared App Group. We consume the inbox and
                    // hand the input to ContentView for routing.
                    guard url.scheme == SharedInbox.urlScheme else { return }
                    if let input = SharedInbox.consume() {
                        sharedInput = input
                    }
                }
        }
    }
}
