import Foundation

enum LocalIntelligenceRecommendationService {
    enum SmartPackKey: String, CaseIterable, Sendable {
        case travel
        case vehicle
        case family
        case school
        case medical
        case work
        case property
        case disaster
        case dependent
        case pet
    }

    struct PackRecommendation: Identifiable, Sendable {
        let key: SmartPackKey
        let title: String
        let systemImage: String
        let reason: String

        var id: String { key.rawValue }
    }

    struct ReadinessRecommendation: Identifiable, Sendable {
        let id: String
        let title: String
        let systemImage: String
        let detail: String
        let priority: Int
    }

    static func packRecommendations(
        documents: [Document],
        householdProfiles: [HouseholdMemberProfile],
        enabledPacks: Set<SmartPackKey>
    ) -> [PackRecommendation] {
        let roles = Set(householdProfiles.map(\.role))
        let types = Set(documents.map(\.documentType))
        let humanCount = householdProfiles.filter { $0.role != .pet }.count

        let recommendations: [PackRecommendation?] = [
            enabledPacks.contains(.travel) ? nil : pack(.travel, "Travel & Identity Pack", "airplane.departure", !types.isDisjoint(with: Set([.passport, .globalEntry, .airlineMembership, .hotelLoyalty, .rentalCarMembership])) ? "Travel and identity documents are already present, so this pack will make them faster to reach." : nil),
            enabledPacks.contains(.vehicle) ? nil : pack(.vehicle, "Vehicle & Roadside Pack", "car.fill", roles.contains(where: { $0 == .adult || $0 == .senior }) ? "Your household has drivers or adults who benefit from roadside-ready access." : nil),
            enabledPacks.contains(.family) ? nil : pack(.family, "Family Emergency Pack", "person.3.sequence.fill", humanCount > 1 ? "Multiple people are in the household, so shared fast access adds value." : nil),
            enabledPacks.contains(.school) ? nil : pack(.school, "School Pack", "graduationcap.fill", roles.contains(where: { $0 == .child || $0 == .dependent }) ? "A child or dependent profile makes school and enrollment access relevant." : nil),
            enabledPacks.contains(.medical) ? nil : pack(.medical, "Medical Visit Pack", "cross.case.fill", !types.isDisjoint(with: Set([.insuranceHealth, .medicareCard, .prescriptionInfo, .bloodTypeCard, .emergencyContacts])) ? "Medical records already exist, so grouping them improves appointment readiness." : nil),
            enabledPacks.contains(.work) ? nil : pack(.work, "Work Credential Pack", "briefcase.fill", !types.isDisjoint(with: Set([.employeeID, .professionalLicense, .workPermit])) ? "Work-related credentials are already stored and can be grouped for faster retrieval." : nil),
            enabledPacks.contains(.property) ? nil : pack(.property, "Property Claim Pack", "house.fill", !types.isDisjoint(with: Set([.insuranceHome, .insuranceLife])) ? "Insurance and property-style records are present, so claim-ready grouping is useful." : nil),
            enabledPacks.contains(.disaster) ? nil : pack(.disaster, "Grab-and-Go Pack", "bolt.shield.fill", (!types.isDisjoint(with: Set([.passport, .insuranceHealth, .emergencyContacts])) || humanCount > 1) ? "Your vault already has the core records that benefit from one emergency packet." : nil),
            enabledPacks.contains(.dependent) ? nil : pack(.dependent, "Dependent Care Pack", "person.2.crop.square.stack.fill", roles.contains(where: { $0 == .child || $0 == .senior || $0 == .dependent }) ? "Dependent-care roles are present and benefit from a dedicated packet." : nil),
            enabledPacks.contains(.pet) ? nil : pack(.pet, "Pet & Boarding Pack", "pawprint.fill", roles.contains(.pet) ? "A pet profile exists, so boarding and vet-ready access becomes relevant." : nil)
        ]

        return recommendations.compactMap { $0 }
    }

    static func readinessRecommendations(
        documents: [Document],
        householdProfiles: [HouseholdMemberProfile]
    ) -> [ReadinessRecommendation] {
        var items: [ReadinessRecommendation] = []

        let expired = documents.filter(\.isExpired).count
        if expired > 0 {
            items.append(ReadinessRecommendation(
                id: "expired",
                title: "Renew expired documents",
                systemImage: "arrow.clockwise.circle.fill",
                detail: "\(expired) document\(expired == 1 ? "" : "s") already expired and should be renewed or replaced.",
                priority: 0
            ))
        }

        let incomplete = documents.filter(\.isMissingRequiredPages).count
        if incomplete > 0 {
            items.append(ReadinessRecommendation(
                id: "incomplete",
                title: "Finish front and back scans",
                systemImage: "doc.badge.plus",
                detail: "\(incomplete) card-style document\(incomplete == 1 ? "" : "s") still look incomplete.",
                priority: 1
            ))
        }

        let lowConfidence = documents.filter { ($0.ocrConfidenceScore ?? 1) < 0.5 }.count
        if lowConfidence > 0 {
            items.append(ReadinessRecommendation(
                id: "ocr",
                title: "Review low-confidence OCR",
                systemImage: "text.viewfinder",
                detail: "\(lowConfidence) document\(lowConfidence == 1 ? "" : "s") may need manual review because OCR confidence was low.",
                priority: 2
            ))
        }

        let humans = householdProfiles.filter { $0.role != .pet }
        let primaryIdentityTypes: Set<DocumentType> = [.passport, .driversLicense, .stateID]
        let missingPrimaryID = humans.filter { profile in
            let ownedTypes = Set(documents.filter { $0.ownerDisplayName == profile.name }.map(\.documentType))
            return primaryIdentityTypes.isDisjoint(with: ownedTypes)
        }.count
        if missingPrimaryID > 0 {
            items.append(ReadinessRecommendation(
                id: "identity",
                title: "Fill identity gaps",
                systemImage: "person.text.rectangle.fill",
                detail: "\(missingPrimaryID) household member\(missingPrimaryID == 1 ? "" : "s") still lack a primary ID in the vault.",
                priority: 3
            ))
        }

        if documents.isEmpty {
            items.append(ReadinessRecommendation(
                id: "empty",
                title: "Start with an everyday document",
                systemImage: "plus.rectangle.on.folder.fill",
                detail: "Add a passport, driver's license, or insurance card so the vault becomes immediately useful.",
                priority: 4
            ))
        }

        return items.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.title < rhs.title
        }
    }

    private static func pack(
        _ key: SmartPackKey,
        _ title: String,
        _ systemImage: String,
        _ reason: String?
    ) -> PackRecommendation? {
        guard let reason else { return nil }
        return PackRecommendation(key: key, title: title, systemImage: systemImage, reason: reason)
    }
}
