//
//  ImageLoader.swift
//  LegitImage
//
//  Helpers that turn a PhotosPickerItem or a Files URL into an
//  `ImageInput` with the right source classification.
//

import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum ImageLoaderError: LocalizedError {
    case decodingFailed
    case readFailed

    var errorDescription: String? {
        switch self {
        case .decodingFailed: return "Couldn't decode the selected image."
        case .readFailed:     return "Couldn't read the selected file."
        }
    }
}

enum ImageLoader {

    /// Loads raw data + image from a PhotosPickerItem and inspects the
    /// backing PHAsset to decide whether the source is a screenshot.
    static func load(from item: PhotosPickerItem) async throws -> ImageInput {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ImageLoaderError.readFailed
        }
        guard let image = UIImage(data: data) else {
            throw ImageLoaderError.decodingFailed
        }

        let source: ImageSource = isScreenshot(itemIdentifier: item.itemIdentifier) ? .screenshot : .fileUpload
        let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"

        return ImageInput(image: image, data: data, source: source, mimeType: mime)
    }

    /// Loads from a file URL returned by `.fileImporter`. Files-app
    /// imports are always treated as uploads.
    static func load(fromFileURL url: URL) throws -> ImageInput {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ImageLoaderError.readFailed }

        guard let image = UIImage(data: data) else {
            throw ImageLoaderError.decodingFailed
        }

        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/jpeg"
        return ImageInput(image: image, data: data, source: .fileUpload, mimeType: mime)
    }

    /// Builds an input from a freshly captured camera image. Camera shots
    /// are never screenshots.
    static func make(fromCamera image: UIImage, data: Data?) -> ImageInput {
        let bytes = data ?? image.jpegData(compressionQuality: 0.92) ?? Data()
        return ImageInput(image: image, data: bytes, source: .fileUpload, mimeType: "image/jpeg")
    }

    // MARK: - Screenshot detection
    //
    // PhotosPickerItem doesn't expose mediaSubtypes directly. We resolve
    // the underlying PHAsset using the item's local identifier and look
    // for `photoScreenshot`. If we can't access the asset (e.g. limited
    // Photos permission), default to `fileUpload`.
    private static func isScreenshot(itemIdentifier: String?) -> Bool {
        guard let id = itemIdentifier else { return false }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = result.firstObject else { return false }
        return asset.mediaSubtypes.contains(.photoScreenshot)
    }
}
