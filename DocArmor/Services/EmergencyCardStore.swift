import Foundation

enum EmergencyCardStore {
    private static let key = "emergencyCardData"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static func load() -> EmergencyCardData {
        guard
            let data = defaults.data(forKey: key),
            let card = try? JSONDecoder().decode(EmergencyCardData.self, from: data)
        else {
            return EmergencyCardData()
        }
        return card
    }

    static func save(_ card: EmergencyCardData) {
        guard let data = try? JSONEncoder().encode(card) else { return }
        defaults.set(data, forKey: key)
    }
}
