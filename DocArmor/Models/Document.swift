import Foundation
import SwiftData

@Model
final class Document {
    var id: UUID
    var name: String
    /// Optional person assignment. `nil` means the document belongs to the shared household vault.
    var ownerName: String?
    /// Stored as String for migration safety across enum changes
    var documentTypeRaw: String
    /// Stored as String for migration safety
    var categoryRaw: String
    var notes: String
    var issuerName: String
    var identifierSuffix: String
    var lastVerifiedAt: Date?
    var renewalNotes: String
    var expirationDate: Date?
    /// Days before expiry to send reminders — multiple values allowed (e.g. [30, 60, 90]).
    /// nil or empty means no reminders scheduled.
    var expirationReminderDays: [Int]?
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool

    @Relationship(deleteRule: .cascade)
    var pages: [DocumentPage]

    // MARK: - Computed

    var documentType: DocumentType {
        DocumentType(rawValue: documentTypeRaw) ?? .custom
    }

    var ownerDisplayName: String {
        guard let ownerName, !ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Shared"
        }
        return ownerName
    }

    var category: DocumentCategory {
        DocumentCategory(rawValue: categoryRaw) ?? .identity
    }

    var isExpired: Bool {
        guard let expiry = expirationDate else { return false }
        return expiry < Date.now
    }

    var expiresSoon: Bool {
        guard let daysUntilExpiry else { return false }
        return daysUntilExpiry >= 0 && daysUntilExpiry <= 30
    }

    var daysUntilExpiry: Int? {
        guard let expiry = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: expiry).day
    }

    var isMissingRequiredPages: Bool {
        documentType.requiresFrontBack && pages.count < 2
    }

    var needsVerificationReview: Bool {
        guard let lastVerifiedAt else { return true }
        guard let days = Calendar.current.dateComponents([.day], from: lastVerifiedAt, to: .now).day else {
            return false
        }
        return days >= 180
    }

    var needsAttention: Bool {
        isExpired || expiresSoon || isMissingRequiredPages || needsVerificationReview
    }

    var sortedPages: [DocumentPage] {
        pages.sorted { $0.pageIndex < $1.pageIndex }
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        ownerName: String? = nil,
        documentType: DocumentType,
        category: DocumentCategory? = nil,
        notes: String = "",
        issuerName: String = "",
        identifierSuffix: String = "",
        lastVerifiedAt: Date? = nil,
        renewalNotes: String = "",
        expirationDate: Date? = nil,
        expirationReminderDays: [Int]? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.documentTypeRaw = documentType.rawValue
        self.categoryRaw = (category ?? documentType.defaultCategory).rawValue
        self.notes = notes
        self.issuerName = issuerName
        self.identifierSuffix = identifierSuffix
        self.lastVerifiedAt = lastVerifiedAt
        self.renewalNotes = renewalNotes
        self.expirationDate = expirationDate
        self.expirationReminderDays = expirationReminderDays
        self.createdAt = Date.now
        self.updatedAt = Date.now
        self.isFavorite = isFavorite
        self.pages = []
    }
}
