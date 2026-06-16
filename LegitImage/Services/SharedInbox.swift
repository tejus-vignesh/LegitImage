//
//  SharedInbox.swift
//  LegitImage
//
//  Hand-off channel between the Share Extension and the main app. The
//  extension writes the shared image bytes (and a tiny metadata file)
//  into the App Group container; the main app polls / reads on open.
//
//  Both targets must share the same App Group identifier — keep that
//  identifier in one place (`appGroupID`) so it can't drift.
//

import Foundation
import UIKit

enum SharedInbox {
    /// App Group identifier. Add this group to **both** the app target
    /// and the Share Extension target via Signing & Capabilities.
    static let appGroupID = "group.com.LegitImage.shared"

    /// URL scheme the extension uses to wake the host app after writing
    /// an image. Declared in the app's Info.plist (CFBundleURLTypes).
    static let urlScheme = "legitimage"

    private static let imageFilename = "shared-image.bin"
    private static let metaFilename  = "shared-meta.json"

    struct Meta: Codable {
        let mimeType: String?
        /// Set by the Share Extension to `.screenshot`. The app respects
        /// whatever the extension wrote so weighting + reasoning match.
        let source: String
        let writtenAt: Date
    }

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Persists an image to the shared container. Called by the extension.
    static func write(imageData: Data, mimeType: String?, source: ImageSource) throws {
        guard let dir = containerURL else { throw SharedInboxError.containerUnavailable }
        let imageURL = dir.appendingPathComponent(imageFilename)
        let metaURL  = dir.appendingPathComponent(metaFilename)
        try imageData.write(to: imageURL, options: .atomic)
        let meta = Meta(
            mimeType: mimeType,
            source: source == .screenshot ? "screenshot" : "fileUpload",
            writtenAt: Date()
        )
        try JSONEncoder().encode(meta).write(to: metaURL, options: .atomic)
    }

    /// Reads and clears the shared image. Called by the main app on
    /// receiving a `legitimage://verify` URL.
    static func consume() -> ImageInput? {
        guard let dir = containerURL else { return nil }
        let imageURL = dir.appendingPathComponent(imageFilename)
        let metaURL  = dir.appendingPathComponent(metaFilename)

        guard let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data) else {
            return nil
        }

        let meta = (try? JSONDecoder().decode(Meta.self, from: Data(contentsOf: metaURL)))
        let source: ImageSource = (meta?.source == "screenshot") ? .screenshot : .fileUpload

        // Remove so we don't replay the same image on next launch.
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: metaURL)

        return ImageInput(image: image, data: data, source: source, mimeType: meta?.mimeType)
    }
}

enum SharedInboxError: LocalizedError {
    case containerUnavailable

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "App Group container not available. Check the App Group capability on both targets."
        }
    }
}
