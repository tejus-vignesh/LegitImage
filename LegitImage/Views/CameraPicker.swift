//
//  CameraPicker.swift
//  LegitImage
//
//  Thin SwiftUI wrapper around UIImagePickerController for camera capture.
//  SwiftUI does not yet expose a first-party camera view, so this stays.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage, Data?) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onCancel(); return
            }
            // Re-encode to JPEG so we have raw bytes for the network calls.
            let data = image.jpegData(compressionQuality: 0.92)
            parent.onCapture(image, data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
