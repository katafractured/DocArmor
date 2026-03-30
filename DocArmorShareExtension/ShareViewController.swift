import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let importButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        refreshDetailText()
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.text = "Save to DocArmor"
        titleLabel.textAlignment = .center

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center

        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.configuration = .filled()
        importButton.configuration?.title = "Import"
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.configuration = .plain()
        cancelButton.configuration?.title = "Cancel"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            detailLabel,
            activityIndicator,
            importButton,
            cancelButton
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func refreshDetailText() {
        let count = attachmentProviders.count
        detailLabel.text = count == 0
            ? "No supported attachments were found in this share item."
            : "DocArmor will copy \(count) attachment\(count == 1 ? "" : "s") into its secure import inbox."
        importButton.isEnabled = count > 0
    }

    private var attachmentProviders: [NSItemProvider] {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        return items
            .flatMap { $0.attachments ?? [] }
            .filter { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            }
    }

    @objc
    private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(domain: "DocArmorShareExtension", code: 0))
    }

    @objc
    private func importTapped() {
        setImporting(true)
        Task {
            do {
                try await persistAttachments()
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                presentError(error.localizedDescription)
                setImporting(false)
            }
        }
    }

    private func setImporting(_ importing: Bool) {
        importButton.isEnabled = !importing
        cancelButton.isEnabled = !importing
        importing ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    private func persistAttachments() async throws {
        let folder = try importFolderURL()
        for provider in attachmentProviders {
            try await persist(provider: provider, into: folder)
        }
    }

    private func persist(provider: NSItemProvider, into folder: URL) async throws {
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            try await persistFileRepresentation(provider: provider, type: .pdf, into: folder)
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            try await persistImage(provider: provider, into: folder)
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            try await persistFileURL(provider: provider, into: folder)
            return
        }
        try await persistFileRepresentation(provider: provider, type: .data, into: folder)
    }

    private func persistImage(provider: NSItemProvider, into folder: URL) async throws {
        let data = try await loadDataRepresentation(provider: provider, type: .image)
        let fileURL = folder.appendingPathComponent("share-\(UUID().uuidString).jpg")
        try data.write(to: fileURL, options: .atomic)
    }

    private func persistFileURL(provider: NSItemProvider, into folder: URL) async throws {
        let fileURL = try await loadFileURL(provider: provider)
        let destination = uniqueDestinationURL(in: folder, preferredName: fileURL.lastPathComponent)
        try FileManager.default.copyItem(at: fileURL, to: destination)
    }

    private func persistFileRepresentation(
        provider: NSItemProvider,
        type: UTType,
        into folder: URL
    ) async throws {
        let sourceURL = try await loadFileRepresentation(provider: provider, type: type)
        let destination = uniqueDestinationURL(in: folder, preferredName: sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
    }

    private func importFolderURL() throws -> URL {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.katafract.DocArmor") else {
            throw NSError(domain: "DocArmorShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group container is unavailable."])
        }
        let folder = root.appendingPathComponent("ImportInbox", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func uniqueDestinationURL(in folder: URL, preferredName: String) -> URL {
        let baseName = URL(fileURLWithPath: preferredName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: preferredName).pathExtension
        let sanitizedBase = baseName.isEmpty ? "import-\(UUID().uuidString)" : baseName
        let filename = ext.isEmpty ? sanitizedBase : "\(sanitizedBase).\(ext)"
        return folder.appendingPathComponent("\(UUID().uuidString)-\(filename)")
    }

    private func loadFileRepresentation(provider: NSItemProvider, type: UTType) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "DocArmorShareExtension", code: 2, userInfo: [NSLocalizedDescriptionKey: "File representation was unavailable."]))
                }
            }
        }
    }

    private func loadDataRepresentation(provider: NSItemProvider, type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "DocArmorShareExtension", code: 3, userInfo: [NSLocalizedDescriptionKey: "Image data was unavailable."]))
                }
            }
        }
    }

    private func loadFileURL(provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = item as? Data,
                   let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? {
                    continuation.resume(returning: url)
                    return
                }
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                continuation.resume(throwing: NSError(domain: "DocArmorShareExtension", code: 4, userInfo: [NSLocalizedDescriptionKey: "Shared file URL was unavailable."]))
            }
        }
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Import Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
