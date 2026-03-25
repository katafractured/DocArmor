import SwiftUI
import SwiftData
import LocalAuthentication
import UniformTypeIdentifiers

struct SettingsView: View {
    enum BackupOperation: String, Identifiable {
        case export
        case restore

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(AuthService.self) private var auth
    @Environment(AutoLockService.self) private var autoLock
    @Query private var allDocuments: [Document]

    @State private var showingResetAlert = false
    @State private var showingResetConfirm = false
    @State private var isResetting = false
    @State private var householdMembers = HouseholdStore.loadMembers()
    @State private var newMemberName = ""
    @State private var showingRestoreConfirm = false
    @State private var showingFileImporter = false
    @State private var showingFileExporter = false
    @State private var activeBackupOperation: BackupOperation?
    @State private var pendingImportURL: URL?
    @State private var backupDocument = EncryptedBackupDocument()
    @State private var backupFilename = BackupService.defaultFilename()
    @State private var backupError: String?
    @State private var backupSuccessMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Security
                Section("Security") {
                    Picker("Auto-Lock", selection: autoLockTimeoutBinding) {
                        ForEach(AutoLockService.Timeout.allCases) { timeout in
                            Text(timeout.displayName).tag(timeout)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Label("Biometrics", systemImage: biometryIcon)
                        Spacer()
                        Text(biometryName)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Vault
                Section("Vault") {
                    HStack {
                        Label("Documents", systemImage: "doc.fill")
                        Spacer()
                        Text("\(allDocuments.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset Vault", systemImage: "trash.fill")
                            .foregroundStyle(.red)
                    }
                    .disabled(isResetting)
                }

                Section("Encrypted Backup") {
                    Button {
                        activeBackupOperation = .export
                    } label: {
                        Label("Export Encrypted Backup", systemImage: "square.and.arrow.up.fill")
                    }

                    Button {
                        showingRestoreConfirm = true
                    } label: {
                        Label("Restore Encrypted Backup", systemImage: "square.and.arrow.down.fill")
                    }

                    Text("Backups are encrypted with a passphrase you choose. DocArmor cannot recover that passphrase for you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Household") {
                    if householdMembers.isEmpty {
                        Text("No family members added yet. Add one to organize documents per person.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(householdMembers, id: \.self) { member in
                            HStack {
                                Label(member, systemImage: "person.fill")
                                Spacer()
                                Text("\(documentCount(for: member))")
                                    .foregroundStyle(.secondary)
                                Button {
                                    householdMembers = HouseholdStore.removeMember(named: member)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("Add family member", text: $newMemberName)
                            .autocorrectionDisabled()
                        Button("Add") {
                            householdMembers = HouseholdStore.addMember(named: newMemberName)
                            newMemberName = ""
                        }
                        .disabled(HouseholdStore.normalize(newMemberName) == nil)
                    }

                    Label("Documents can also stay shared for the whole household.", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Developer", systemImage: "person.fill")
                        Spacer()
                        Text("Katafract LLC")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Support & Legal") {
                    externalLinkRow(
                        title: "App Page",
                        systemImage: "app.badge",
                        urlString: "https://katafract.com/apps/docarmor"
                    )

                    externalLinkRow(
                        title: "Support",
                        systemImage: "questionmark.circle",
                        urlString: "https://katafract.com/support/docarmor"
                    )

                    externalLinkRow(
                        title: "Privacy Policy",
                        systemImage: "hand.raised.fill",
                        urlString: "https://katafract.com/privacy/docarmor"
                    )

                    externalLinkRow(
                        title: "Terms of Use",
                        systemImage: "doc.text",
                        urlString: "https://katafract.com/terms/docarmor"
                    )
                }

                // MARK: Privacy Statement
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("100% Local Storage", systemImage: "iphone")
                            .font(.caption.bold())
                        Text("Your documents never leave this device. DocArmor makes zero network connections and has no server infrastructure.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Vault?", isPresented: $showingResetAlert) {
                Button("Reset Everything", role: .destructive) {
                    showingResetConfirm = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete ALL documents and the encryption key. Your data will be unrecoverable. This cannot be undone.")
            }
            .confirmationDialog("Are you absolutely sure?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
                Button("Delete Everything Forever", role: .destructive) {
                    Task { await resetVault() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All \(allDocuments.count) document(s) will be permanently destroyed.")
            }
            .confirmationDialog("Restore Backup?", isPresented: $showingRestoreConfirm, titleVisibility: .visible) {
                Button("Choose Backup File", role: .destructive) {
                    showingFileImporter = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Restoring replaces the current vault, its encryption key, and reminders with the contents of the backup file.")
            }
            .sheet(item: $activeBackupOperation) { operation in
                BackupPassphraseSheet(operation: operation) { passphrase in
                    Task { await handleBackupPassphrase(passphrase, operation: operation) }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    pendingImportURL = urls.first
                    activeBackupOperation = .restore
                case .failure(let error):
                    backupError = error.localizedDescription
                }
            }
            .fileExporter(
                isPresented: $showingFileExporter,
                document: backupDocument,
                contentType: .data,
                defaultFilename: backupFilename
            ) { result in
                switch result {
                case .success:
                    backupSuccessMessage = "Encrypted backup exported successfully."
                case .failure(let error):
                    backupError = error.localizedDescription
                }
            }
            .alert("Backup Error", isPresented: backupErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupError ?? "The encrypted backup operation failed.")
            }
            .alert("Backup Complete", isPresented: backupSuccessBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupSuccessMessage ?? "Done.")
            }
        }
    }

    // MARK: - Reset Vault

    private func resetVault() async {
        isResetting = true
        ExpirationService.cancelAllReminders()

        // Delete all SwiftData records
        for doc in allDocuments {
            modelContext.delete(doc)
        }

        // Explicitly save before touching the Keychain. SwiftData batches deletes
        // and may not flush until the next auto-save window; if the app crashes
        // after VaultKey.delete() but before the context saves, stale encrypted
        // records remain — now undecryptable with the new key.
        try? modelContext.save()

        // Delete vault encryption key — encrypted data is now unrecoverable garbage
        try? VaultKey.delete()

        // Generate a fresh key for any future use
        _ = try? VaultKey.generate()

        auth.lock()
        isResetting = false
    }

    @MainActor
    private func handleBackupPassphrase(_ passphrase: String, operation: BackupOperation) async {
        do {
            switch operation {
            case .export:
                backupDocument = try BackupService.exportBackup(
                    documents: allDocuments,
                    householdMembers: householdMembers,
                    passphrase: passphrase
                )
                backupFilename = BackupService.defaultFilename()
                showingFileExporter = true
            case .restore:
                guard let importURL = pendingImportURL else {
                    backupError = "Choose a backup file to restore."
                    return
                }
                let didAccess = importURL.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        importURL.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: importURL)
                try BackupService.restoreBackup(from: data, passphrase: passphrase, into: modelContext)
                householdMembers = HouseholdStore.loadMembers()
                pendingImportURL = nil
                backupSuccessMessage = "Encrypted backup restored successfully."
            }
        } catch {
            backupError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private var biometryIcon: String {
        switch auth.biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.fill"
        }
    }

    private var autoLockTimeoutBinding: Binding<AutoLockService.Timeout> {
        Binding(
            get: { autoLock.selectedTimeout },
            set: { autoLock.selectedTimeout = $0 }
        )
    }

    private var biometryName: String {
        switch auth.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "Passcode"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var backupErrorBinding: Binding<Bool> {
        Binding(
            get: { backupError != nil },
            set: { if !$0 { backupError = nil } }
        )
    }

    private var backupSuccessBinding: Binding<Bool> {
        Binding(
            get: { backupSuccessMessage != nil },
            set: { if !$0 { backupSuccessMessage = nil } }
        )
    }

    private func documentCount(for member: String) -> Int {
        allDocuments.filter { $0.ownerDisplayName == member }.count
    }

    @ViewBuilder
    private func externalLinkRow(title: String, systemImage: String, urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Button {
                openURL(url)
            } label: {
                HStack {
                    Label(title, systemImage: systemImage)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Document.self, DocumentPage.self], inMemory: true)
        .environment(AuthService())
        .environment(AutoLockService(authService: AuthService()))
}
