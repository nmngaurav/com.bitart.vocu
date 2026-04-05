import Foundation
import Observation
import SwiftUI

@Observable
final class SettingsViewModel {
    var user: UserBrief? = AuthSession.shared.currentUser
    var subscription: MySubscriptionResponse? = nil
    var progressSummary: ProgressSummaryResponse? = nil

    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String? = nil

    var editingName: String = ""
    private var editingDailyGoal: Int = 10   // hidden from UI; used when patching notification time
    var editingNotificationTime: Date = SettingsViewModel.defaultNotificationDate()

    private let api = APIClient.shared

    static func defaultNotificationDate() -> Date {
        var cal = Calendar.current
        return cal.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    }

    static func dateFromNotificationString(_ s: String?) -> Date {
        let raw = s ?? "09:00"
        let parts = raw.split(separator: ":")
        let h = Int(parts[0]) ?? 9
        let m = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        return Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? defaultNotificationDate()
    }

    static func notificationTimeString(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    func clearError() {
        errorMessage = nil
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        async let userResult: UserBrief? = try? await api.request(.getMe)
        async let subResult: MySubscriptionResponse? = try? await api.request(Endpoint.mySubscription)
        async let progressResult: ProgressSummaryResponse? = try? await api.request(.progressSummary)

        let (u, s, p) = await (userResult, subResult, progressResult)

        if let u = u {
            user = u
            editingName = u.displayName ?? ""
            if let dg = u.preferences?.dailyGoal {
                editingDailyGoal = dg
            }
            editingNotificationTime = Self.dateFromNotificationString(u.preferences?.notificationTime)
            AuthSession.shared.updateUser(u)
        }
        subscription = s
        progressSummary = p
    }

    func saveDisplayName() async {
        guard !editingName.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let updated: UserBrief = try await api.request(.updateMe(displayName: editingName, preferences: nil))
            user = updated
            AuthSession.shared.updateUser(updated)
        } catch {
            errorMessage = (error as? LexisError)?.errorDescription ?? error.localizedDescription
        }
    }

    func saveNotificationTime(_ date: Date) async {
        isSaving = true
        defer { isSaving = false }
        let timeStr = Self.notificationTimeString(from: date)
        do {
            let prefs: [String: Any] = [
                "daily_goal": editingDailyGoal,
                "notification_time": timeStr,
            ]
            let updated: UserBrief = try await api.request(
                .updateMe(displayName: nil, preferences: prefs)
            )
            user = updated
            AuthSession.shared.updateUser(updated)
            // Schedule the local OS notification after the BE confirms the save.
            VocuNotifications.scheduleDaily(at: timeStr)
        } catch {
            errorMessage = (error as? LexisError)?.errorDescription ?? error.localizedDescription
        }
    }

    var totalWordsSeen: Int {
        progressSummary?.totalWordsSeen ?? 0
    }

    var currentStreak: Int {
        user?.stats?.currentStreak ?? 0
    }

    var displayEmail: String {
        if AuthSession.shared.isAnonymous { return "Guest session" }
        return user?.email ?? ""
    }

    func signOut(coordinator: AppCoordinator) async {
        try? await api.requestVoid(.logout)
        try? await api.requestVoid(.deregisterPushToken)
        coordinator.signOut()
    }

    var subscriptionLabel: String {
        guard let sub = subscription else {
            return AuthSession.shared.isProUser ? "Pro" : "Free"
        }
        return sub.tier.capitalized
    }

    var subscriptionColor: Color {
        AuthSession.shared.isProUser ? .amberGlow : .textSecondary
    }

    var appVersionLabel: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}
