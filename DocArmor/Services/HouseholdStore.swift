import Foundation

enum HouseholdStore {
    nonisolated private static let membersKey = "householdMembers"

    nonisolated static func loadMembers() -> [String] {
        let members = UserDefaults.standard.stringArray(forKey: membersKey) ?? ["Me"]
        return sanitize(members)
    }

    nonisolated static func saveMembers(_ members: [String]) {
        UserDefaults.standard.set(sanitize(members), forKey: membersKey)
    }

    @discardableResult
    nonisolated static func addMember(named name: String) -> [String] {
        var members = loadMembers()
        guard let normalized = normalize(name), !members.contains(normalized) else { return members }
        members.append(normalized)
        saveMembers(members)
        return members
    }

    @discardableResult
    nonisolated static func removeMember(named name: String) -> [String] {
        let members = loadMembers().filter { $0 != name }
        saveMembers(members)
        return members
    }

    nonisolated static func normalize(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func sanitize(_ members: [String]) -> [String] {
        Array(Set(members.compactMap(normalize(_:))))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
