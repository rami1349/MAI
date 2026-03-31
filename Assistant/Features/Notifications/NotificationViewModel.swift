// ============================================================================
// NotificationViewModel.swift
//
//
// PURPOSE:
//   Manages in-app notification state (read/unread, badge count) and handles
//   all notification delivery to Firestore. Owns the "who to notify?" decision
//   logic for every family event type.
//
// ARCHITECTURE ROLE:
//   - Owned by FamilyViewModel (coordinator). Views observe it via @Environment.
//   - `notify*()` methods are called BY FamilyViewModel after domain operations.
//   - NotificationViewModel owns all notification routing logic — FamilyViewModel
//     passes raw context (IDs + resolved names) but never decides who to notify.
//   - Firestore `onNotificationCreated` Cloud Function delivers FCM push
//     notifications after each document write.
//
// NOTIFICATION ROUTING RULES (enforced in notify*() methods):
//   - NEVER notify the user who performed the action (don't-notify-self guard).
//   - Task assignment: notify assignee + assigner (with personalized messages).
//   - Task completion: notify creator only (not the person who completed it).
//   - Proof submitted: notify creator only.
//   - Proof verified: notify assignee(s) only.
//   - Event created/updated/deleted: notify all participants except the actor.
//
// ============================================================================

import Foundation
import Observation
import FirebaseFirestore
import os.log

/// Manages in-app notification state and delivers notifications to Firestore.
///
/// Provides real-time notification sync, read/unread management, badge count
/// tracking, and the complete set of `notify*()` methods for all family events.
@MainActor
@Observable
final class NotificationViewModel {
    
    // MARK: - Published State
    
    /// Ordered list of notifications for the current user (newest first).
    private(set) var notifications: [FamilyNotification] = []
    
    /// Indicates an in-flight Firestore operation.
    private(set) var isLoading = false
    
    /// Localized error message for Firestore failures.
    var errorMessage: String?
    
    /// #PERF-3: Cached count of unread notifications.
    private(set) var unreadCount: Int = 0
    
    /// Whether there are more notifications to load (pagination)
    private(set) var hasMoreNotifications = false
    
    // MARK: - Private
    
    /// Firestore singleton — @ObservationIgnored (infrastructure, not UI state).
    private var db: Firestore { Firestore.firestore() }
    
    /// Real-time snapshot listener for the current user's notifications.
    @ObservationIgnored private var listener: ListenerRegistration?
    
    /// Current user ID for pagination queries
    @ObservationIgnored private var currentUserId: String?
    
    /// Page size for notification queries (SUGGESTION 5: increased from 50)
    private static let pageSize = 100
    
    /// Logger for notification write failures (SUGGESTION 3)
    private static let logger = Logger(subsystem: "com.", category: "Notifications")
    
    /// SUGGESTION 4: Deduplication cache - tracks recent notifications by hash
    /// Key: hash of (userId, type, relatedId, message prefix)
    /// Value: timestamp when notification was sent
    @ObservationIgnored private var recentNotifications: [String: Date] = [:]
    
    /// Deduplication window - ignore duplicate notifications within this interval
    private static let deduplicationWindow: TimeInterval = 5.0 // 5 seconds
    
    /// Maximum batch size for Firestore WriteBatch operations
    private static let maxBatchSize = 500
    
    deinit { listener?.remove() }
    
    // MARK: - Setup Listener
    
    /// Establishes a real-time Firestore listener for the user's notifications.
    ///
    /// Query bounds:
    /// - Filtered to `userId` — each user only sees their own notifications.
    /// - Ordered by `createdAt` descending — newest first.
    /// - Limited to pageSize (100) most recent.
    ///
    /// - Parameter userId: Firebase UID of the current user.
    func setupListener(userId: String) {
        listener?.remove()
        currentUserId = userId
        
        listener = db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: Self.pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Failed to sync notifications: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // #PERF-1: Decode off main thread
                Task {
                    let notifs = await FirestoreDecode.documents(documents, as: FamilyNotification.self)
                    
                    await MainActor.run {
                        // #PERF-2: Dedup check
                        let newIDs = Set(notifs.compactMap { $0.id })
                        let oldIDs = Set(self.notifications.compactMap { $0.id })
                        let newUnread = notifs.filter({ !$0.isRead }).count
                        let needsUpdate = newIDs != oldIDs ||
                        notifs.count != self.notifications.count ||
                        newUnread != self.unreadCount
                        
                        guard needsUpdate else { return }
                        
                        self.notifications = notifs
                        self.unreadCount = newUnread
                        self.hasMoreNotifications = documents.count >= Self.pageSize
                        LocalNotificationService.shared.updateBadgeCount(newUnread)
                    }
                }
            }
    }
    
    // MARK: - Pagination (SUGGESTION 5)
    
    /// Loads more notifications beyond the current page.
    ///
    /// Uses cursor-based pagination from the last notification's createdAt.
    func loadMoreNotifications() async {
        guard let userId = currentUserId,
              let lastNotification = notifications.last,
              hasMoreNotifications else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .start(after: [lastNotification.createdAt])
                .limit(to: Self.pageSize)
                .getDocuments()
            
            let moreNotifs = await FirestoreDecode.documents(snapshot.documents, as: FamilyNotification.self)
            
            notifications.append(contentsOf: moreNotifs)
            hasMoreNotifications = snapshot.documents.count >= Self.pageSize
            recomputeUnreadCount()
        } catch {
            errorMessage = "Failed to load more notifications: \(error.localizedDescription)"
        }
    }
    
    // MARK: - User Operations
    
    /// Marks a notification as read (optimistic local update + async Firestore write).
    func markAsRead(_ notification: FamilyNotification) async {
        guard let id = notification.id else { return }
        var updated = notification
        updated.isRead = true
        
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index] = updated
            recomputeUnreadCount()
        }
        
        try? db.collection("notifications").document(id).setData(from: updated, merge: true)
    }
    
    /// Deletes a single notification.
    func delete(_ notification: FamilyNotification) async {
        guard let id = notification.id else { return }
        notifications.removeAll { $0.id == id }
        recomputeUnreadCount()
        try? await db.collection("notifications").document(id).delete()
    }
    
    /// Marks all notifications as read using WriteBatch for efficiency.
    ///
    /// SUGGESTION 1: Uses Firestore WriteBatch instead of individual writes.
    /// Batches are split into chunks of 500 (Firestore limit).
    func markAllAsRead() async {
        // Update local state immediately
        var updated = notifications
        for i in updated.indices where !updated[i].isRead {
            updated[i].isRead = true
        }
        notifications = updated
        recomputeUnreadCount()
        
        // Batch write to Firestore
        let unreadNotifications = notifications.filter { $0.id != nil }
        
        // Split into batches of 500 (Firestore limit)
        for chunk in unreadNotifications.chunked(into: Self.maxBatchSize) {
            let batch = db.batch()
            
            for notification in chunk {
                guard let id = notification.id else { continue }
                let ref = db.collection("notifications").document(id)
                batch.updateData(["isRead": true], forDocument: ref)
            }
            
            do {
                try await batch.commit()
            } catch {
                Self.logger.error("Failed to batch mark notifications as read: \(error.localizedDescription)")
            }
        }
    }
    
    /// Deletes all notifications using WriteBatch for efficiency.
    ///
    /// SUGGESTION 1: Uses Firestore WriteBatch instead of individual deletes.
    func deleteAll() async {
        let toDelete = notifications.filter { $0.id != nil }
        notifications = []
        recomputeUnreadCount()
        
        // Split into batches of 500
        for chunk in toDelete.chunked(into: Self.maxBatchSize) {
            let batch = db.batch()
            
            for notification in chunk {
                guard let id = notification.id else { continue }
                let ref = db.collection("notifications").document(id)
                batch.deleteDocument(ref)
            }
            
            do {
                try await batch.commit()
            } catch {
                Self.logger.error("Failed to batch delete notifications: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private: Badge Count
    
    private func recomputeUnreadCount() {
        let newCount = notifications.filter { !$0.isRead }.count
        if unreadCount != newCount {
            unreadCount = newCount
            LocalNotificationService.shared.updateBadgeCount(newCount)
        }
    }
    
    // MARK: - Private: Deduplication (SUGGESTION 4)
    
    /// Generates a hash key for deduplication based on notification properties.
    private func deduplicationKey(
        userId: String,
        type: FamilyNotification.NotificationType,
        relatedId: String?,
        messagePrefix: String
    ) -> String {
        // Use first 50 chars of message to allow for slight variations
        let prefix = String(messagePrefix.prefix(50))
        return "\(userId)|\(type.rawValue)|\(relatedId ?? "nil")|\(prefix)"
    }
    
    /// Checks if a notification should be deduplicated (sent recently).
    private func shouldDeduplicate(key: String) -> Bool {
        // Clean up old entries first
        let cutoff = Date.now.addingTimeInterval(-Self.deduplicationWindow * 2)
        recentNotifications = recentNotifications.filter { $0.value > cutoff }
        
        // Check if we've sent this notification recently
        if let lastSent = recentNotifications[key],
           Date().timeIntervalSince(lastSent) < Self.deduplicationWindow {
            Self.logger.debug("Deduplicated notification: \(key)")
            return true
        }
        
        return false
    }
    
    /// Records that a notification was sent for deduplication tracking.
    private func recordNotificationSent(key: String) {
        recentNotifications[key] = Date.now
    }
    
    // =========================================================================
    // MARK: - Notification Orchestration
    // =========================================================================
    
    /// Delivers notifications for a task assignment to both the assignee and assigner.
    func notifyTaskAssigned(
        taskId: String, title: String,
        assigneeId: String, assignerId: String, familyId: String,
        assignerName: String, assigneeName: String
    ) async {
        guard assigneeId != assignerId else { return }
        
        // Notify assignee
        write(.init(
            userId: assigneeId, familyId: familyId, type: .taskAssigned,
            title: "task_assignment",
            message: AppStrings.assignedYouTask(assignerName, title),
            relatedTaskId: taskId, isRead: false, createdAt: Date.now
        ))
        
        // Notify assigner
        write(.init(
            userId: assignerId, familyId: familyId, type: .taskAssigned,
            title: "task_assignment",
            message: AppStrings.youAssignedTask(assigneeName, title),
            relatedTaskId: taskId, isRead: false, createdAt: Date.now
        ))
    }
    
    /// Notifies the task creator when someone else completes their task.
    func notifyTaskCompleted(
        taskId: String, title: String,
        creatorId: String, performerId: String, familyId: String,
        performerName: String
    ) async {
        guard creatorId != performerId else { return }
        
        write(.init(
            userId: creatorId, familyId: familyId, type: .taskCompleted,
            title: "taskCompletedNotification",
            message: AppStrings.taskCompletedNotifBody(performerName, title),
            relatedTaskId: taskId, isRead: false, createdAt: Date.now
        ))
    }
    
    /// Notifies the assignee when a task assigned to them is deleted.
    func notifyTaskDeleted(
        title: String, assigneeId: String?, deleterId: String?,
        familyId: String, deleterName: String
    ) async {
        guard let assigneeId, assigneeId != deleterId else { return }
        
        write(.init(
            userId: assigneeId, familyId: familyId, type: .taskDeleted,
            title: "task_removed",
            message: AppStrings.memberRemovedTask(deleterName, title),
            relatedTaskId: nil, isRead: false, createdAt: Date.now
        ))
    }
    
    /// Notifies assignees when a task they are assigned to is updated or reassigned.
    func notifyTaskUpdated(
        taskId: String, title: String,
        assigneeId: String?, oldAssigneeId: String?,
        editorId: String, familyId: String
    ) async {
        if let assigneeId, assigneeId != editorId {
            write(.init(
                userId: assigneeId, familyId: familyId, type: .taskAssigned,
                title: "task_updated_notif",
                message: AppStrings.taskUpdatedNotifBody(title),
                relatedTaskId: taskId, isRead: false, createdAt: Date.now
            ))
        }
        
        if let oldAssigneeId, oldAssigneeId != assigneeId, oldAssigneeId != editorId {
            write(.init(
                userId: oldAssigneeId, familyId: familyId, type: .taskAssigned,
                title: "taskReassignedNotificaation",
                message: AppStrings.taskReassignedNotifBody(title),
                relatedTaskId: taskId, isRead: false, createdAt: Date.now
            ))
        }
    }
    
    /// Notifies the task creator when proof is submitted for their task.
    func notifyProofSubmitted(
        taskId: String, title: String,
        creatorId: String, submitterId: String, familyId: String,
        submitterName: String
    ) async {
        guard creatorId != submitterId else { return }
        
        write(.init(
            userId: creatorId, familyId: familyId, type: .proofSubmitted,
            title:"proof_submitted",
            message: "\("submitterName") \("submitted_proof_for"): \(title)",
            relatedTaskId: taskId, isRead: false, createdAt: Date.now
        ))
    }
    
    /// Notifies the assignee of the proof verification result.
    func notifyProofVerified(
        taskId: String?, title: String,
        assigneeId: String?, verifierId: String, familyId: String,
        approved: Bool
    ) async {
        guard let assigneeId, assigneeId != verifierId else { return }
        
        let message = approved
        ? "\("your_task") '\(title)' \("was_approved")!"
        : "\("your_proof_for") '\(title)' \("was_not_accepted")."
        
        write(.init(
            userId: assigneeId, familyId: familyId, type: .proofVerified,
            title: approved ? "approved" : "rejected",
            message: message,
            relatedTaskId: taskId, isRead: false, createdAt: Date.now
        ))
    }
    
    /// Notifies participants and the creator when a new calendar event is created.
    func notifyEventCreated(
        eventId: String, title: String,
        creatorId: String, participantIds: [String], familyId: String,
        creatorName: String, startDate: Date
    ) async {
        let dateStr = startDate.formatted(.dateTime.month().day().hour().minute())
        
        for pid in participantIds where pid != creatorId {
            write(.init(
                userId: pid, familyId: familyId, type: .eventCreated,
                title: "new_event",
                message: AppStrings.addedYouToEvent(creatorName, title, dateStr),
                relatedTaskId: nil, relatedEventId: eventId,
                isRead: false, createdAt: Date.now
            ))
        }
        
        write(.init(
            userId: creatorId, familyId: familyId, type: .eventCreated,
            title: "new_event",
            message: AppStrings.youCreatedEvent(title, dateStr),
            relatedTaskId: nil, relatedEventId: eventId,
            isRead: false, createdAt: Date.now
        ))
    }
    
    /// Notifies participants when an event they are part of is updated.
    ///
    /// SUGGESTION 2: Now uses correct .eventUpdated type
    func notifyEventUpdated(
        eventId: String, title: String,
        participantIds: [String], updatedBy: String, familyId: String
    ) async {
        for pid in participantIds where pid != updatedBy {
            write(.init(
                userId: pid, familyId: familyId, type: .eventUpdated,  // FIXED: was .eventCreated
                title: "eventUpdatedNotification",
                message: AppStrings.eventUpdatedNotifBody(title),
                relatedTaskId: nil, relatedEventId: eventId,
                isRead: false, createdAt: Date.now
            ))
        }
    }
    
    /// Notifies participants when a calendar event they are part of is canceled.
    ///
    /// SUGGESTION 2: Now uses correct .eventCanceled type
    func notifyEventDeleted(
        title: String, participantIds: [String],
        deletedBy: String, familyId: String, deleterName: String
    ) async {
        for pid in participantIds where pid != deletedBy {
            write(.init(
                userId: pid, familyId: familyId, type: .eventCanceled,  // FIXED: was .eventCreated
                title: "eventCanceledNotification",
                message: AppStrings.eventCanceledNotifBody(title, deleterName),
                relatedTaskId: nil, isRead: false, createdAt: Date.now
            ))
        }
    }
    
    // MARK: - Reward & Payout Notifications
    
    /// Notifies the target user when someone requests a payout from them.
    func notifyPayoutRequested(
        requesterId: String,
        requesterName: String,
        targetId: String,
        amount: Double,
        familyId: String
    ) async {
        guard requesterId != targetId else { return }
        
        write(.init(
            userId: targetId,
            familyId: familyId,
            type: .rewardReceived,
            title: "payout_request",
            message: AppStrings.requestedPayoutFrom(requesterName, Int(amount)),
            relatedTaskId: nil,
            isRead: false,
            createdAt: Date.now
        ))
    }
    
    /// Notifies the requester when their payout is approved.
    func notifyPayoutApproved(
        requesterId: String,
        payerName: String,
        amount: Double,
        familyId: String
    ) async {
        write(.init(
            userId: requesterId,
            familyId: familyId,
            type: .rewardReceived,
            title: "payout_approved",
            message: AppStrings.payoutApprovedBody(payerName, Int(amount)),
            relatedTaskId: nil,
            isRead: false,
            createdAt: Date.now
        ))
    }
    
    /// Notifies the requester when their payout is rejected.
    func notifyPayoutRejected(
        requesterId: String,
        rejecterName: String,
        amount: Double,
        familyId: String
    ) async {
        write(.init(
            userId: requesterId,
            familyId: familyId,
            type: .rewardReceived,
            title: "payout_rejected",
            message: AppStrings.payoutRejectedBody(rejecterName, Int(amount)),
            relatedTaskId: nil,
            isRead: false,
            createdAt: Date.now
        ))
    }
    
    /// Notifies a user when they earn a reward from completing a task.
    func notifyRewardEarned(
        userId: String,
        taskTitle: String,
        amount: Double,
        assignerName: String,
        familyId: String,
        taskId: String?
    ) async {
        write(.init(
            userId: userId,
            familyId: familyId,
            type: .rewardReceived,
            title: "reward_earned",
            message: AppStrings.rewardEarnedBody(Int(amount), taskTitle, assignerName),
            relatedTaskId: taskId,
            isRead: false,
            createdAt: Date.now
        ))
    }
    
    // MARK: - Member Joined
    
    /// Notifies all existing family members when a new member joins.
    func notifyMemberJoined(
        newMemberId: String,
        newMemberName: String,
        familyId: String,
        existingMemberIds: [String]
    ) async {
        for memberId in existingMemberIds where memberId != newMemberId {
            write(.init(
                userId: memberId,
                familyId: familyId,
                type: .memberJoined,
                title: "member_joined",
                message: String(localized: "member_joined_body \(newMemberName)"),
                relatedTaskId: nil,
                isRead: false,
                createdAt: Date.now
            ))
        }
    }
    
    // MARK: - Task Overdue (client-side, for immediate feedback)
    
    /// Creates an in-app notification when a task becomes overdue.
    /// Note: The backend `checkOverdueTasks` scheduler also creates these,
    /// but this provides immediate feedback when the user opens the app.
    func notifyTaskOverdue(
        taskId: String,
        title: String,
        assigneeId: String,
        familyId: String
    ) async {
        write(.init(
            userId: assigneeId,
            familyId: familyId,
            type: .taskOverdue,
            title: "task_overdue",
            message: String(localized: "task_overdue_body \(title)"),
            relatedTaskId: taskId,
            isRead: false,
            createdAt: Date.now
        ))
    }
    
    // MARK: - Private Write Helper
    
    /// Writes a single notification document to Firestore with deduplication.
    ///
    /// SUGGESTION 3: Logs failures instead of silently dropping.
    /// SUGGESTION 4: Deduplicates rapid consecutive notifications.
    private func write(_ notification: FamilyNotification) {
        // SUGGESTION 4: Check for duplicate notifications
        let dedupKey = deduplicationKey(
            userId: notification.userId,
            type: notification.type,
            relatedId: notification.relatedTaskId ?? notification.relatedEventId,
            messagePrefix: notification.message
        )
        
        guard !shouldDeduplicate(key: dedupKey) else { return }
        
        // Record this notification for future deduplication
        recordNotificationSent(key: dedupKey)
        
        // Write to Firestore
        do {
            _ = try db.collection("notifications").addDocument(from: notification)
        } catch {
            // SUGGESTION 3: Log failures instead of silently dropping
            Self.logger.error("Failed to write notification: \(error.localizedDescription), type: \(notification.type.rawValue), userId: \(notification.userId)")
        }
    }
}
