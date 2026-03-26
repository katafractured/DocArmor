import SwiftUI
import SwiftData

struct TravelModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Document.name) private var allDocuments: [Document]

    @State private var navigationPath = NavigationPath()

    private let travelTypes: Set<DocumentType> = [
        .passport, .driversLicense, .stateID, .globalEntry,
        .hotelLoyalty, .airlineMembership, .rentalCarMembership
    ]

    private var travelDocuments: [Document] {
        allDocuments.filter { doc in
            doc.category == .travel || travelTypes.contains(doc.documentType)
        }
    }

    private var readyDocuments: [Document] {
        travelDocuments.filter { !$0.needsAttention }
    }

    private var attentionDocuments: [Document] {
        travelDocuments.filter { $0.needsAttention }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if travelDocuments.isEmpty {
                    ContentUnavailableView(
                        "No Travel Documents",
                        systemImage: "airplane",
                        description: Text("Add travel-category documents or types like passport, driver's license, and membership cards to see them here.")
                    )
                } else {
                    List {
                        if !readyDocuments.isEmpty {
                            Section {
                                ForEach(readyDocuments) { doc in
                                    DocumentRow(document: doc)
                                        .contentShape(Rectangle())
                                        .onTapGesture { navigationPath.append(doc) }
                                }
                            } header: {
                                Label("Ready to Travel", systemImage: "checkmark.shield.fill")
                                    .foregroundStyle(.green)
                                    .font(.footnote.bold())
                            }
                        }

                        if !attentionDocuments.isEmpty {
                            Section {
                                ForEach(attentionDocuments) { doc in
                                    DocumentRow(document: doc)
                                        .contentShape(Rectangle())
                                        .onTapGesture { navigationPath.append(doc) }
                                }
                            } header: {
                                Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.footnote.bold())
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Travel Mode")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: Document.self) { document in
                DocumentDetailView(document: document)
            }
        }
    }
}

#Preview {
    TravelModeView()
        .modelContainer(for: [Document.self, DocumentPage.self], inMemory: true)
}
