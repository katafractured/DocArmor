import Foundation

enum AppGroup {
    nonisolated static let identifier = "group.com.katafract.DocArmor"

    nonisolated static let importInboxFolderName = "ImportInbox"

    nonisolated static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
