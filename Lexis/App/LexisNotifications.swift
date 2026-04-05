import Foundation
import UserNotifications

extension Notification.Name {
    /// Switch main tab bar to the review history tab (index 1).
    static let vocuOpenWordListTab = Notification.Name("vocuOpenWordListTab")
    /// Open the today's-words recap from HomeView (fired after session completes or from empty queue).
    static let vocuShowRecap = Notification.Name("vocuShowRecap")
    // vocuAudioDidUseSpeechFallback is defined in AudioPlaybackService.swift
}

// MARK: - Local Notification Scheduler

enum VocuNotifications {
    private static let dailyReminderID = "com.vocu.dailyReminder"

    /// Schedules (or re-schedules) a daily reminder at the given "HH:mm" time string.
    static func scheduleDaily(at timeString: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let parts = timeString.split(separator: ":")
            let hour   = Int(parts.first ?? "9") ?? 9
            let minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0

            let content = UNMutableNotificationContent()
            content.title = "Time to review"
            content.body  = "Keep your streak alive — a quick session takes just 2 minutes."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour   = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: dailyReminderID,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
            UNUserNotificationCenter.current().add(request)
        }
    }
}
