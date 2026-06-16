//
//  ShareViewController.swift
//  LegitImageShareExtension
//
//  Accepts an image from the iOS Share Sheet (notably the screenshot
//  screen's Share button), writes it into the App Group container
//  shared with the main app, and wakes the host app with a
//  `legitimage://verify` URL so it opens straight on the results screen.
//
//  This extension is intentionally headless: no UI, no sheet — the
//  user gets bounced into the app immediately.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

// MARK: - App Group constants
//
// Kept in sync with `SharedInbox.swift` in the host app. We don't share
// source files across targets here to keep the extension binary small;
// if either constant changes, update both files.
private let appGroupID = "group.com.LegitImage.shared"
private let hostURLScheme = "legitimage"
private let imageFilename = "shared-image.bin"
private let metaFilename  = "shared-meta.json"

private struct SharedMeta: Codable {
    let mimeType: String?
    let source: String  // "screenshot"
    let writtenAt: Date
}

final class ShareViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await handleShare() }
    }

    private func handleShare() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            complete(); return
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                await loadAndForward(provider: provider)
                return
            }
        }
        complete()
    }

    private func loadAndForward(provider: NSItemProvider) async {
        do {
            let (data, mime) = try await loadImageData(from: provider)
            try writeToAppGroup(data: data, mime: mime)
            await openHostApp()
        } catch {
            NSLog("LegitImage Share extension failed: %@", String(describing: error))
        }
        complete()
    }

    // MARK: - Image loading

    private func loadImageData(from provider: NSItemProvider) async throws -> (Data, String?) {
        if let data = try? await loadDataRepresentation(provider: provider, type: UTType.image.identifier) {
            let mime = sniffMime(from: data) ?? "image/png"
            return (data, mime)
        }
        // Fallback: load as URL (some sources hand off a temp file path).
        let url: URL = try await withCheckedThrowingContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error = error { cont.resume(throwing: error); return }
                if let url = item as? URL { cont.resume(returning: url); return }
                cont.resume(throwing: NSError(domain: "LegitImage", code: -1))
            }
        }
        let data = try Data(contentsOf: url)
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
        return (data, mime)
    }

    private func loadDataRepresentation(provider: NSItemProvider, type: String) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                if let error = error { cont.resume(throwing: error); return }
                if let data = data { cont.resume(returning: data); return }
                cont.resume(throwing: NSError(domain: "LegitImage", code: -2))
            }
        }
    }

    private func sniffMime(from data: Data) -> String? {
        guard data.count >= 4 else { return nil }
        let bytes = [UInt8](data.prefix(8))
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.count >= 12, bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[8] == 0x57 { return "image/webp" }
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
        return nil
    }

    // MARK: - App Group hand-off

    private func writeToAppGroup(data: Data, mime: String?) throws {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw NSError(domain: "LegitImage", code: -3, userInfo: [NSLocalizedDescriptionKey: "App Group container missing"])
        }
        try data.write(to: dir.appendingPathComponent(imageFilename), options: .atomic)
        let meta = SharedMeta(mimeType: mime, source: "screenshot", writtenAt: Date())
        try JSONEncoder().encode(meta)
            .write(to: dir.appendingPathComponent(metaFilename), options: .atomic)
    }

    // MARK: - Host app wake

    @MainActor
    private func openHostApp() async {
        guard let url = URL(string: "\(hostURLScheme)://verify") else { return }
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                _ = await app.open(url, options: [:])
                return
            }
            // Walk up the responder chain looking for the openURL: selector
            // — required because UIApplication.shared isn't available in
            // app extensions.
            if r.responds(to: NSSelectorFromString("openURL:")) {
                _ = r.perform(NSSelectorFromString("openURL:"), with: url)
                return
            }
            responder = r.next
        }
    }

    private func complete() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
