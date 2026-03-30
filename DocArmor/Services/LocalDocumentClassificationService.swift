import Foundation

enum LocalDocumentClassificationService {
    struct Suggestions: Sendable {
        var documentType: DocumentType?
        var category: DocumentCategory?
        var ownerName: String?
        var confidenceScore: Double
    }

    static func suggest(
        from ocr: OCRService.Suggestions,
        householdProfiles: [HouseholdMemberProfile]
    ) -> Suggestions {
        let corpus = ocr.textCorpus.lowercased()
        let type = detectType(from: corpus, issuerName: ocr.issuerName)
        let ownerName = detectOwner(from: ocr.name, householdProfiles: householdProfiles)

        var confidence = min(ocr.confidenceScore, 0.75)
        if type != nil { confidence += 0.15 }
        if ownerName != nil { confidence += 0.1 }

        return Suggestions(
            documentType: type,
            category: type?.defaultCategory,
            ownerName: ownerName,
            confidenceScore: min(confidence, 0.95)
        )
    }

    private static func detectType(from corpus: String, issuerName: String?) -> DocumentType? {
        let issuer = issuerName?.lowercased() ?? ""

        if corpus.contains("passport") || corpus.contains("p<") {
            return .passport
        }
        if corpus.contains("global entry") || corpus.contains("tsa precheck") || corpus.contains("trusted traveler") {
            return .globalEntry
        }
        if corpus.contains("driver") && corpus.contains("license") {
            return .driversLicense
        }
        if corpus.contains("identification card") || corpus.contains("state id") {
            return .stateID
        }
        if corpus.contains("social security") {
            return .socialSecurity
        }
        if corpus.contains("birth certificate") {
            return .birthCertificate
        }
        if corpus.contains("permanent resident") || corpus.contains("green card") {
            return .greenCard
        }
        if corpus.contains("work permit") || corpus.contains("employment authorization") || corpus.contains("visa") {
            return .workPermit
        }
        if corpus.contains("medicare") || corpus.contains("medicaid") {
            return .medicareCard
        }
        if corpus.contains("vaccin") || corpus.contains("immunization") {
            return .vaccineRecord
        }
        if corpus.contains("blood type") || corpus.contains("donor") {
            return .bloodTypeCard
        }
        if corpus.contains("emergency contact") || corpus.contains("in case of emergency") {
            return .emergencyContacts
        }
        if corpus.contains("rxbin") || corpus.contains("rx grp") || corpus.contains("pcn") || corpus.contains("prescription") {
            return .prescriptionInfo
        }
        if corpus.contains("insurance") && (corpus.contains("auto") || corpus.contains("vehicle")) {
            return .insuranceAuto
        }
        if corpus.contains("insurance") && (corpus.contains("home") || corpus.contains("renters") || corpus.contains("renter")) {
            return .insuranceHome
        }
        if corpus.contains("insurance") && corpus.contains("life") {
            return .insuranceLife
        }
        if corpus.contains("insurance") || issuer.contains("health") || issuer.contains("blue cross") || issuer.contains("aetna") {
            return .insuranceHealth
        }
        if corpus.contains("hotel") || corpus.contains("loyalty") {
            return .hotelLoyalty
        }
        if corpus.contains("airline") || corpus.contains("boarding") || corpus.contains("frequent flyer") {
            return .airlineMembership
        }
        if corpus.contains("rental car") {
            return .rentalCarMembership
        }
        if corpus.contains("employee id") || corpus.contains("employee badge") {
            return .employeeID
        }
        if corpus.contains("professional license") || corpus.contains("board of") || corpus.contains("licensed") {
            return .professionalLicense
        }

        return nil
    }

    private static func detectOwner(
        from extractedName: String?,
        householdProfiles: [HouseholdMemberProfile]
    ) -> String? {
        guard let extractedName else { return nil }
        let normalizedExtracted = normalizedTokens(from: extractedName)
        guard normalizedExtracted.isEmpty == false else { return nil }

        let bestMatch = householdProfiles
            .filter { $0.role != .pet }
            .compactMap { profile -> (String, Int)? in
                let profileTokens = normalizedTokens(from: profile.name)
                let score = profileTokens.intersection(normalizedExtracted).count
                return score > 0 ? (profile.name, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0 < rhs.0
            }
            .first

        return bestMatch?.0
    }

    private static func normalizedTokens(from text: String) -> Set<String> {
        let letters = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return Set(letters)
    }
}
