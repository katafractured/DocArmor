import Foundation
import UserNotifications

enum ExpirationService {

    // MARK: - Request Permission

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Schedule Reminder

    static func scheduleReminder(for document: Document) {
        guard
            let expirationDate = document.expirationDate,
            let reminderDays = document.expirationReminderDays,
            !reminderDays.isEmpty
        else { return }

        for days in reminderDays {
            guard days > 0 else { continue }
            guard let triggerDate = Calendar.current.date(
                byAdding: .day,
                value: -days,
                to: expirationDate
            ) else { continue }

            guard triggerDate > Date.now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Document Expiring Soon"
            let formatted = expirationDate.formatted(date: .abbreviated, time: .omitted)
            content.body = "\(document.name) expires on \(formatted). Tap to view."
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: notificationID(for: document, days: days),
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Cancel Reminder

    static func cancelReminder(for document: Document) {
        let ids = [30, 60, 90].map { notificationID(for: document, days: $0) }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Update Reminder

    static func updateReminder(for document: Document) {
        cancelReminder(for: document)
        scheduleReminder(for: document)
    }

    // MARK: - Cancel All

    static func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    private static func notificationID(for document: Document, days: Int) -> String {
        "docarmor.expiry.\(document.id.uuidString).\(days)"
    }
}
