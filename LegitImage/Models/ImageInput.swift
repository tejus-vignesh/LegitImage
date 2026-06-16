//
//  ImageInput.swift
//  LegitImage
//

import Foundation
import UIKit

/// The bundle of data the analyzer needs to run: the decoded image, the
/// raw file bytes (kept so the C2PA reader can parse the original
/// container), and where the image came from.
struct ImageInput: Hashable {
    let image: UIImage
    let data: Data
    let source: ImageSource
    /// MIME type, if known. Used by Sightengine + C2PA.
    let mimeType: String?

    static func == (lhs: ImageInput, rhs: ImageInput) -> Bool {
        lhs.data == rhs.data && lhs.source == rhs.source && lhs.mimeType == rhs.mimeType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(data)
        hasher.combine(source)
        hasher.combine(mimeType)
    }
}
