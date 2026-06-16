//
//  HomeView.swift
//  LegitImage
//
//  The first screen. One job: get an image in. Three sources, one button.
//

import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {

    /// Parent uses this to push the results screen once an input is ready.
    let onImageReady: (ImageInput) -> Void

    @State private var showSourceDialog = false
    @State private var photosSelection: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var loadError: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                logo
                Spacer()
                uploadButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }

            if isLoading {
                Color.black.opacity(0.05).ignoresSafeArea()
                ProgressView().controlSize(.large)
            }
        }
        .confirmationDialog("Choose Image", isPresented: $showSourceDialog, titleVisibility: .visible) {
            Button("Photo Library") { showPhotosPicker = true }
            Button("Take Photo")    { showCamera = true }
            Button("Files")         { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photosSelection,
            matching: .images,
            preferredItemEncoding: .current
        )
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onCapture: { image, data in
                    showCamera = false
                    onImageReady(ImageLoader.make(fromCamera: image, data: data))
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: photosSelection) { _, newItem in
            guard let item = newItem else { return }
            loadPhotosPickerItem(item)
        }
        .alert("Couldn't load image", isPresented: Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loadError ?? "")
        }
    }

    // MARK: - Subviews

    private var logo: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.primary)

            Text("LegitImage")
                .font(.system(size: 34, weight: .semibold, design: .default))
                .foregroundStyle(.primary)

            Text("Verify any image")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
    }

    private var uploadButton: some View {
        Button {
            showSourceDialog = true
        } label: {
            Text("Choose Image")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }

    // MARK: - Loaders

    private func loadPhotosPickerItem(_ item: PhotosPickerItem) {
        isLoading = true
        Task {
            defer {
                photosSelection = nil
                isLoading = false
            }
            do {
                let input = try await ImageLoader.load(from: item)
                onImageReady(input)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let input = try ImageLoader.load(fromFileURL: url)
                onImageReady(input)
            } catch {
                loadError = error.localizedDescription
            }
        case .failure(let error):
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    HomeView { _ in }
}
