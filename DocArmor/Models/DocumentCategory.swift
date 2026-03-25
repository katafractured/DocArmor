import SwiftUI

enum DocumentCategory: String, CaseIterable, Codable, Hashable {
    case identity  = "Identity"
    case medical   = "Medical"
    case financial = "Financial"
    case travel    = "Travel"
    case work      = "Work"
    case custom    = "Custom"

    var systemImage: String {
        switch self {
        case .identity:  return "person.text.rectangle.fill"
        case .medical:   return "cross.case.fill"
        case .financial: return "creditcard.fill"
        case .travel:    return "airplane"
        case .work:      return "briefcase.fill"
        case .custom:    return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .identity:  return Color(red: 0.28, green: 0.39, blue: 0.50)
        case .medical:   return Color(red: 0.58, green: 0.30, blue: 0.30)
        case .financial: return Color(red: 0.38, green: 0.48, blue: 0.28)
        case .travel:    return Color(red: 0.62, green: 0.46, blue: 0.24)
        case .work:      return Color(red: 0.42, green: 0.34, blue: 0.48)
        case .custom:    return Color(red: 0.42, green: 0.44, blue: 0.48)
        }
    }
}
