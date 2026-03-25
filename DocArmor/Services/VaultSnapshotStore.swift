import Foundation

nonisolated struct VaultReadinessSnapshot: Codable, Sendable {
    let updatedAt: Date
    let totalDocuments: Int
    let needsAttentionCount: Int
    let expiringSoonCount: Int
    let readyNowCount: Int
}

enum VaultSnapshotStore {
    nonisolated private static let snapshotKey = "vaultReadinessSnapshot"

    nonisolated static func save(snapshot: VaultReadinessSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults().set(data, forKey: snapshotKey)
    }

    nonisolated static func loadSnapshot() -> VaultReadinessSnapshot? {
        guard
            let data = sharedDefaults().data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(VaultReadinessSnapshot.self, from: data)
        else {
            return nil
        }
        return snapshot
    }

    nonisolated private static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }
}
