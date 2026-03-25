import SwiftUI
import SwiftData

struct VaultView: View {
    private enum BundleFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case readyNow = "Ready Now"
        case travel = "Travel Set"
        case medical = "Medical"
        case work = "Work"
        case attention = "Needs Attention"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .readyNow: return "bolt.shield.fill"
            case .travel: return "airplane.departure"
            case .medical: return "cross.case.fill"
            case .work: return "briefcase.fill"
            case .attention: return "exclamationmark.triangle.fill"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.createdAt, order: .reverse) private var allDocuments: [Document]

    @State private var searchText = ""
    @State private var showingAddDocument = false
    @State private var navigationPath = NavigationPath()
    @State private var selectedBundleFilter: BundleFilter = .all
    @State private var selectedTypeFilter: DocumentType?
    @State private var selectedOwnerFilter: String?

    var pendingDocumentType: Binding<DocumentType?>
    var pendingCategory: Binding<DocumentCategory?>

    // MARK: - Computed

    private let sharedOwnerToken = "__shared__"

    private var filteredDocuments: [Document] {
        allDocuments.filter { document in
            let matchesSearch =
                searchText.isEmpty ||
                document.name.localizedCaseInsensitiveContains(searchText) ||
                document.documentType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                document.ownerDisplayName.localizedCaseInsensitiveContains(searchText)

            let matchesType =
                selectedTypeFilter == nil ||
                document.documentType == selectedTypeFilter

            let matchesOwner: Bool
            if let selectedOwnerFilter {
                if selectedOwnerFilter == sharedOwnerToken {
                    matchesOwner = HouseholdStore.normalize(document.ownerName) == nil
                } else {
                    matchesOwner = document.ownerDisplayName == selectedOwnerFilter
                }
            } else {
                matchesOwner = true
            }

            let matchesBundle = matches(document: document, bundle: selectedBundleFilter)

            return matchesSearch && matchesType && matchesOwner && matchesBundle
        }
    }

    private var favorites: [Document] {
        filteredDocuments.filter { $0.isFavorite }
    }

    private var documentsByCategory: [(DocumentCategory, [Document])] {
        let nonFavorites = filteredDocuments.filter { !$0.isFavorite }
        return DocumentCategory.allCases.compactMap { category in
            let docs = nonFavorites.filter { $0.category == category }
            return docs.isEmpty ? nil : (category, docs)
        }
    }

    private var ownerFilterOptions: [String] {
        var options = allDocuments.map(\.ownerDisplayName)
        if allDocuments.contains(where: { HouseholdStore.normalize($0.ownerName) == nil }) {
            options.append("Shared")
        }
        return Array(Set(options)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private var snapshotFingerprint: String {
        allDocuments
            .map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
    }

    private var expiringSoonDocuments: [Document] {
        allDocuments.filter(\.expiresSoon)
    }

    private var attentionDocuments: [Document] {
        allDocuments.filter(\.needsAttention)
    }

    private var recentlyAddedDocuments: [Document] {
        Array(allDocuments.prefix(3))
    }

    private var membersMissingPrimaryIDCount: Int {
        let members = HouseholdStore.loadMembers()
        let essentialTypes: Set<DocumentType> = [.driversLicense, .passport, .stateID]
        return members.filter { member in
            !allDocuments.contains { $0.ownerDisplayName == member && essentialTypes.contains($0.documentType) }
        }.count
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if !allDocuments.isEmpty {
                    filterBar
                }

                if allDocuments.isEmpty {
                    emptyStateView
                } else if filteredDocuments.isEmpty {
                    ContentUnavailableView(
                        "No Matching Documents",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different search, type filter, or person filter.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    documentList
                }
            }
            .navigationTitle("DocArmor")
            .navigationDestination(for: Document.self) { document in
                DocumentDetailView(document: document)
            }
            .searchable(text: $searchText, prompt: "Search documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddDocument = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddDocument) {
                AddDocumentView()
            }
            .onChange(of: pendingDocumentType.wrappedValue) { _, type in
                guard let type else { return }
                // VaultView is only in the hierarchy when auth.state == .unlocked,
                // so this onChange fires only after the user has authenticated.
                // Do NOT clear the pending value on the lock screen path — the
                // DocArmorApp.onOpenURL handler sets it; we consume it here.
                if let doc = allDocuments.first(where: { $0.documentType == type }) {
                    navigationPath.append(doc)
                }
                pendingDocumentType.wrappedValue = nil
            }
            .onChange(of: pendingCategory.wrappedValue) { _, category in
                guard let category else { return }
                if let doc = allDocuments.first(where: { $0.category == category }) {
                    navigationPath.append(doc)
                }
                pendingCategory.wrappedValue = nil
            }
            .task(id: snapshotFingerprint) {
                updateWidgetSnapshot()
            }
        }
    }

    // MARK: - Document List

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(BundleFilter.allCases) { bundle in
                        Button {
                            selectedBundleFilter = bundle
                        } label: {
                            Label(bundle.rawValue, systemImage: bundle.systemImage)
                        }
                    }
                } label: {
                    filterChip(
                        title: selectedBundleFilter.rawValue,
                        systemImage: selectedBundleFilter.systemImage
                    )
                }

                Menu {
                    Button {
                        selectedTypeFilter = nil
                    } label: {
                        Label("All Types", systemImage: "square.grid.2x2")
                    }

                    ForEach(DocumentType.allCases, id: \.self) { type in
                        Button {
                            selectedTypeFilter = type
                        } label: {
                            Label(type.rawValue, systemImage: type.systemImage)
                        }
                    }
                } label: {
                    filterChip(
                        title: selectedTypeFilter?.rawValue ?? "All Types",
                        systemImage: selectedTypeFilter?.systemImage ?? "square.grid.2x2"
                    )
                }

                Menu {
                    Button {
                        selectedOwnerFilter = nil
                    } label: {
                        Label("All People", systemImage: "person.3.fill")
                    }

                    if ownerFilterOptions.contains("Shared") {
                        Button {
                            selectedOwnerFilter = sharedOwnerToken
                        } label: {
                            Label("Shared", systemImage: "person.2.fill")
                        }
                    }

                    ForEach(ownerFilterOptions.filter { $0 != "Shared" }, id: \.self) { owner in
                        Button {
                            selectedOwnerFilter = owner
                        } label: {
                            Label(owner, systemImage: "person.fill")
                        }
                    }
                } label: {
                    filterChip(
                        title: selectedOwnerFilterTitle,
                        systemImage: selectedOwnerFilter == sharedOwnerToken ? "person.2.fill" : "person.fill"
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var selectedOwnerFilterTitle: String {
        if selectedOwnerFilter == sharedOwnerToken {
            return "Shared"
        }
        return selectedOwnerFilter ?? "All People"
    }

    private func filterChip(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(
                Capsule()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    private var documentList: some View {
        List {
            Section("Readiness") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        readinessCard(
                            title: "Needs Attention",
                            value: "\(attentionDocuments.count)",
                            caption: "Expired, stale, or incomplete",
                            systemImage: "exclamationmark.triangle.fill",
                            color: .orange
                        ) {
                            selectedBundleFilter = .attention
                        }

                        readinessCard(
                            title: "Expiring Soon",
                            value: "\(expiringSoonDocuments.count)",
                            caption: "Within 30 days",
                            systemImage: "calendar.badge.exclamationmark",
                            color: .red
                        ) {
                            selectedBundleFilter = .attention
                        }

                        readinessCard(
                            title: "Ready Now",
                            value: "\(allDocuments.filter { matches(document: $0, bundle: .readyNow) }.count)",
                            caption: "Favorites and travel IDs",
                            systemImage: "bolt.shield.fill",
                            color: documentTone
                        ) {
                            selectedBundleFilter = .readyNow
                        }

                        readinessCard(
                            title: "People Missing ID",
                            value: "\(membersMissingPrimaryIDCount)",
                            caption: "No passport, DL, or state ID",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            color: .secondary
                        ) {
                            selectedOwnerFilter = nil
                            selectedBundleFilter = .all
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if !recentlyAddedDocuments.isEmpty {
                Section("Recently Added") {
                    ForEach(recentlyAddedDocuments) { doc in
                        DocumentRow(document: doc)
                            .contentShape(Rectangle())
                            .onTapGesture { navigationPath.append(doc) }
                    }
                }
            }

            // Favorites section
            if !favorites.isEmpty {
                Section {
                    ForEach(favorites) { doc in
                        DocumentRow(document: doc)
                            .contentShape(Rectangle())
                            .onTapGesture { navigationPath.append(doc) }
                    }
                    .onDelete { indexSet in
                        deleteDocuments(from: favorites, at: indexSet)
                    }
                } header: {
                    Label("Favorites", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }

            // Category sections
            ForEach(documentsByCategory, id: \.0) { category, docs in
                Section {
                    ForEach(docs) { doc in
                        DocumentRow(document: doc)
                            .contentShape(Rectangle())
                            .onTapGesture { navigationPath.append(doc) }
                    }
                    .onDelete { indexSet in
                        deleteDocuments(from: docs, at: indexSet)
                    }
                } header: {
                    CategoryHeader(category: category)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 72))
                .foregroundStyle(.tint.opacity(0.7))

            VStack(spacing: 8) {
                Text("Your Vault is Empty")
                    .font(.title2.bold())
                Text("Add your important documents — driver's license,\npassport, insurance cards, and more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showingAddDocument = true }) {
                Label("Add First Document", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Delete

    private func deleteDocuments(from docs: [Document], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(docs[index])
        }
    }

    private var documentTone: Color {
        Color(red: 0.26, green: 0.39, blue: 0.45)
    }

    private func readinessCard(
        title: String,
        value: String,
        caption: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 170, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func matches(document: Document, bundle: BundleFilter) -> Bool {
        switch bundle {
        case .all:
            return true
        case .readyNow:
            return document.isFavorite || document.category == .identity || document.category == .travel
        case .travel:
            return document.category == .travel || [.passport, .globalEntry, .driversLicense, .hotelLoyalty, .airlineMembership, .rentalCarMembership].contains(document.documentType)
        case .medical:
            return document.category == .medical
        case .work:
            return document.category == .work
        case .attention:
            return document.needsAttention
        }
    }

    private func updateWidgetSnapshot() {
        let snapshot = VaultReadinessSnapshot(
            updatedAt: .now,
            totalDocuments: allDocuments.count,
            needsAttentionCount: attentionDocuments.count,
            expiringSoonCount: expiringSoonDocuments.count,
            readyNowCount: allDocuments.filter { matches(document: $0, bundle: .readyNow) }.count
        )
        VaultSnapshotStore.save(snapshot: snapshot)
    }
}

// MARK: - Supporting Views

struct CategoryHeader: View {
    let category: DocumentCategory

    var body: some View {
        Label(category.rawValue, systemImage: category.systemImage)
            .foregroundStyle(category.color)
            .font(.footnote.bold())
    }
}

struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 12) {
            // Doc type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(document.category.color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: document.documentType.systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(document.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(document.name)
                        .font(.body.weight(.medium))
                    if document.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(document.documentType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(document.ownerDisplayName, systemImage: document.ownerName == nil ? "person.2.fill" : "person.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if document.isMissingRequiredPages {
                    Label("Missing page", systemImage: "doc.badge.plus")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if document.needsVerificationReview {
                    Label("Review recommended", systemImage: "checkmark.seal.trianglebadge.exclamationmark")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Expiration badge
            if let days = document.daysUntilExpiry {
                ExpirationBadge(daysUntilExpiry: days, isExpired: document.isExpired)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct ExpirationBadge: View {
    let daysUntilExpiry: Int
    let isExpired: Bool

    private var badgeColor: Color {
        if isExpired { return .red }
        if daysUntilExpiry <= 30 { return .orange }
        return .green
    }

    private var label: String {
        if isExpired          { return "Expired" }
        if daysUntilExpiry <= 30  { return "\(daysUntilExpiry)d" }
        if daysUntilExpiry <= 365 { return "Valid" }
        return "Valid"
    }

    var body: some View {
        // Always show a badge when there is an expiration date — green for valid,
        // orange for ≤30 days, red for expired. Hiding it for 31-365 days left
        // users with no visual confirmation their document was still current.
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }
}

#Preview {
    VaultView(pendingDocumentType: .constant(nil), pendingCategory: .constant(nil))
        .modelContainer(for: [Document.self, DocumentPage.self], inMemory: true)
}
