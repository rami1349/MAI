// ============================================================================
// LocalNotificationService.swift
//
//
// PURPOSE:
//   Manages all notification delivery in  — both local push notifications
//   scheduled by the device and FCM token management for server-sent push notifications.
//
// TWO NOTIFICATION PATHWAYS:
//
//   1. LOCAL (device-scheduled):
//      Scheduled by this service using `UNUserNotificationCenter`.
//      Fires even when the app is in the background or terminated.
//      Used for: task due reminders, event reminders, birthday countdowns.
//
//   2. REMOTE (server-sent via FCM):
//      Triggered by Firestore Cloud Function `onNotificationCreated`.
//      When a `notifications/{id}` document is created, the Cloud Function
//      reads the recipient's `fcmToken` and sends a push via Firebase Cloud Messaging.
//      This service stores and manages the FCM token on the user document.
//
// NOTIFICATION IDENTIFIER SCHEME:
//   Each notification has a stable identifier based on the entity it references:
//   - Task due:     "taskdue_{taskId}"
//   - Due tomorrow: "duetomorrow_{taskId}"
//   - Event soon:   "eventsoon_{eventId}"
//   - Event tomorrow: "eventtomorrow_{eventId}"
//   - Birthday:     "birthday_{memberId}"
//   - Task status:  "status_{taskId}_{statusRawValue}"
//
//   Stable identifiers allow pending notifications to be cancelled by ID when
//   the task or event is completed, deleted, or rescheduled.
//
// FOREGROUND PRESENTATION:
//   This service implements `UNUserNotificationCenterDelegate.willPresent` to
//   display notifications even when the app is in the foreground (default iOS
//   behavior suppresses them). Foreground banners require this explicit opt-in.
//
// DEEP LINK ROUTING:
//   Tap handling in `didReceive` posts `Notification.Name` events to
//   `NotificationCenter.default`. ContentView or MainTabView observes these
//   and navigates to the relevant task or habit screen.
//
// ============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

/// Singleton service managing FCM tokens, local notification scheduling,
/// and tap-to-deep-link routing for .
///
/// Conforms to:
/// - `UNUserNotificationCenterDelegate`: handles foreground display and tap routing.
/// - `MessagingDelegate`: receives FCM token updates from Firebase Messaging.
@Observable
class LocalNotificationService: NSObject, UNUserNotificationCenterDelegate {

    /// Shared singleton. Assigned as both the notification center delegate and
    /// Firebase Messaging delegate in `AssistantApp.init()`.
    static let shared = LocalNotificationService()

    /// The current device FCM token. Set by `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)`.
    /// Observed by `AuthViewModel` via `NotificationCenter` to save token to Firestore on login.
    var fcmToken: String?

    private var db: Firestore { Firestore.firestore() }

    private override init() {
        super.init()
    }

    // MARK: - Permission

    /// Requests user authorization for alert, badge, and sound notifications.
    ///
    /// On grant, registers with APNs via `UIApplication.registerForRemoteNotifications()`.
    /// APNs registration in turn triggers the FCM SDK to issue a new token,
    /// which arrives in `messaging(_:didReceiveRegistrationToken:)`.
    ///
    /// - Returns: `true` if the user granted notification permission, `false` otherwise.
    ///   Authorization failure is silent (no error propagated) — the app degrades gracefully
    ///   without notifications.
    func requestPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: options)

            if granted {
                // registerForRemoteNotifications must be called on the main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    // MARK: - FCM Token Management

    /// Persists the current FCM token to the user's Firestore document.
    ///
    /// Called by `AuthViewModel` after successful sign-in and when a new FCM token
    /// arrives via the `fcmTokenReceived` NotificationCenter observation.
    ///
    /// Uses `setData(merge: true)` to update only the FCM-related fields without
    /// overwriting the entire user document.
    ///
    /// - Parameter userId: Firebase UID of the currently signed-in user.
    func saveFCMToken(userId: String) async {
        guard let token = fcmToken else { return } // No token yet — will be called again when available

        do {
            try await db.collection("users").document(userId).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
                "platform": "ios" // Used by Cloud Functions to route platform-specific payloads
            ], merge: true) // merge: true preserves all other user fields
        } catch {
            // Token save failure is non-critical — next app launch will retry.
            // FCM will still deliver if an older valid token exists on the document.
        }
    }

    /// Removes the FCM token from the user's Firestore document on sign-out or account deletion.
    ///
    /// After removal, FCM push notifications will no longer be delivered to this device.
    /// Called by `AuthViewModel.signOut()` and `AccountDeletionService.deleteAccount()`.
    ///
    /// - Parameter userId: Firebase UID of the user signing out.
    func removeFCMToken(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": FieldValue.delete() // Removes the field entirely (not sets to null)
            ])
        } catch {
            // Non-critical. Worst case: a few stale push notifications after sign-out.
        }
    }

    // MARK: - Badge Count

    /// Sets the app badge count to reflect unread in-app notification count.
    ///
    /// Called by `NotificationViewModel` when the unread count changes.
    /// Pass `0` to clear the badge icon.
    ///
    /// - Parameter count: The number to display on the app icon badge.
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    // MARK: - Birthday Countdown Notifications

    /// Schedules "Birthday Tomorrow!" notifications for all family members.
    ///
    /// For each member, calculates the next occurrence of their birthday and schedules
    /// a notification at 9 AM the day before (if within the next 30 days).
    ///
    /// Notification identifier: `"birthday_{memberId}"` — replaces any existing pending
    /// birthday notification for that member when called again (UNUserNotificationCenter
    /// deduplicates by identifier).
    ///
    /// - Parameter familyMembers: All members in the family (all birthdays are checked).
    func scheduleCountdownNotifications(familyMembers: [FamilyUser]) {
        let calendar = Calendar.current
        let today = Date()

        for member in familyMembers {
            let birthday = member.dateOfBirth

            // Project birthday onto current year
            var nextBirthdayComponents = calendar.dateComponents([.month, .day], from: birthday)
            nextBirthdayComponents.year = calendar.component(.year, from: today)

            if var nextBirthday = calendar.date(from: nextBirthdayComponents) {
                // If birthday already passed this year, push to next year
                if nextBirthday < today {
                    nextBirthdayComponents.year = calendar.component(.year, from: today) + 1
                    nextBirthday = calendar.date(from: nextBirthdayComponents) ?? nextBirthday
                }

                let daysUntil = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: today),
                    to: calendar.startOfDay(for: nextBirthday)
                ).day ?? 0

                // Only schedule if birthday is between 2 and 30 days away
                // (1 day away means tomorrow — notification fires "day before" = today at 9 AM)
                if daysUntil > 1 && daysUntil <= 30 {
                    let notificationDate = calendar.date(byAdding: .day, value: -1, to: nextBirthday) ?? nextBirthday
                    scheduleBirthdayReminder(
                        memberName: member.displayName,
                        memberId: member.id ?? "",
                        date: notificationDate
                    )
                }
            }
        }
    }

    /// Creates and registers a birthday reminder notification for a specific member.
    ///
    /// Fires at 9:00 AM on the day before the birthday.
    private func scheduleBirthdayReminder(memberName: String, memberId: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Birthday Tomorrow!"
        content.body  = "\(memberName)'s birthday is tomorrow!"
        content.sound = .default
        content.userInfo = ["type": "birthday", "memberId": memberId]

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour   = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "birthday_\(memberId)", // Stable ID — deduplicates on re-schedule
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Task Due Notifications

    /// Schedules two local reminder notifications per incomplete task:
    ///
    /// 1. "Due tomorrow" at 9:00 AM the day before the due date.
    /// 2. "Due in 1 hour" exactly 1 hour before the due/scheduled time.
    ///
    /// Before scheduling, removes any existing pending notifications for these tasks
    /// (by their stable identifiers) to prevent duplicate notifications when tasks
    /// are rescheduled.
    ///
    /// Only schedules for:
    /// - Tasks assigned to `userId` (v1 `assignedTo` only — v2 `assignees` not checked ⚠️).
    /// - Tasks that are not completed.
    /// - Future due dates only (past dates are skipped).
    ///
    /// - Parameters:
    ///   - tasks: All tasks from the TaskViewModel list.
    ///   - userId: The current user's Firebase UID (for assignee filtering).
    func scheduleTaskDueDateNotifications(tasks: [FamilyTask], userId: String) {
        // Remove existing pending task notifications before re-scheduling
        // (prevents duplicates when task due dates change)
        let dueIdentifiers      = tasks.compactMap { $0.id.map { "taskdue_\($0)" } }
        let tomorrowIdentifiers = tasks.compactMap { $0.id.map { "duetomorrow_\($0)" } }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: dueIdentifiers + tomorrowIdentifiers)

        let calendar = Calendar.current
        let now = Date()

        for task in tasks {
            // Skip: task not assigned to this user (v1 only — doesn't check v2 assignees ⚠️)
            guard task.assignedTo == nil || task.assignedTo == userId else { continue }
            // Skip: already completed tasks
            guard task.status != .completed else { continue }
            guard let taskId = task.id else { continue }

            // Prefer scheduledTime as the precise reminder anchor; fall back to dueDate
            let dueDate = task.scheduledTime ?? task.dueDate
            guard dueDate > now else { continue } // Skip past-due tasks

            // ── Notification 1: "Due tomorrow" at 9 AM the day before ──
            let startOfDueDay = calendar.startOfDay(for: dueDate)
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: startOfDueDay) {
                var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: dayBefore)
                tomorrowComponents.hour   = 9
                tomorrowComponents.minute = 0

                if let triggerDate = calendar.date(from: tomorrowComponents), triggerDate > now {
                    let content = UNMutableNotificationContent()
                    content.title    = "task_Due_Tomorrow"
                    content.body     = AppStrings.taskDueTomorrowBody(task.title)
                    content.sound    = .default
                    content.userInfo = ["type": "taskDueTomorrow", "taskId": taskId]

                    let trigger = UNCalendarNotificationTrigger(
                        dateMatching: tomorrowComponents, repeats: false
                    )
                    UNUserNotificationCenter.current().add(
                        UNNotificationRequest(
                            identifier: "due_tomorrow_\(taskId)",
                            content: content,
                            trigger: trigger
                        )
                    )
                }
            }

            // ── Notification 2: "Due in 1 hour" ──
            if let reminderDate = calendar.date(byAdding: .hour, value: -1, to: dueDate),
               reminderDate > now {
                let content = UNMutableNotificationContent()
                content.title    = "task_Due_Soon"
                content.body     = AppStrings.taskDueSoonBody(task.title)
                content.sound    = .default
                content.userInfo = ["type": "taskDue", "taskId": taskId]

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: reminderDate
                )
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(
                        identifier: "taskdue_\(taskId)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    )
                )
            }
        }
    }

    /// Cancels all pending due date notifications for a specific task.
    ///
    /// Called when a task is completed, deleted, or has its due date changed.
    ///
    /// - Parameter taskId: Firestore document ID of the task.
    func cancelTaskDueNotifications(taskId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["taskdue_\(taskId)", "duetomorrow_\(taskId)"]
        )
    }

    // MARK: - Calendar Event Reminder Notifications

    /// Schedules two local reminder notifications per upcoming event:
    ///
    /// 1. "Event tomorrow" at 9:00 AM the day before the event.
    /// 2. "Starting in 1 hour" exactly 1 hour before event start.
    ///
    /// Only schedules for events where `userId` is either the creator or a participant.
    ///
    /// - Parameters:
    ///   - events: Calendar events from `CalendarViewModel`.
    ///   - userId: Current user's Firebase UID.
    func scheduleEventReminders(events: [CalendarEvent], userId: String) {
        // Remove existing event reminders before re-scheduling
        let reminderIds = events.compactMap { event -> [String]? in
            guard let id = event.id else { return nil }
            return ["event_tomorrow_\(id)", "event_soon_\(id)"]
        }.flatMap { $0 }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)

        let calendar = Calendar.current
        let now = Date()

        for event in events {
            guard event.createdBy == userId || event.participants.contains(userId) else { continue }
            guard let eventId = event.id else { continue }
            guard event.startDate > now else { continue }

            // ── Notification 1: "Event tomorrow" at 9 AM the day before ──
            let startOfEventDay = calendar.startOfDay(for: event.startDate)
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: startOfEventDay) {
                var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: dayBefore)
                tomorrowComponents.hour   = 9
                tomorrowComponents.minute = 0

                if let triggerDate = calendar.date(from: tomorrowComponents), triggerDate > now {
                    let content = UNMutableNotificationContent()
                    content.title    = "event_Tomorrow"
                    content.body     = AppStrings.eventTomorrowBody(event.title)
                    content.sound    = .default
                    content.userInfo = ["type": "event_Tomorrow", "eventId": eventId]

                    UNUserNotificationCenter.current().add(
                        UNNotificationRequest(
                            identifier: "event_tomorrow_\(eventId)",
                            content: content,
                            trigger: UNCalendarNotificationTrigger(
                                dateMatching: tomorrowComponents, repeats: false
                            )
                        )
                    )
                }
            }

            // ── Notification 2: "Starting in 1 hour" ──
            if let reminderDate = calendar.date(byAdding: .hour, value: -1, to: event.startDate),
               reminderDate > now {
                let content = UNMutableNotificationContent()
                content.title    = "event_Starting_Soon"
                content.body     = AppStrings.eventStartingSoonBody(event.title)
                content.sound    = .default
                content.userInfo = ["type": "eventSoon", "eventId": eventId]

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: reminderDate
                )
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(
                        identifier: "event_soon_\(eventId)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    )
                )
            }
        }
    }

    /// Cancels all pending reminder notifications for a specific calendar event.
    ///
    /// Called when an event is deleted or has its date changed.
    ///
    /// - Parameter eventId: Firestore document ID of the event.
    func cancelEventReminders(eventId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["event_tomorrow_\(eventId)", "event_soon_\(eventId)"]
        )
    }

    // MARK: - Task Status Change Notification (Immediate Local Delivery)

    /// Immediately delivers a local notification when a task's status changes.
    ///
    /// Fires 1 second after the call (minimum UNTimeIntervalNotificationTrigger interval).
    /// Used to inform the current user of status changes they can see in the UI
    /// (e.g., after completing a task or submitting proof).
    ///
    /// Does NOT fire for `.todo` status (returned early — no notification needed).
    ///
    /// - Parameters:
    ///   - task: The task whose status changed.
    ///   - newStatus: The new status to describe in the notification.
    ///   - performerName: Display name of the user who caused the status change.
    func sendTaskStatusNotification(
        task: FamilyTask,
        newStatus: FamilyTask.TaskStatus,
        performerName: String
    ) {
        let content = UNMutableNotificationContent()

        switch newStatus {
        case .inProgress:
            content.title = "task_Started"
            content.body  = AppStrings.taskStartedBody(performerName, task.title)
        case .pendingVerification:
            content.title = "proof_Submitted"
            content.body  = AppStrings.proofSubmittedBody(performerName, task.title)
        case .completed:
            content.title = "task_Completed"
            content.body  = AppStrings.taskCompletedBody(performerName, task.title)
        case .todo:
            return // No notification for status regression to todo
        }

        content.sound    = .default
        content.userInfo = [
            "type": "task_Status",
            "taskId": task.id ?? "",
            "status": newStatus.rawValue
        ]

        // 1-second delay is the minimum interval for UNTimeIntervalNotificationTrigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                // Include taskId + status in identifier to avoid collisions
                // when the same task changes status multiple times quickly
                identifier: "status_\(task.id ?? UUID().uuidString)_\(newStatus.rawValue)",
                content: content,
                trigger: trigger
            )
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Displays notifications in-app as banners when the app is in the foreground.
    ///
    /// Default iOS behavior suppresses notifications when the app is active.
    /// This override enables foreground banners + sound + badge for all notifications.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    /// Handles tap on a notification banner — routes to the relevant in-app screen.
    ///
    /// Deep link routing via `NotificationCenter.default`:
    /// - `taskId` present → posts `.openTaskDetail` → ContentView navigates to task detail.
    /// - `habitId` present → posts `.openHabits` → ContentView navigates to habits tab.
    ///
    /// If neither key is present, the tap opens the app without deep linking.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let taskId = userInfo["taskId"] as? String, !taskId.isEmpty {
            // Deep link to task detail view
            NotificationCenter.default.post(
                name: .openTaskDetail,
                object: nil,
                userInfo: ["taskId": taskId]
            )
        } else if let habitId = userInfo["habitId"] as? String, !habitId.isEmpty {
            // Deep link to habits tab
            NotificationCenter.default.post(
                name: .openHabits,
                object: nil,
                userInfo: ["habitId": habitId]
            )
        }

        completionHandler()
    }
}

// MARK: - MessagingDelegate (FCM Token Updates)

extension LocalNotificationService: MessagingDelegate {

    /// Called by the FCM SDK whenever a new registration token is issued.
    ///
    /// Tokens are refreshed periodically by FCM and immediately after an APNs
    /// device token change. This stores the token locally and broadcasts it via
    /// `NotificationCenter` so `AuthViewModel` can save it to Firestore.
    ///
    /// Direct Firestore write is NOT done here because the user may not be
    /// authenticated at this point (token can arrive before sign-in completes).
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        // Store token locally for use by saveFCMToken(userId:)
        Task { @MainActor in
            self.fcmToken = token
        }

        // Notify AuthViewModel to persist the token if a user is signed in
        NotificationCenter.default.post(
            name: .fcmTokenReceived,
            object: nil,
            userInfo: ["token": token]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a notification tap should navigate to a task detail view.
    /// `userInfo["taskId"]` contains the Firestore task document ID.
    static let openTaskDetail = Notification.Name("openTaskDetail")

    /// Posted when a notification tap should navigate to the habits tab.
    /// `userInfo["habitId"]` contains the Firestore habit document ID.
    static let openHabits = Notification.Name("openHabits")

    /// Posted by the FCM delegate when a new registration token is received.
    /// `userInfo["token"]` contains the raw FCM token string.
    static let fcmTokenReceived = Notification.Name("fcmTokenReceived")

    /// Posted after a task is completed or proof submitted to dismiss the entire sheet stack.
    /// Observed by `TaskDetailView` and `ProofCaptureView` to pop back to the task list.
    static let dismissTaskSheets = Notification.Name("dismissTaskSheets")
}

// MARK: - Improvements & Code Quality Notes
//
// SUGGESTION 1 — scheduleTaskDueDateNotifications only checks v1 assignedTo:
//   Line: `guard task.assignedTo == nil || task.assignedTo == userId else { continue }`
//   This skips multi-assignee tasks where this user is in `assignees` but not `assignedTo`.
//   Fix: Change to `guard task.isAssigned(to: userId) || task.assignedTo == nil else { continue }`
//
// SUGGESTION 2 — Notification budget not enforced:
//   iOS allows up to 64 pending local notifications per app. Large families with many tasks
//   can easily exceed this. Add a priority-based scheduling limit that keeps only the
//   N most urgent notifications (e.g., top 60 by due date).
//
// SUGGESTION 3 — Birthday notifications not cleared on member removal:
//   If a member leaves the family, their birthday notification remains pending.
//   Add `cancelBirthdayNotification(memberId:)` and call it from FamilyViewModel.removeMember().
//
// SUGGESTION 4 — sendTaskStatusNotification identifier not stable:
//   The status notification identifier includes `UUID().uuidString` when `task.id` is nil.
//   This means it can't be cancelled programmatically. Always ensure task.id is non-nil
//   before calling this function, or handle the nil case with a stable fallback.
//
// SUGGESTION 5 — FCM token multi-device handling:
//   `saveFCMToken` stores a single `fcmToken` field. A user with multiple devices
//   (iPad + iPhone) will have the token overwritten by whichever device last signed in.
//   Upgrade to `fcmTokens: [String]` (array) with `FieldValue.arrayUnion` to support
//   multi-device push delivery.
