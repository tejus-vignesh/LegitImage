//
//  ImageSource.swift
//  LegitImage
//

import Foundation

/// How the image arrived in the app. The source decides which checks run
/// and how their results are weighted in the final verdict.
enum ImageSource: Equatable {
    /// User picked a file (Photos non-screenshot, Camera, or Files).
    /// All three checks run; metadata is trustworthy.
    case fileUpload

    /// Image is a screenshot — either flagged by the Photos asset, or
    /// arrived through the Share Extension straight from the iOS
    /// screenshot screen. Metadata is stripped, so C2PA is skipped and
    /// SynthID is marked unreliable.
    case screenshot

    var displayName: String {
        switch self {
        case .fileUpload: return "Uploaded file"
        case .screenshot: return "Screenshot"
        }
    }

    var runsC2PA: Bool { self == .fileUpload }
    var synthIDIsReliable: Bool { self == .fileUpload }
}
