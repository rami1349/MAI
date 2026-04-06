// FamilyViewModel.swift
//
//
// PURPOSE:
//   Thin coordinator that injects context (familyId, userId) into child ViewModel
//   calls and orchestrates cross-cutting operations like notification dispatch,
//   reward ledger recording, and local push notification scheduling.
//
// ARCHITECTURE ROLE:
//   - The single root @Environment injected by the app entry point.
//   - Owns and initializes all domain-specific child ViewModels.
//   - Views observe child VMs DIRECTLY (not through this class) for domain data.
//   - This class ONLY adds coordination value that individual VMs can't provide:
//       - Resolving member names from FamilyMemberViewModel
//       - Triggering NotificationViewModel after task/event mutations
//       - Injecting familyId/userId so child VMs don't need to store them
//
// WHAT THIS CLASS DOES NOT DO:
//   - Store or forward data from child VMs (views observe directly)
//   - Own notification decision logic (NotificationViewModel.notify*() handles that)
//   - Implement task/event/habit business logic (delegated to domain VMs)
//
// ARCHITECTURE PATTERN: "Coordinator + Dependency Injector"
//   FamilyViewModel is NOT a "god object" — it intentionally does the minimum
//   needed to connect domain VMs. Any logic beyond context injection belongs
//   in the domain VM that owns the relevant data.
//
// CHILD VIEWMODELS:
//   - familyMemberVM  — Family profile, members list, task groups
//   - taskVM          — Task CRUD, status, proof, rewards
//   - calendarVM      — Calendar event CRUD, date queries
//   - habitVM         — Habit definitions and completion logs
//   - notificationVM  — In-app notification delivery and state
//   - rewardVM        — Reward ledger and wallet history
//
// ERROR PROPAGATION:
//   Child VM error messages forwarded via withObservationTracking.
//   Views that show a global error banner observe FamilyViewModel.errorMessage.
//
// KEY DEPENDENCIES:
//   - All child ViewModels
//   - LocalNotificationService — push notification scheduling
//   - Observation framework — error forwarding from child VMs
//  NOT a god-object. Does NOT:
//  - Store/forward data (views observe child VMs directly via @Observable)
//  - Own notification decision logic (NotificationVM.notify*() handles that)
//  - Pass through operations that don't need familyId/userId injection
//
//  Views call child VMs directly for:
//  - Data reads: taskVM.allTasks, habitVM.habits, notificationVM.notifications, etc.
//  - Notification ops: notificationVM.markAsRead(), .delete(), .deleteAll()
//  - Simple ops: habitVM.deleteHabit(), habitVM.isHabitCompleted()


import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import os

@MainActor
@Observable
final class FamilyViewModel {
    // MARK: - Domain ViewModels
    let familyMemberVM = FamilyMemberViewModel()
    let taskVM = TaskViewModel()
    let calendarVM = CalendarViewModel()
    let habitVM = HabitViewModel()
    let notificationVM = NotificationViewModel()
    let rewardVM = RewardViewModel()
    
    // MARK: - Shared State
    private(set) var currentFamilyId: String?
    private(set) var currentUserId: String?
    var currentViewingGroupId: String?
    var isLoading = false
    var errorMessage: String?
    
    init() {
        // Error forwarding: observe child VM errorMessage properties
        // withObservationTracking replaces Combine Publishers.MergeMany($errorMessage)
        observeChildErrors()
    }
    
    // MARK: - Error Forwarding (@Observable-compatible)
    // Replaces Combine $errorMessage merge. Uses withObservationTracking to watch
    // all child VM errorMessage properties. When any child sets an error, it's
    // forwarded to this VM's errorMessage for global error banners.
    
    private func observeChildErrors() {
        withObservationTracking {
            _ = familyMemberVM.errorMessage
            _ = taskVM.errorMessage
            _ = calendarVM.errorMessage
            _ = habitVM.errorMessage
            _ = notificationVM.errorMessage
        } onChange: {
            Task { @MainActor [weak self] in
                self?.forwardChildError()
                self?.observeChildErrors()  // Re-register for next change
            }
        }
    }
    
    private func forwardChildError() {
        if let e = familyMemberVM.errorMessage { errorMessage = e; familyMemberVM.errorMessage = nil; return }
        if let e = taskVM.errorMessage { errorMessage = e; taskVM.errorMessage = nil; return }
        if let e = calendarVM.errorMessage { errorMessage = e; calendarVM.errorMessage = nil; return }
        if let e = habitVM.errorMessage { errorMessage = e; habitVM.errorMessage = nil; return }
        if let e = notificationVM.errorMessage { errorMessage = e; notificationVM.errorMessage = nil; return }
    }
    
    // MARK: - Private Helpers
    
    private func memberName(_ id: String?) -> String {
        guard let id else { return String(localized: "someone") }
        return familyMemberVM.getMember(by: id)?.displayName ?? String(localized: "someone")
    }
    
    // MARK: - Load Data
    
    func loadFamilyData(familyId: String, userId: String) async {
        guard currentFamilyId != familyId else { return }
        
        isLoading = true
        currentFamilyId = familyId
        currentUserId = userId
        
        async let familyLoad: () = familyMemberVM.loadFamilyData(familyId: familyId)
        async let tasksLoad: () = taskVM.loadTasks(familyId: familyId)
        async let habitsLoad: () = habitVM.loadHabits(userId: userId)
        _ = await (familyLoad, tasksLoad, habitsLoad)
        
        taskVM.setupListener(familyId: familyId, userId: userId)
        notificationVM.setupListener(userId: userId)
        habitVM.setupListener(userId: userId)
        rewardVM.setupListeners(familyId: familyId)
        
        // FIX: Set up calendar listener with a 3-month window (prev/current/next)
        // so Home, Calendar, and TodayTasks all have overlapping event data.
        // CalendarView month navigation expands the range further if needed.
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: .now))!
        let prevMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart)!
        let nextMonthEnd = cal.date(byAdding: .month, value: 2, to: monthStart)!
        calendarVM.setupListener(familyId: familyId, from: prevMonthStart, to: nextMonthEnd)
        
        LocalNotificationService.shared.scheduleTaskDueDateNotifications(tasks: taskVM.allTasks, userId: userId)
        
        isLoading = false
    }
    
    // MARK: - Task Group Operations
    
    func createTaskGroup(name: String, icon: String, color: String) async {
        guard let familyId = familyMemberVM.family?.id, let userId = currentUserId else { return }
        await familyMemberVM.createTaskGroup(name: name, icon: icon, color: color, familyId: familyId, userId: userId)
    }
    
    func deleteTaskGroup(_ group: TaskGroup) async {
        await familyMemberVM.deleteTaskGroup(group, deleteRelatedTasks: true)
    }
    
    // MARK: - Task Operations (Multi-Assignee)
    
    /// Create task with multi-assignee support
    func createTask(
        title: String, description: String? = nil, groupId: String? = nil,
        assignees: [String] = [], dueDate: Date, scheduledTime: Date? = nil,
        priority: FamilyTask.TaskPriority = .medium,
        hasReward: Bool = false, rewardAmount: Double? = nil,
        requiresProof: Bool = false, proofType: FamilyTask.ProofType? = nil,
        isRecurring: Bool = false, recurrenceRule: FamilyTask.RecurrenceRule? = nil
    ) async {
        guard let familyId = familyMemberVM.family?.id, let userId = currentUserId else { return }
        
        let taskId = await taskVM.createTask(
            familyId: familyId, userId: userId, title: title,
            description: description, groupId: groupId, assignees: assignees,
            dueDate: dueDate, scheduledTime: scheduledTime, priority: priority,
            hasReward: hasReward, rewardAmount: rewardAmount,
            requiresProof: requiresProof, proofType: proofType,
            isRecurring: isRecurring, recurrenceRule: recurrenceRule,
            getMemberName: { [weak self] id in self?.memberName(id) ?? String(localized: "someone") }
        )
        
        guard let taskId else { return }
        
        // Linked calendar event - include all assignees as participants
        _ = await calendarVM.createEvent(
            familyId: familyId, title: title, description: nil,
            startDate: scheduledTime ?? dueDate,
            endDate: (scheduledTime ?? dueDate).addingTimeInterval(3600),
            isAllDay: false, color: "7C3AED", createdBy: userId,
            participants: assignees, linkedTaskId: taskId
        )
        
        // Send notifications to all assignees
        for assigneeId in assignees {
            await notificationVM.notifyTaskAssigned(
                taskId: taskId, title: title,
                assigneeId: assigneeId, assignerId: userId, familyId: familyId,
                assignerName: memberName(userId), assigneeName: memberName(assigneeId)
            )
        }
    }
    
    func updateTaskStatus(_ task: FamilyTask, to status: FamilyTask.TaskStatus, authViewModel: AuthViewModel? = nil) async {
        // Capture values BEFORE any async operations
        let taskId = task.id ?? ""
        let taskTitle = task.title
        let assignedBy = task.assignedBy
        let assignerName = memberName(task.assignedBy)
        let assignees = task.allAssignees
        let hasReward = task.hasReward
        let requiresProof = task.requiresProof
        let rewardAmount = task.rewardAmount
        
        await taskVM.updateTaskStatus(
            task, to: status, currentUserId: currentUserId,
            getMemberName: { [weak self] id in self?.memberName(id) ?? String(localized: "someone") }
        )
        
        if status == .completed, let fid = currentFamilyId, let uid = currentUserId {
            await notificationVM.notifyTaskCompleted(
                taskId: taskId, title: taskTitle,
                creatorId: assignedBy, performerId: uid,
                familyId: fid, performerName: memberName(uid)
            )
        }
        
        if status == .completed && hasReward && !requiresProof {
            await authViewModel?.refreshCurrentUser()
            
            if let fid = currentFamilyId, let amount = rewardAmount {
                for recipientId in assignees {
                    await rewardVM.recordTaskReward(
                        familyId: fid,
                        userId: recipientId,
                        amount: amount,
                        taskTitle: taskTitle,
                        taskId: taskId,
                        createdBy: assignedBy,
                        createdByName: assignerName,
                        recipientName: memberName(recipientId)
                    )
                    
                    await notificationVM.notifyRewardEarned(
                        userId: recipientId,
                        taskTitle: taskTitle,
                        amount: amount,
                        assignerName: assignerName,
                        familyId: fid,
                        taskId: taskId
                    )
                }
            }
        }
    }
    
    
    func deleteTask(_ task: FamilyTask) async {
        // Capture values BEFORE any async operations
        let assignees = task.allAssignees
        let taskTitle = task.title
        let taskId = task.id ?? ""
        let deleterId = currentUserId
        let deleterName = memberName(currentUserId)
        
        // 1. Notify assignees about deletion
        if let fid = currentFamilyId {
            for assigneeId in assignees {
                await notificationVM.notifyTaskDeleted(
                    title: taskTitle,
                    assigneeId: assigneeId,
                    deleterId: deleterId,
                    familyId: fid,
                    deleterName: deleterName
                )
            }
        }
        
        // 2. Clean up current user's notifications about this task
        //    (other users' stale notifications handled gracefully in UI)
        if let uid = currentUserId, !taskId.isEmpty {
            let db = Firestore.firestore()
            let notifSnap = try? await db.collection("notifications")
                .whereField("userId", isEqualTo: uid)
                .whereField("relatedTaskId", isEqualTo: taskId)
                .getDocuments()
            for doc in notifSnap?.documents ?? [] {
                try? await doc.reference.delete()
            }
        }
        
        // 3. Delete task + cascaded data (focusSessions, proofs, linked events)
        await taskVM.deleteTask(task)
    }
    
    func updateTask(_ task: FamilyTask) async {
        // Capture values BEFORE any async operations
        let taskId = task.id ?? ""
        let taskTitle = task.title
        let newAssignees = Set(task.allAssignees)
        
        let oldTask = taskVM.allTasks.first { $0.id == task.id }
        let oldAssignees = Set(oldTask?.allAssignees ?? [])
        
        await taskVM.updateTask(task)
        
        if let fid = currentFamilyId, let uid = currentUserId {
            let assignerName = memberName(uid)
            
            // Notify newly added assignees
            let addedAssignees = newAssignees.subtracting(oldAssignees)
            for assigneeId in addedAssignees {
                await notificationVM.notifyTaskAssigned(
                    taskId: taskId, title: taskTitle,
                    assigneeId: assigneeId, assignerId: uid, familyId: fid,
                    assignerName: assignerName, assigneeName: memberName(assigneeId)
                )
            }
            
            // Notify existing assignees about update
            let existingAssignees = newAssignees.intersection(oldAssignees)
            for assigneeId in existingAssignees {
                await notificationVM.notifyTaskUpdated(
                    taskId: taskId, title: taskTitle,
                    assigneeId: assigneeId, oldAssigneeId: assigneeId,
                    editorId: uid, familyId: fid
                )
            }
        }
        
        if let uid = currentUserId {
            LocalNotificationService.shared.scheduleTaskDueDateNotifications(tasks: taskVM.allTasks, userId: uid)
        }
    }
    
    // MARK: - Proof Submission (Multi-Image Support)
    
    /// Submit proof with multiple images (up to 6)
    func submitProof(
        for task: FamilyTask,
        proofDataArray: [Data],
        type: FamilyTask.ProofType,
        progressHandler: ((Double) -> Void)? = nil
    ) async {
        await taskVM.submitProof(
            for: task,
            proofDataArray: proofDataArray,
            type: type,
            progressHandler: progressHandler
        )
        
        if let fid = currentFamilyId, let uid = currentUserId {
            await notificationVM.notifyProofSubmitted(
                taskId: task.id ?? "", title: task.title,
                creatorId: task.assignedBy, submitterId: uid,
                familyId: fid, submitterName: memberName(uid)
            )
        }
    }
    
    /// Submit proof with single image (legacy support)
    func submitProof(for task: FamilyTask, proofData: Data, type: FamilyTask.ProofType) async {
        await taskVM.submitProof(for: task, proofData: proofData, type: type)
        
        if let fid = currentFamilyId, let uid = currentUserId {
            await notificationVM.notifyProofSubmitted(
                taskId: task.id ?? "", title: task.title,
                creatorId: task.assignedBy, submitterId: uid,
                familyId: fid, submitterName: memberName(uid)
            )
        }
    }
    // MARK: - Smart Proof Submission (Homework Auto-Verify)
    
    /// Submit proof with smart verification
    /// - Homework: Triggers background AI verification automatically
    /// - Chores: Just updates status, parent manually approves (no AI cost)
    func submitProofWithSmartVerify(
        task: FamilyTask,
        proofURLs: [String],
        userId: String
    ) async {
        guard let taskId = task.id else { return }
        
        // 1. Update task with proof URLs and set to pending
        var updatedTask = task
        updatedTask.proofURLs = proofURLs
        updatedTask.status = .pendingVerification
        
        await taskVM.updateTask(updatedTask)
        
        // 2. Notify task creator about proof submission
        if let fid = currentFamilyId {
            await notificationVM.notifyProofSubmitted(
                taskId: taskId, title: task.title,
                creatorId: task.assignedBy, submitterId: userId,
                familyId: fid, submitterName: memberName(userId)
            )
        }
        
        // 3. Only trigger AI for homework tasks that should auto-verify
        if task.shouldAutoVerify {
            await triggerBackgroundVerification(
                taskId: taskId,
                imageUrl: proofURLs.first ?? "",
                userId: userId,
                task: task
            )
        }
        // Chores: No AI call - parent will manually approve/reject (saves $$$)
    }
    
    /// Trigger background AI verification for homework.
    ///
    /// Routes through the existing `confirmAction` callable with `verify_task`
    /// action type. Previously called a non-existent `startBackgroundVerification`
    /// callable which silently failed every time.
    private func triggerBackgroundVerification(
        taskId: String,
        imageUrl: String,
        userId: String,
        task: FamilyTask
    ) async {
        let db = Firestore.firestore()
        
        // Mark task as AI processing
        try? await db.collection("tasks").document(taskId).updateData([
            "aiVerificationStatus": "processing"
        ])
        
        // Fire and forget — don't block the UI
        Task {
            do {
                let functions = Functions.functions()
                let actionPayload: [String: Any] = [
                    "action": [
                        "type": "verify_task",
                        "data": [
                            "taskId": taskId,
                            "imageUrl": imageUrl
                        ]
                    ]
                ]
                let _ = try await functions.httpsCallable("confirm_action").call(actionPayload)
            } catch {
                Log.verification.error("Background verification failed: \(error, privacy: .public)")
                try? await db.collection("tasks").document(taskId).updateData([
                    "aiVerificationStatus": "failed"
                ])
            }
        }
    }
    
    /// Upload proof file to Firebase Storage
    /// Returns the download URL
    func uploadProofFile(
        data: Data,
        taskId: String,
        fileType: String,
        fileName: String?
    ) async throws -> String {
        guard let _ = currentUserId,
              let familyId = currentFamilyId else {
            throw NSError(domain: "FamilyViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let storage = Storage.storage()
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let ext = fileType == "image" ? "jpg" : fileType
        
        // CHANGED: Use proofs/{familyId}/ to match your existing rules
        let path = "proofs/\(familyId)/\(taskId)/\(timestamp).\(ext)"
        
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = fileType == "image" ? "image/jpeg" : "application/octet-stream"
        
        let _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        
        return url.absoluteString
    }
    
    func verifyProof(for task: FamilyTask, verifierId: String, approved: Bool) async {
        // Capture values BEFORE any async operations
        let taskId = task.id
        let taskTitle = task.title
        let assignees = task.allAssignees
        let assignedBy = task.assignedBy
        let assignerName = memberName(task.assignedBy)
        let hasReward = task.hasReward
        let rewardAmount = task.rewardAmount
        
        await taskVM.verifyProof(for: task, verifierId: verifierId, approved: approved)
        
        if let fid = currentFamilyId {
            // Notify all assignees about proof verification
            for assigneeId in assignees {
                await notificationVM.notifyProofVerified(
                    taskId: taskId, title: taskTitle,
                    assigneeId: assigneeId, verifierId: verifierId,
                    familyId: fid, approved: approved
                )
            }
            
            // Record in reward ledger when proof approved with reward
            if approved && hasReward, let amount = rewardAmount {
                for assigneeId in assignees {
                    await rewardVM.recordTaskReward(
                        familyId: fid,
                        userId: assigneeId,
                        amount: amount,
                        taskTitle: taskTitle,
                        taskId: taskId,
                        createdBy: assignedBy,
                        createdByName: assignerName,
                        recipientName: memberName(assigneeId)
                    )
                    
                    await notificationVM.notifyRewardEarned(
                        userId: assigneeId,
                        taskTitle: taskTitle,
                        amount: amount,
                        assignerName: assignerName,
                        familyId: fid,
                        taskId: taskId
                    )
                }
            }
        }
    }
    
    // MARK: - Calendar Operations
    
    func loadCalendarEvents(from start: Date, to end: Date) async {
        guard let familyId = familyMemberVM.family?.id else { return }
        await calendarVM.loadEvents(familyId: familyId, from: start, to: end)
        if let uid = currentUserId {
            LocalNotificationService.shared.scheduleEventReminders(events: calendarVM.events, userId: uid)
        }
    }
    
    func createEvent(
        title: String, description: String?, startDate: Date, endDate: Date,
        isAllDay: Bool, color: String, createdBy: String, participants: [String]
    ) async {
        guard let familyId = familyMemberVM.family?.id else { return }
        
        let eventId = await calendarVM.createEvent(
            familyId: familyId, title: title, description: description,
            startDate: startDate, endDate: endDate, isAllDay: isAllDay,
            color: color, createdBy: createdBy, participants: participants
        )
        
        if let eventId {
            await notificationVM.notifyEventCreated(
                eventId: eventId, title: title,
                creatorId: createdBy, participantIds: participants,
                familyId: familyId, creatorName: memberName(createdBy),
                startDate: startDate
            )
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) async {
        if let fid = currentFamilyId, let uid = currentUserId {
            await notificationVM.notifyEventDeleted(
                title: event.title, participantIds: event.participants,
                deletedBy: uid, familyId: fid, deleterName: memberName(uid)
            )
        }
        if let eid = event.id { LocalNotificationService.shared.cancelEventReminders(eventId: eid) }
        await calendarVM.deleteEvent(event)
    }
    
    func updateEvent(_ event: CalendarEvent) async {
        await calendarVM.updateEvent(event)
        if let fid = currentFamilyId, let uid = currentUserId, let eid = event.id {
            await notificationVM.notifyEventUpdated(
                eventId: eid, title: event.title,
                participantIds: event.participants, updatedBy: uid, familyId: fid
            )
        }
    }
    // MARK: - Reward Operations
    
    /// Request payout from a specific person. Sends notification to target.
    func requestPayout(targetId: String, targetName: String, amount: Double) async {
        guard let odId = currentUserId,
              let familyId = currentFamilyId else { return }
        
        let requesterName = memberName(odId)
        
        // Format: "target:userId|displayName" for filtering
        let targetNote = "target:\(targetId)|\(targetName)"
        
        // Create withdrawal request
        await rewardVM.requestWithdrawal(
            familyId: familyId,
            userId: odId,
            userName: requesterName,
            amount: amount,
            note: targetNote
        )
        
        // Send notification to target
        await notificationVM.notifyPayoutRequested(
            requesterId: odId,
            requesterName: requesterName,
            targetId: targetId,
            amount: amount,
            familyId: familyId
        )
    }
    /// Approve a payout request. Sends notification to requester.
    func approvePayout(_ request: WithdrawalRequest) async {
        guard let payerId = currentUserId else { return }
        let payerName = memberName(payerId)
        
        // Approve the withdrawal
        await rewardVM.approveWithdrawal(
            request,
            reviewerId: payerId,
            reviewerName: payerName
        )
        
        // Send notification to requester
        await notificationVM.notifyPayoutApproved(
            requesterId: request.userId,
            payerName: payerName,
            amount: request.amount,
            familyId: request.familyId
        )
    }
    
    /// Reject a payout request. Sends notification to requester.
    func rejectPayout(_ request: WithdrawalRequest, reason: String?) async {
        guard let rejecterId = currentUserId else { return }
        let rejecterName = memberName(rejecterId)
        
        // Reject the withdrawal
        await rewardVM.rejectWithdrawal(
            request,
            reviewerId: rejecterId,
            reviewerName: rejecterName,
            reason: reason
        )
        
        // Send notification to requester
        await notificationVM.notifyPayoutRejected(
            requesterId: request.userId,
            rejecterName: rejecterName,
            amount: request.amount,
            familyId: request.familyId
        )
    }
    
    // MARK: - Habit Operations (familyId/userId injection)
    
    func loadHabits() async {
        guard let userId = currentUserId else { return }
        await habitVM.loadHabits(userId: userId)
    }
    
    func loadHabitLogs(from startDate: Date, to endDate: Date) async {
        guard let userId = currentUserId else { return }
        await habitVM.loadHabitLogs(userId: userId, from: startDate, to: endDate)
    }
    
    func createHabit(name: String, icon: String, colorHex: String) async {
        guard let familyId = familyMemberVM.family?.id, let userId = currentUserId else { return }
        await habitVM.createHabit(name: name, icon: icon, colorHex: colorHex, familyId: familyId, userId: userId)
    }
    
    func toggleHabitCompletion(habit: Habit, date: Date) async {
        guard let userId = currentUserId else { return }
        await habitVM.toggleHabitCompletion(habit: habit, date: date, userId: userId)
    }
    
    // MARK: - Profile & Family Operations (userId/familyId injection)
    
    func updateUserProfile(
        userId: String, displayName: String? = nil,
        dateOfBirth: Date? = nil, goal: String? = nil, avatarData: Data? = nil
    ) async {
        await familyMemberVM.updateUserProfile(
            userId: userId, displayName: displayName,
            dateOfBirth: dateOfBirth, goal: goal, avatarData: avatarData
        )
    }
    
    func updateFamily(
        familyId: String, name: String? = nil, backgroundImageData: Data? = nil
    ) async {
        await familyMemberVM.updateFamily(
            familyId: familyId, name: name, backgroundImageData: backgroundImageData
        )
    }
    
    func updateFamilyBanner(imageData: Data) async {
        await familyMemberVM.updateFamilyBanner(imageData: imageData)
    }
}

// MARK: - Preview Helper

extension View {
    @MainActor
    func previewWithFamilyVM() -> some View {
        let vm = FamilyViewModel()
        return self
            .environment(vm)
            .environment(vm.familyMemberVM)
            .environment(vm.taskVM)
            .environment(vm.calendarVM)
            .environment(vm.habitVM)
            .environment(vm.notificationVM)
    }
}
