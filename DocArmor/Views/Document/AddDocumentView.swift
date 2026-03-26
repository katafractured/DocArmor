import SwiftUI
import SwiftData

struct AddDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Edit mode: pass an existing document
    var editingDocument: Document?

    // MARK: - Form State

    @State private var name = ""
    @State private var selectedOwnerName: String?
    @State private var selectedType: DocumentType = .driversLicense
    @State private var selectedCategory: DocumentCategory = .identity
    @State private var notes = ""
    @State private var issuerName = ""
    @State private var identifierSuffix = ""
    @State private var hasLastVerified = false
    @State private var lastVerifiedAt = Date.now
    @State private var renewalNotes = ""
    @State private var hasExpiration = false
    @State private var expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var selectedReminderDays: Set<Int> = [30]

    // Pages captured/imported (raw, not yet encrypted)
    @State private var capturedImages: [UIImage] = []
    @State private var pageLabels: [String] = []

    // Existing page thumbnails shown in edit mode (decrypted for preview)
    @State private var existingPageThumbnails: [UIImage] = []
    @State private var isLoadingExistingPages = false

    // OCR suggestions shown as tappable chips after image capture
    @State private var suggestedName: String?
    @State private var suggestedDocNumber: String?
    @State private var suggestedExpiry: Date?

    // Sheet presentation
    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var scannerError: String?
    @State private var householdMembers = HouseholdStore.loadMembers()

    private var isEditing: Bool { editingDocument != nil }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Document Info
                Section("Document Info") {
                    TextField("Name (e.g. John's Passport)", text: $name)
                        .autocorrectionDisabled()

                    if let suggested = suggestedName, name.isEmpty {
                        suggestionChip(label: "Use \"\(suggested)\"") {
                            name = suggested
                            suggestedName = nil
                        }
                    }

                    Picker(selection: $selectedOwnerName) {
                        Label("Shared", systemImage: "person.2.fill").tag(Optional<String>.none)
                        ForEach(availableHouseholdMembers, id: \.self) { member in
                            Label(member, systemImage: "person.fill").tag(Optional(member))
                        }
                    } label: {
                        Label("Person", systemImage: selectedOwnerName == nil ? "person.2.fill" : "person.fill")
                    }
                    .pickerStyle(.menu)

                    Picker(selection: $selectedType) {
                        ForEach(DocumentType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage).tag(type)
                        }
                    } label: {
                        Label("Type", systemImage: selectedType.systemImage)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedType) { _, newType in
                        selectedCategory = newType.defaultCategory
                        updatePageLabels()
                    }

                    Picker(selection: $selectedCategory) {
                        ForEach(DocumentCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.systemImage).tag(cat)
                        }
                    } label: {
                        Label("Category", systemImage: selectedCategory.systemImage)
                    }
                    .pickerStyle(.menu)
                }

                Section("Reference Details") {
                    TextField("Issuing authority", text: $issuerName)
                        .autocorrectionDisabled()

                    TextField("ID or policy suffix", text: $identifierSuffix)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if let suggested = suggestedDocNumber, identifierSuffix.isEmpty {
                        suggestionChip(label: "Use doc number: \(suggested)") {
                            identifierSuffix = suggested
                            suggestedDocNumber = nil
                        }
                    }

                    Toggle("Track last verification", isOn: $hasLastVerified)

                    if hasLastVerified {
                        DatePicker("Last Verified", selection: $lastVerifiedAt, displayedComponents: .date)
                    }

                    TextField("Renewal notes", text: $renewalNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // MARK: Expiration
                Section("Expiration") {
                    Toggle("Has Expiration Date", isOn: $hasExpiration)

                    if !hasExpiration, let suggested = suggestedExpiry {
                        suggestionChip(label: "Set expiry: \(suggested.formatted(date: .abbreviated, time: .omitted))") {
                            hasExpiration = true
                            expirationDate = suggested
                            suggestedExpiry = nil
                        }
                    }

                    if hasExpiration {
                        DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)

                        ForEach([30, 60, 90], id: \.self) { days in
                            Toggle("\(days) days before", isOn: Binding(
                                get: { selectedReminderDays.contains(days) },
                                set: { on in
                                    if on { selectedReminderDays.insert(days) }
                                    else  { selectedReminderDays.remove(days) }
                                }
                            ))
                        }
                    }
                }

                // MARK: Notes
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // MARK: Pages
                Section("Document Pages") {
                    if isEditing {
                        // Existing pages (decrypted thumbnails)
                        if isLoadingExistingPages {
                            ProgressView("Loading pages…")
                        } else if !existingPageThumbnails.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(existingPageThumbnails.indices, id: \.self) { i in
                                        Image(uiImage: existingPageThumbnails[i])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(.separator, lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // New pages to append
                        if !capturedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(capturedImages.indices, id: \.self) { i in
                                        VStack(spacing: 4) {
                                            Image(uiImage: capturedImages[i])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(.tint.opacity(0.6), lineWidth: 2)
                                                )
                                            Text("New")
                                                .font(.caption2)
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            Button(role: .destructive) {
                                capturedImages.removeAll()
                            } label: {
                                Label("Clear New Pages", systemImage: "trash")
                            }
                        }

                        Button(action: { showingScanner = true }) {
                            Label("Add Pages via Scan", systemImage: "camera.viewfinder")
                        }
                        Button(action: { showingPhotoPicker = true }) {
                            Label("Add Pages from Photos", systemImage: "photo.on.rectangle")
                        }
                    } else {
                        if capturedImages.isEmpty {
                            VStack(spacing: 12) {
                                Button(action: { showingScanner = true }) {
                                    Label("Scan Document", systemImage: "camera.viewfinder")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button(action: { showingPhotoPicker = true }) {
                                    Label("Import from Photos", systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(capturedImages.indices, id: \.self) { i in
                                        VStack(spacing: 4) {
                                            Image(uiImage: capturedImages[i])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(.separator, lineWidth: 1)
                                                )
                                            if i < pageLabels.count {
                                                Text(pageLabels[i])
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            Button(role: .destructive) {
                                capturedImages.removeAll()
                            } label: {
                                Label("Clear Pages", systemImage: "trash")
                            }

                            Button(action: { showingScanner = true }) {
                                Label("Rescan", systemImage: "camera.viewfinder")
                            }
                        }
                    }
                }

                // MARK: Save Error
                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Document" : "Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await saveDocument() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerWrapperView(
                    onCompletion: { images in
                        capturedImages = images
                        updatePageLabels()
                        showingScanner = false
                        if let first = images.first { Task { await runOCR(on: first) } }
                    },
                    onCancel: { showingScanner = false },
                    onError: { error in
                        showingScanner = false
                        scannerError = error.localizedDescription
                    }
                )
                .ignoresSafeArea()
            }
            .alert("Camera Unavailable", isPresented: .init(
                get: { scannerError != nil },
                set: { if !$0 { scannerError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerError ?? "The document scanner could not start. Check that camera access is allowed in Settings.")
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView(
                    onCompletion: { images in
                        capturedImages = images
                        updatePageLabels()
                        showingPhotoPicker = false
                        if let first = images.first { Task { await runOCR(on: first) } }
                    },
                    onCancel: { showingPhotoPicker = false }
                )
                .ignoresSafeArea()
            }
            .onAppear {
                if let doc = editingDocument {
                    name = doc.name
                    selectedOwnerName = HouseholdStore.normalize(doc.ownerName)
                    selectedType = doc.documentType
                    selectedCategory = doc.category
                    notes = doc.notes
                    issuerName = doc.issuerName
                    identifierSuffix = doc.identifierSuffix
                    hasLastVerified = doc.lastVerifiedAt != nil
                    if let lastVerified = doc.lastVerifiedAt {
                        lastVerifiedAt = lastVerified
                    }
                    renewalNotes = doc.renewalNotes
                    hasExpiration = doc.expirationDate != nil
                    if let expiry = doc.expirationDate { expirationDate = expiry }
                    selectedReminderDays = Set(doc.expirationReminderDays ?? [])
                    Task { await loadExistingPageThumbnails() }
                } else {
                    selectedOwnerName = availableHouseholdMembers.first
                    updatePageLabels()
                }
            }
        }
    }

    // MARK: - Validation

    private var reminderArrayOrNil: [Int]? {
        let sorted = selectedReminderDays.sorted()
        return sorted.isEmpty ? nil : sorted
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isEditing || !capturedImages.isEmpty)
    }

    private var availableHouseholdMembers: [String] {
        var members = householdMembers
        if let selectedOwnerName, !members.contains(selectedOwnerName) {
            members.append(selectedOwnerName)
        }
        return members.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    // MARK: - Page Labels

    private func updatePageLabels() {
        if selectedType.requiresFrontBack && capturedImages.count >= 2 {
            pageLabels = ["Front", "Back"] + (2..<capturedImages.count).map { "Page \($0 + 1)" }
        } else {
            pageLabels = capturedImages.indices.map { i in
                capturedImages.count == 1 ? "" : "Page \(i + 1)"
            }
        }
    }

    // MARK: - OCR

    private func runOCR(on image: UIImage) async {
        let suggestions = await OCRService.extractSuggestions(from: image)
        if let n = suggestions.name, !n.isEmpty { suggestedName = n }
        if let d = suggestions.documentNumber { suggestedDocNumber = d }
        if let e = suggestions.expirationDate { suggestedExpiry = e }
    }

    private func suggestionChip(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: "sparkles")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(.tint)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load Existing Page Thumbnails

    private func loadExistingPageThumbnails() async {
        guard let doc = editingDocument else { return }
        isLoadingExistingPages = true
        do {
            let key = try VaultKey.load()
            let pages = doc.sortedPages
            var ordered = [Int: UIImage](minimumCapacity: pages.count)
            try await withThrowingTaskGroup(of: (Int, UIImage?).self) { group in
                for (idx, page) in pages.enumerated() {
                    let encData = page.encryptedImageData
                    let nonce   = page.nonce
                    group.addTask(priority: .userInitiated) {
                        let jpeg = try EncryptionService.decrypt(
                            encryptedData: encData, nonce: nonce, using: key)
                        return (idx, UIImage(data: jpeg))
                    }
                }
                for try await (idx, image) in group {
                    ordered[idx] = image
                }
            }
            existingPageThumbnails = (0..<pages.count).compactMap { ordered[$0] }
        } catch {
            // Thumbnails unavailable — edit still works; pages won't be shown
        }
        isLoadingExistingPages = false
    }

    // MARK: - Save

    private func saveDocument() async {
        isSaving = true
        saveError = nil

        do {
            let key = try VaultKey.load()

            if let doc = editingDocument {
                // Update existing document metadata
                doc.name = name.trimmingCharacters(in: .whitespaces)
                doc.ownerName = HouseholdStore.normalize(selectedOwnerName)
                doc.documentTypeRaw = selectedType.rawValue
                doc.categoryRaw = selectedCategory.rawValue
                doc.notes = notes
                doc.issuerName = issuerName.trimmingCharacters(in: .whitespacesAndNewlines)
                doc.identifierSuffix = identifierSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
                doc.lastVerifiedAt = hasLastVerified ? lastVerifiedAt : nil
                doc.renewalNotes = renewalNotes
                doc.expirationDate = hasExpiration ? expirationDate : nil
                doc.expirationReminderDays = hasExpiration ? reminderArrayOrNil : nil
                doc.updatedAt = .now

                // Append any newly captured pages to the existing document
                if !capturedImages.isEmpty {
                    let nextIndex = doc.pages.count
                    for (offset, image) in capturedImages.enumerated() {
                        let jpegData = image.jpegData(compressionQuality: 0.85) ?? Data()
                        let (encrypted, nonce) = try await Task.detached(priority: .userInitiated) {
                            try EncryptionService.encrypt(jpegData, using: key)
                        }.value
                        let page = DocumentPage(
                            pageIndex: nextIndex + offset,
                            encryptedImageData: encrypted,
                            nonce: nonce,
                            label: nil
                        )
                        page.document = doc
                        modelContext.insert(page)
                    }
                }

                ExpirationService.updateReminder(for: doc)
            } else {
                // Create new document + encrypt pages
                let document = Document(
                    name: name.trimmingCharacters(in: .whitespaces),
                    ownerName: HouseholdStore.normalize(selectedOwnerName),
                    documentType: selectedType,
                    category: selectedCategory,
                    notes: notes,
                    issuerName: issuerName.trimmingCharacters(in: .whitespacesAndNewlines),
                    identifierSuffix: identifierSuffix.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastVerifiedAt: hasLastVerified ? lastVerifiedAt : nil,
                    renewalNotes: renewalNotes,
                    expirationDate: hasExpiration ? expirationDate : nil,
                    expirationReminderDays: hasExpiration ? reminderArrayOrNil : nil
                )
                modelContext.insert(document)

                for (index, image) in capturedImages.enumerated() {
                    let jpegData = image.jpegData(compressionQuality: 0.85) ?? Data()
                    let (encrypted, nonce) = try await Task.detached(priority: .userInitiated) {
                        try EncryptionService.encrypt(jpegData, using: key)
                    }.value

                    let label: String? = index < pageLabels.count ? (pageLabels[index].isEmpty ? nil : pageLabels[index]) : nil
                    let page = DocumentPage(
                        pageIndex: index,
                        encryptedImageData: encrypted,
                        nonce: nonce,
                        label: label
                    )
                    page.document = document
                    modelContext.insert(page)
                }

                ExpirationService.scheduleReminder(for: document)
            }

            // Reset flag before dismiss so re-presentation doesn't flash "Saving…"
            isSaving = false
            dismiss()
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

#Preview {
    AddDocumentView()
        .modelContainer(for: [Document.self, DocumentPage.self], inMemory: true)
}
