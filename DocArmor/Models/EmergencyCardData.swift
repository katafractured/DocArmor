import Foundation

struct EmergencyCardData: Codable, Equatable {
    var isEnabled: Bool = false
    var bloodType: String = ""
    var allergies: String = ""
    var medicalNotes: String = ""
    var contact1Name: String = ""
    var contact1Phone: String = ""
    var contact2Name: String = ""
    var contact2Phone: String = ""
}
