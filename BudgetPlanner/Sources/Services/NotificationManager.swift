import Foundation
import UserNotifications

enum NotificationManager {
    static func configureBudgetReminder(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        let identifier = "budget_monthly_review_reminder"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }

        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let content = UNMutableNotificationContent()
            content.title = "Budget check-in"
            content.body = "Review your spending and savings opportunities today."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
