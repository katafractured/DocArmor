import SwiftUI
import UniformTypeIdentifiers

/// Full-screen first step of the scan-first onboarding flow.
///
/// Shows capture options (camera, photos, files) immediately when a new document
/// is created. Once the user has captured one or more images, a Continue button
/// appears and a thumbnail strip is shown. Tapping Continue passes the images
/// back to the parent via `onImagesReady`, which transitions to the processing stage.
struct DocumentCaptureStageView: View {

    let selectedType: DocumentType
    let pendingInboxItemsCount: Int
    var onImagesReady: ([UIImage]) -> Void
    var onImportInbox: () -> Void
    var onCancel: () -> Void

    @State private var capturedImages: [UIImage] = []
    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var showingFileImporter = false
    @State private var scannerError: String?
    @State private var importError: String?
    @State private var cropImageIndex: Int? = nil

    private var needsFrontBack: Bool { selectedType.requiresFrontBack }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                Spacer()

                if capturedImages.isEmpty {
                    emptyStateView
                } else {
                    capturedStateView
                }

                Spacer()

                bottomActions
            }
        }
        .sheet(isPresented: $showingScanner) {
            ScannerWrapperView(
                onCompletion: { images in
                    if capturedImages.isEmpty {
                        capturedImages = images
                    } else {
                        capturedImages.append(contentsOf: images)
                    }
                    showingScanner = false
                },
                onCancel: { showingScanner = false },
                onError: { error in
                    showingScanner = false
                    scannerError = error.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPickerView(
                onCompletion: { images in
                    if capturedImages.isEmpty {
                        capturedImages = images
                    } else {
                        capturedImages.append(contentsOf: images)
                    }
                    showingPhotoPicker = false
                },
                onCancel: { showingPhotoPicker = false }
            )
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await importFiles(from: urls) }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { cropImageIndex != nil },
            set: { if !$0 { cropImageIndex = nil } }
        )) {
            if let index = cropImageIndex, capturedImages.indices.contains(index) {
                ImageCropView(
                    image: capturedImages[index],
                    documentType: selectedType
                ) { cropped in
                    capturedImages[index] = cropped
                    cropImageIndex = nil
                } onCancel: {
                    cropImageIndex = nil
                }
            }
        }
        .alert("Camera Unavailable", isPresented: .init(
            get: { scannerError != nil },
            set: { if !$0 { scannerError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scannerError ?? "Check that camera access is allowed in Settings.")
        }
        .alert("Import Failed", isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "The file could not be imported.")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            Spacer()
            Text(capturedImages.isEmpty ? "Scan Document" : "Review Scans")
                .font(.headline)
            Spacer()
            // Balance the × button
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            Text("Scan or import your document")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            if needsFrontBack {
                Label("This document type needs front and back.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Captured state

    private var capturedStateView: some View {
        VStack(spacing: 16) {
            if needsFrontBack {
                HStack(spacing: 16) {
                    sideIndicator("Front", isCaptured: capturedImages.count >= 1)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.tertiary)
                    sideIndicator("Back", isCaptured: capturedImages.count >= 2)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(capturedImages.indices, id: \.self) { i in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: capturedImages[i])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.separator, lineWidth: 1)
                                )

                            Button {
                                cropImageIndex = i
                            } label: {
                                Image(systemName: "crop")
                                    .font(.caption2.bold())
                                    .padding(5)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                        }
                    }

                    // "Add more" tile
                    Button {
                        showingScanner = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(needsFrontBack && capturedImages.count == 1 ? "Add Back" : "Add More")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 120, height: 90)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .foregroundStyle(.secondary.opacity(0.4))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }

            Button(role: .destructive) {
                capturedImages.removeAll()
            } label: {
                Label("Clear All", systemImage: "trash")
                    .font(.caption)
            }
        }
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        VStack(spacing: 12) {
            if !capturedImages.isEmpty {
                Button {
                    onImagesReady(capturedImages)
                } label: {
                    Label("Continue", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
            }

            HStack(spacing: 12) {
                captureOptionButton("Scan", icon: "camera.viewfinder") {
                    showingScanner = true
                }
                captureOptionButton("Photos", icon: "photo.on.rectangle") {
                    showingPhotoPicker = true
                }
                captureOptionButton("Files", icon: "doc.badge.plus") {
                    showingFileImporter = true
                }
                if pendingInboxItemsCount > 0 {
                    captureOptionButton("Inbox (\(pendingInboxItemsCount))", icon: "square.and.arrow.down") {
                        onImportInbox()
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 36)
    }

    // MARK: - Helpers

    private func sideIndicator(_ label: String, isCaptured: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isCaptured ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCaptured ? .green : .secondary)
            Text(label)
                .font(.subheadline.weight(isCaptured ? .semibold : .regular))
        }
    }

    private func captureOptionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - File import

    private func importFiles(from urls: [URL]) async {
        do {
            let result = try DocumentImportNormalizationService.normalize(urls: urls)
            if capturedImages.isEmpty {
                capturedImages = result.images
            } else {
                capturedImages.append(contentsOf: result.images)
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}

#Preview {
    DocumentCaptureStageView(
        selectedType: .driversLicense,
        pendingInboxItemsCount: 2,
        onImagesReady: { _ in },
        onImportInbox: {},
        onCancel: {}
    )
}
