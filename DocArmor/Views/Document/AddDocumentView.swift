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
    @State private var reminderDays: Int? = 30

    // Pages captured/imported (raw, not yet encrypted)
    @State private var capturedImages: [UIImage] = []
    @State private var pageLabels: [String] = []

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

                    if hasExpiration {
                        DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)

                        Picker("Reminder", selection: $reminderDays) {
                            Text("None").tag(Optional<Int>.none)
                            Text("30 days before").tag(Optional<Int>.some(30))
                            Text("60 days before").tag(Optional<Int>.some(60))
                            Text("90 days before").tag(Optional<Int>.some(90))
                        }
                    }
                }

                // MARK: Notes
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // MARK: Pages
                if !isEditing {
                    Section("Document Pages") {
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
                            // Thumbnail preview of captured pages
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
                    reminderDays = doc.expirationReminderDays
                } else {
                    selectedOwnerName = availableHouseholdMembers.first
                    updatePageLabels()
                }
            }
        }
    }

    // MARK: - Validation

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
                doc.expirationReminderDays = hasExpiration ? reminderDays : nil
                doc.updatedAt = .now
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
                    expirationReminderDays: hasExpiration ? reminderDays : nil
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
