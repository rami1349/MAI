// ============================================================================
// TaskViewModel.swift
// 
//
// PURPOSE:
//   Manages the full lifecycle of family tasks — creation, status transitions,
//   proof submission/verification, and real-time Firestore sync. Acts as the
//   data layer for all task-related UI in the app.
//
// ARCHITECTURE ROLE:
//   - Owned by FamilyViewModel (coordinator). Views observe it via @Environment.
//   - Does NOT perform notification logic — FamilyViewModel handles that.
//   - Does NOT know about UI or navigation.
//
// KEY DESIGN DECISIONS:
//   - Bounded query (last 30 days + future, limit 200) prevents loading thousands
//     of historical completed tasks into memory.
//   - All derived state (todayTasks, inProgressTasks, etc.) is pre-computed in
//     `recomputeDerivedCaches()` and stored as caches, NOT as computed
//     properties. This avoids O(n) recalculation on every SwiftUI render pass.
//   - Dedup check in `setTasks(_:)` prevents SwiftUI from re-rendering when
//     Firestore sends a snapshot with unchanged data (e.g., metadata-only updates).
//   - User-specific task indexes (tasksByAssignedTo, tasksByAssignedBy) enable
//     O(1) lookups by user ID instead of O(n) filter scans.
// DATA FLOW:
//   Firestore snapshot → FirestoreDecode (background) → setTasks() →
//   allTasks, activeTasks, index caches, derived caches → Views
//
// KEY DEPENDENCIES:
//   - FirebaseFirestore  — task persistence and real-time sync
//   - FirebaseStorage    — proof image/video uploads
//   - FirestoreDecode    — off-main-thread Codable decoding helper
//   - SoundManager       — audio feedback on task events
//

import Foundation
import Observation
import FirebaseFirestore
import FirebaseStorage

@MainActor
@Observable
final class TaskViewModel {
    // MARK: - Published State
    private(set) var allTasks: [FamilyTask] = []
    /// Tasks visible in views — hides completed non-recurring tasks.
    private(set) var activeTasks: [FamilyTask] = []
    private(set) var isLoading = false
    var errorMessage: String?
    
    // MARK: - PERF-3: Cached Derived Data
    // These are now caches instead of computed properties
    // Updated only when source data changes via recomputeDerivedCaches()
    private(set) var todayTasks: [FamilyTask] = []
    private(set) var inProgressTasks: [FamilyTask] = []
    private(set) var pendingVerificationTasks: [FamilyTask] = []
    private(set) var completionPercentage: Double = 0
    
    // P-6 FIX: These were computed properties — O(n) filter+sort per body evaluation.
    // Now cached in recomputeDerivedCaches() for O(1) reads from views.
    private(set) var overdueTasks: [FamilyTask] = []
    private(set) var tasksDueSoon: [FamilyTask] = []
    private(set) var tasksNeedingAttention: [FamilyTask] = []
    
    // MARK: - Private
    // Firestore singleton — @ObservationIgnored (infrastructure, not UI state)
    private var db: Firestore { Firestore.firestore() }
    @ObservationIgnored private var listener: ListenerRegistration?
    
    /// Current user ID - used to detect when tasks assigned to this user are approved
    @ObservationIgnored private var currentUserId: String?
    
    /// Track task statuses to detect approvals for sound playback
    @ObservationIgnored private var previousTaskStatuses: [String: FamilyTask.TaskStatus] = [:]
    
    /// P-8 FIX: Debounced notification scheduling task handle.
    /// Prevents 400+ UNUserNotificationCenter.add() calls per Firestore snapshot.
    @ObservationIgnored private var notificationScheduleTask: Task<Void, Never>?
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    // MARK: - Caches (internal, not published)
    @ObservationIgnored private var tasksByStatus: [FamilyTask.TaskStatus: [FamilyTask]] = [:]
    @ObservationIgnored private var tasksByGroup: [String: [FamilyTask]] = [:]
    @ObservationIgnored private var tasksByDate: [String: [FamilyTask]] = [:]
    /// Date-indexed cache excluding completed non-recurring tasks (for calendar/day views).
    @ObservationIgnored private var activeTasksByDate: [String: [FamilyTask]] = [:]
    
    // P-5 FIX: O(1) lookup by stableId — replaces O(n) .first { $0.stableId == taskId }
    // Used by TaskDetailView which previously scanned allTasks on every body evaluation.
    @ObservationIgnored private var tasksByStableId: [String: FamilyTask] = [:]
    
    // P-9 FIX: Dictionary for O(1) deep-diff instead of sorting both arrays per snapshot
    @ObservationIgnored private var taskSnapshotById: [String: TaskSnapshot] = [:]
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - P-5: O(1) Task Lookup by StableId
    
    /// Returns a task by its stableId in O(1). Used by TaskDetailView.
    /// Replaces the previous O(n) scan: `allTasks.first { $0.stableId == taskId }`
    func task(byStableId id: String) -> FamilyTask? {
        tasksByStableId[id]
    }
    
    // MARK: - PERFORMANCE: User-specific task caches
    // Pre-indexed for O(1) lookup by user ID
    // Updated for multi-assignee: indexes by all assignees (allAssignees computed property)
    @ObservationIgnored private var tasksByAssignedTo: [String: [FamilyTask]] = [:]
    @ObservationIgnored private var tasksByAssignedBy: [String: [FamilyTask]] = [:]
    
    /// Returns tasks assigned to a specific user - O(1) lookup
    /// Updated for multi-assignee: checks allAssignees
    func tasksAssignedTo(userId: String) -> [FamilyTask] {
        tasksByAssignedTo[userId] ?? []
    }
    
    /// Returns tasks assigned by a specific user - O(1) lookup
    func tasksAssignedBy(userId: String) -> [FamilyTask] {
        tasksByAssignedBy[userId] ?? []
    }
    
    /// Returns all tasks for a user (assigned to OR assigned by) - O(1) lookup + merge
    func tasksFor(userId: String) -> [FamilyTask] {
        let assignedTo = Set(tasksAssignedTo(userId: userId).compactMap { $0.id })
        let assignedBy = tasksAssignedBy(userId: userId)
        
        // Merge without duplicates
        var result = tasksAssignedTo(userId: userId)
        for task in assignedBy {
            if !assignedTo.contains(task.id ?? "") {
                result.append(task)
            }
        }
        return result
    }
    
    // MARK: - FIX-VISIBILITY: Filtered task views for assignee vs assigner
    
    /// Returns tasks visible to the assignee (person doing the task)
    /// - Completed tasks are hidden from assignee
    /// - Shows: todo, inProgress, pendingVerification
    func tasksVisibleToAssignee(userId: String) -> [FamilyTask] {
        tasksAssignedTo(userId: userId).filter { task in
            task.status != .completed
        }
    }
    
    /// Returns tasks visible to the assigner (person who created/assigned the task)
    /// - Shows all tasks including completed ones
    /// - Useful for reviewing task history and verification
    func tasksVisibleToAssigner(userId: String) -> [FamilyTask] {
        tasksAssignedBy(userId: userId)
    }
    
    /// Returns tasks for "My Tasks" view with smart filtering
    /// - For tasks assigned TO the user: hide completed
    /// - For tasks assigned BY the user (to others): show all including completed
    /// Updated for multi-assignee: checks if any assignee is not the current user
    func myTasksFiltered(userId: String) -> [FamilyTask] {
        var result: [FamilyTask] = []
        var addedIds = Set<String>()
        
        // Tasks assigned to me - hide completed
        for task in tasksAssignedTo(userId: userId) {
            if task.status != .completed {
                result.append(task)
                if let id = task.id { addedIds.insert(id) }
            }
        }
        
        // Tasks I assigned to others - hide completed one-offs
        // Multi-assignee: check if ANY assignee is not the current user
        for task in tasksAssignedBy(userId: userId) {
            let assignedToOthers = task.allAssignees.contains { $0 != userId }
            if assignedToOthers,
               let id = task.id,
               !addedIds.contains(id),
               !task.isCompletedOneOff {
                result.append(task)
                addedIds.insert(id)
            }
        }
        
        return result.sortedByPriority()
    }
    
    // MARK: - Load & Listen
    
    // PATCH #2: Add date filter to initial load
    func loadTasks(familyId: String) async {
        isLoading = true
        
        // Only load tasks from last 30 days + future tasks
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        do {
            let snapshot = try await db.collection("tasks")
                .whereField("familyId", isEqualTo: familyId)
                .whereField("dueDate", isGreaterThan: Timestamp(date: thirtyDaysAgo))
                .order(by: "dueDate")
                .limit(to: 200)
                .getDocuments()
            
            // PERF-1: Decode off main thread
            let tasks = await FirestoreDecode.documents(snapshot.documents, as: FamilyTask.self)
            setTasks(tasks)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - PATCH #2: Bounded Listener with Date Filter
    /// Sets up a real-time listener for tasks with bounded query
    /// - Only listens to tasks from last 30 days + future tasks
    /// - Hard limit of 200 tasks for safety
    /// - Requires Firestore composite index: familyId ASC, dueDate ASC
    func setupListener(familyId: String, userId: String) {
        listener?.remove()
        currentUserId = userId
        
        // Only listen to tasks from last 30 days + future tasks
        // This prevents loading thousands of historical completed tasks
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        listener = db.collection("tasks")
            .whereField("familyId", isEqualTo: familyId)
            .whereField("dueDate", isGreaterThan: Timestamp(date: thirtyDaysAgo))
            .order(by: "dueDate")
            .limit(to: 200)  // Hard limit for safety - prevents memory issues
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Failed to sync tasks: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // PERF-1: Move decoding to background thread - keep snapshot callback lightweight
                Task {
                    let tasks = await FirestoreDecode.documents(documents, as: FamilyTask.self)
                    
                    // PERF-2: Publish on main thread in single transaction
                    await MainActor.run {
                        // #SOUND: Detect task approvals and play celebration sounds
                        self.detectTaskApprovalsAndPlaySound(newTasks: tasks, userId: userId)
                        
                        self.setTasks(tasks)
                        
                        // P-8 FIX: Debounce notification scheduling — don't block the main
                        // thread with 400+ UNUserNotificationCenter.add() calls per snapshot.
                        // Defers to a coalesced background task after 500ms of quiet.
                        self.scheduleNotificationsDebounced(tasks: tasks, userId: userId)
                    }
                }
            }
    }
    
    // MARK: - #SOUND: Detect Task Approvals
    
    /// Detects when tasks assigned to the current user were just approved and plays celebration sounds
    private func detectTaskApprovalsAndPlaySound(newTasks: [FamilyTask], userId: String) {
        for task in newTasks {
            guard let taskId = task.id,
                  task.isAssigned(to: userId),  // Multi-assignee: check if user is one of the assignees
                  task.status == .completed else { continue }
            
            // Check if this task was previously pending verification (just approved)
            if let previousStatus = previousTaskStatuses[taskId],
               previousStatus == .pendingVerification {
                // Task was just approved! Play celebration sound
                if task.hasReward && task.rewardPaid == true {
                    SoundManager.shared.playRewardEarned()
                } else {
                    SoundManager.shared.playTaskCompleted()
                }
            }
        }
        
        // Update previous statuses cache for next comparison
        previousTaskStatuses = Dictionary(uniqueKeysWithValues: newTasks.compactMap { task in
            guard let id = task.id else { return nil }
            return (id, task.status)
        })
    }
    
    // MARK: - CRUD Operations
    
    /// Create task with multi-assignee support
    func createTask(
        familyId: String,
        userId: String,
        title: String,
        description: String? = nil,
        groupId: String? = nil,
        assignees: [String] = [],
        dueDate: Date,
        scheduledTime: Date? = nil,
        priority: FamilyTask.TaskPriority = .medium,
        hasReward: Bool = false,
        rewardAmount: Double? = nil,
        requiresProof: Bool = false,
        proofType: FamilyTask.ProofType? = nil,
        isRecurring: Bool = false,
        recurrenceRule: FamilyTask.RecurrenceRule? = nil,
        getMemberName: ((String) -> String?)? = nil
    ) async -> String? {
        // Set assignedTo to first assignee for backwards compatibility
        let primaryAssignee = assignees.first
        
        var task = FamilyTask(
            familyId: familyId, groupId: groupId, title: title, description: description,
            assignedTo: primaryAssignee, assignees: assignees, assignedBy: userId,
            dueDate: dueDate, scheduledTime: scheduledTime,
            status: .todo, priority: priority, createdAt: Date(), completedAt: nil,
            hasReward: hasReward, rewardAmount: rewardAmount, requiresProof: requiresProof, proofType: proofType,
            proofURL: nil, proofURLs: nil, proofVerifiedBy: nil, proofVerifiedAt: nil, rewardPaid: false,
            isRecurring: isRecurring, recurrenceRule: recurrenceRule
        )
        
        // Generate a temporary ID for optimistic update
        let tempId = UUID().uuidString
        task.id = tempId
        
        // OPTIMISTIC UPDATE: Add to local state BEFORE Firestore write
        // This ensures the UI updates immediately, before the listener fires
        var updatedTasks = allTasks
        updatedTasks.append(task)
        setTasks(updatedTasks)
        
        do {
            let ref = try db.collection(FirestoreCollections.tasks).addDocument(from: FamilyTask(
                familyId: familyId, groupId: groupId, title: title, description: description,
                assignedTo: primaryAssignee, assignees: assignees, assignedBy: userId,
                dueDate: dueDate, scheduledTime: scheduledTime,
                status: .todo, priority: priority, createdAt: Date(), completedAt: nil,
                hasReward: hasReward, rewardAmount: rewardAmount, requiresProof: requiresProof, proofType: proofType,
                proofURL: nil, proofURLs: nil, proofVerifiedBy: nil, proofVerifiedAt: nil, rewardPaid: false,
                isRecurring: isRecurring, recurrenceRule: recurrenceRule
            ))
            
            // P-8 FIX: Schedule via debounce — listener will also trigger this,
            // but scheduling immediately gives faster UX for the creating user.
            if assignees.contains(userId) || assignees.isEmpty {
                scheduleNotificationsDebounced(tasks: allTasks, userId: userId)
            }
            
            return ref.documentID
        } catch {
            // ROLLBACK: Remove the optimistic task on failure
            var rollbackTasks = allTasks
            rollbackTasks.removeAll { $0.id == tempId }
            setTasks(rollbackTasks)
            errorMessage = error.localizedDescription
            return nil
        }
    }
    /// Create task from FamilyTask model (used by AddTaskView)
    func createTask(_ task: FamilyTask) async throws {
        var newTask = task
        
        // Generate a temporary ID for optimistic update
        let tempId = UUID().uuidString
        newTask.id = tempId
        
        // OPTIMISTIC UPDATE: Add to local state BEFORE Firestore write
        // This ensures the UI updates immediately, before the listener fires
        var updatedTasks = allTasks
        updatedTasks.append(newTask)
        setTasks(updatedTasks)
        
        do {
            // Write to Firestore - listener will fire and update with real ID
            _ = try db.collection(FirestoreCollections.tasks).addDocument(from: task)
            // Note: Don't update tasks here - the listener will handle it
            // and replace the temp ID with the real Firestore document ID
            
            // P-8 FIX: Debounced — listener will also trigger scheduling
            if let userId = currentUserId, newTask.isAssigned(to: userId) {
                scheduleNotificationsDebounced(tasks: allTasks, userId: userId)
            }
        } catch {
            // ROLLBACK: Remove the optimistic task on failure
            var rollbackTasks = allTasks
            rollbackTasks.removeAll { $0.id == tempId }
            setTasks(rollbackTasks)
            throw error
        }
    }
    
    func updateTaskStatus(
        _ task: FamilyTask,
        to status: FamilyTask.TaskStatus,
        currentUserId: String? = nil,
        getMemberName: ((String) -> String?)? = nil
    ) async {
        guard let id = task.id else { return }
        var updated = task
        updated.status = status
        
        if status == .completed {
            updated.completedAt = Date()
            
            // FIX-REWARD: Mark reward as paid when completing task without proof requirement
            if task.hasReward && !task.requiresProof {
                updated.rewardPaid = true
            }
            
            // #SOUND: Play completion sound for the user completing the task
            if task.hasReward && !task.requiresProof {
                SoundManager.shared.playRewardEarned()
            } else if !task.requiresProof {
                SoundManager.shared.playTaskCompleted()
            }
            // Note: If requiresProof, sound will play when proof is approved
        }
        
        // OPTIMISTIC UPDATE: Update local state immediately for instant UI response
        if let index = allTasks.firstIndex(where: { $0.id == id }) {
            var updatedTasks = allTasks
            updatedTasks[index] = updated
            setTasks(updatedTasks)
        }
        
        do {
            try db.collection("tasks").document(id).setData(from: updated, merge: true)
            
            // PHASE 1 FIX: Transaction-safe reward payment (prevents double-pay)
            // Only pays if task.rewardPaid is still false inside the transaction.
            if status == .completed && task.hasReward && !task.requiresProof,
               let rewardAmount = task.rewardAmount,
               let currentId = currentUserId {
                await payRewardSafely(
                    taskId: id,
                    userId: currentId,
                    amount: rewardAmount,
                    familyId: task.familyId
                )
            }
            
            // Send notification to task assigner/creator about status change
            let assignerId = task.assignedBy
            if assignerId != currentUserId {
                let performerName = currentUserId.flatMap { getMemberName?($0) } ?? "Someone"
                LocalNotificationService.shared.sendTaskStatusNotification(
                    task: task,
                    newStatus: status,
                    performerName: performerName
                )
            }
            
            // Cancel due date notifications if task is completed
            if status == .completed {
                LocalNotificationService.shared.cancelTaskDueNotifications(taskId: id)
                
                // Create next occurrence for recurring tasks
                if task.isRecurring, let rule = task.recurrenceRule {
                    await createNextRecurringTask(from: task, rule: rule, getMemberName: getMemberName)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Update Task Fields
    
    func updateTask(_ task: FamilyTask) async {
        guard let id = task.id else { return }
        
        // OPTIMISTIC UPDATE
        if let index = allTasks.firstIndex(where: { $0.id == id }) {
            var updatedTasks = allTasks
            updatedTasks[index] = task
            setTasks(updatedTasks)
        }
        
        do {
            try db.collection("tasks").document(id).setData(from: task, merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Transaction-Safe Reward Payment
    //
    // PHASE 1 FIX: Prevents double-pay via Firestore transaction.
    // Reads the task's rewardPaid flag inside a transaction; only pays
    // if rewardPaid == false. Atomically sets rewardPaid = true,
    // increments user balance, and writes a rewardTransaction ledger entry.
    
    /// Pay reward to a single user, guarded by a Firestore transaction.
    /// Returns `true` if the reward was actually paid (first call wins).
    @discardableResult
    private func payRewardSafely(
        taskId: String,
        userId: String,
        amount: Double,
        familyId: String
    ) async -> Bool {
        let taskRef = db.collection("tasks").document(taskId)
        let userRef = db.collection("users").document(userId)
        
        do {
            let result = try await db.runTransaction { transaction, errorPointer in
                // 1. Read task inside transaction
                let taskSnap: DocumentSnapshot
                do {
                    taskSnap = try transaction.getDocument(taskRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return false as NSNumber
                }
                
                guard let data = taskSnap.data() else { return false as NSNumber }
                
                // 2. Check rewardPaid flag — if already true, another call won
                let alreadyPaid = data["rewardPaid"] as? Bool ?? false
                if alreadyPaid { return false as NSNumber }
                
                // 3. Atomically set rewardPaid = true
                transaction.updateData(["rewardPaid": true], forDocument: taskRef)
                
                // 4. Increment user balance
                transaction.updateData([
                    "balance": FieldValue.increment(amount)
                ], forDocument: userRef)
                
                // 5. Write ledger entry (rewardTransaction)
                let txnRef = self.db.collection("rewardTransactions").document()
                transaction.setData([
                    "userId": userId,
                    "familyId": familyId,
                    "taskId": taskId,
                    "amount": amount,
                    "type": "task_reward",
                    "reason": "Task completion reward",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: txnRef)
                
                return true as NSNumber
            }
            
            let paid = (result as? NSNumber)?.boolValue ?? false
            
            if paid {
                print("[Reward] Paid $\(amount) to \(userId) for task \(taskId)")
            } else {
                print("[Reward] Skipped — already paid for task \(taskId)")
            }
            return paid
        } catch {
            print("[Reward] Transaction failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Create Next Recurring Task
    private func createNextRecurringTask(from task: FamilyTask, rule: FamilyTask.RecurrenceRule, getMemberName: ((String) -> String?)?) async {
        let calendar = Calendar.current
        
        // Calculate next due date based on recurrence rule
        guard let nextDueDate = calculateNextDueDate(from: task.dueDate, rule: rule) else { return }
        
        // Check if we've passed the end date
        if let endDate = rule.endDate, nextDueDate > endDate { return }
        
        // Calculate next scheduled time if exists
        var nextScheduledTime: Date? = nil
        if let scheduledTime = task.scheduledTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
            nextScheduledTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: nextDueDate)
        }
        
        // Create the next recurring task - preserve all assignees using allAssignees
        _ = await createTask(
            familyId: task.familyId,
            userId: task.assignedBy,
            title: task.title,
            description: task.description,
            groupId: task.groupId,
            assignees: task.allAssignees,  // Multi-assignee: preserve all assignees
            dueDate: nextDueDate,
            scheduledTime: nextScheduledTime,
            priority: task.priority,
            hasReward: task.hasReward,
            rewardAmount: task.rewardAmount,
            requiresProof: task.requiresProof,
            proofType: task.proofType,
            isRecurring: true,
            recurrenceRule: rule,
            getMemberName: getMemberName
        )
    }
    
    private func calculateNextDueDate(from date: Date, rule: FamilyTask.RecurrenceRule) -> Date? {
        let calendar = Calendar.current
        
        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: rule.interval, to: date)
            
        case .weekly:
            if let daysOfWeek = rule.daysOfWeek, !daysOfWeek.isEmpty {
                // Find next matching day of week
                var nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
                for _ in 0..<(7 * rule.interval + 7) { // Search up to interval weeks + 1 week
                    let weekday = calendar.component(.weekday, from: nextDate)
                    if daysOfWeek.contains(weekday) {
                        return nextDate
                    }
                    nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
                }
                return nil
            } else {
                return calendar.date(byAdding: .weekOfYear, value: rule.interval, to: date)
            }
            
        case .monthly:
            return calendar.date(byAdding: .month, value: rule.interval, to: date)
        }
    }
    
    func deleteTask(_ task: FamilyTask) async {
        guard let id = task.id else { return }
        
        // Cancel any scheduled notifications for this task
        LocalNotificationService.shared.cancelTaskDueNotifications(taskId: id)
        
        // OPTIMISTIC UPDATE: Remove from local state immediately for instant UI response
        let originalTasks = allTasks
        let filteredTasks = allTasks.filter { $0.id != id }
        setTasks(filteredTasks)
        
        do {
            // Delete from Firestore
            try await db.collection("tasks").document(id).delete()
            
            // Delete linked calendar event
            // IMPORTANT: Include familyId in query to satisfy Firestore security rules
            let snapshot = try await db.collection("events")
                .whereField("familyId", isEqualTo: task.familyId)
                .whereField("linkedTaskId", isEqualTo: id)
                .getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        } catch {
            // ROLLBACK: Restore original tasks if delete fails
            setTasks(originalTasks)
            errorMessage = "Failed to delete task: \(error.localizedDescription)"
        }
    }
    
    // MARK: - #MULTI-PROOF: Submit Multiple Proof Images
    
    /// Submit proof with multiple images support (up to 6 images)
    /// - Parameters:
    ///   - task: The task to submit proof for
    ///   - proofDataArray: Array of image/video data to upload
    ///   - type: The type of proof (photo/video)
    ///   - progressHandler: Optional callback for upload progress (0.0 to 1.0)
    func submitProof(
        for task: FamilyTask,
        proofDataArray: [Data],
        type: FamilyTask.ProofType,
        progressHandler: ((Double) -> Void)? = nil
    ) async {
        guard let taskId = task.id else { return }
        guard !proofDataArray.isEmpty else { return }
        
        do {
            var uploadedURLs: [String] = []
            let totalItems = Double(proofDataArray.count)
            
            // Upload each image/video
            for (index, proofData) in proofDataArray.enumerated() {
                let ext = type == .photo ? "jpg" : "mp4"
                let path = "proofs/\(taskId)/\(UUID().uuidString).\(ext)"
                let ref = Storage.storage().reference().child(path)
                
                let metadata = StorageMetadata()
                metadata.contentType = type == .photo ? "image/jpeg" : "video/mp4"
                
                _ = try await ref.putDataAsync(proofData, metadata: metadata)
                let proofURL = try await ref.downloadURL().absoluteString
                uploadedURLs.append(proofURL)
                
                // Report progress
                let progress = Double(index + 1) / totalItems
                progressHandler?(progress)
            }
            
            // Update task with all proof URLs
            var updated = task
            updated.proofURLs = uploadedURLs
            updated.proofURL = uploadedURLs.first // Backwards compatibility
            updated.status = .pendingVerification
            try db.collection("tasks").document(taskId).setData(from: updated, merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Submit proof with single image (legacy support)
    func submitProof(for task: FamilyTask, proofData: Data, type: FamilyTask.ProofType) async {
        await submitProof(for: task, proofDataArray: [proofData], type: type, progressHandler: nil)
    }
    
    func verifyProof(for task: FamilyTask, verifierId: String, approved: Bool) async {
        guard let id = task.id else {
            return
        }
        
        // Only the task creator can verify proof
        guard task.assignedBy == verifierId else {
            errorMessage = "Only the task creator can verify proof"
            print(" verifyProof: assignedBy (\(task.assignedBy)) != verifierId (\(verifierId))")
            return
        }
        
        var updated = task
        
        if approved {
            updated.status = .completed
            updated.completedAt = Date()
            updated.proofVerifiedBy = verifierId
            updated.proofVerifiedAt = Date()
            updated.rewardPaid = task.hasReward
            
            // PHASE 1 FIX: Transaction-safe reward payment for proof approval
            if task.hasReward, let rewardAmount = task.rewardAmount {
                // Pay each assignee via the safe transaction method.
                // The first call sets rewardPaid = true on the task atomically.
                // For multi-assignee tasks, we pay each in sequence — the transaction
                // only gates on rewardPaid for the first payment, then we pay the rest
                // via direct increment (the task is already marked as paid).
                let assignees = task.allAssignees
                if let first = assignees.first {
                    let didPay = await payRewardSafely(
                        taskId: id,
                        userId: first,
                        amount: rewardAmount,
                        familyId: task.familyId
                    )
                    // Pay remaining assignees only if first payment succeeded
                    if didPay {
                        for assigneeId in assignees.dropFirst() {
                            let userRef = db.collection("users").document(assigneeId)
                            let txnRef = db.collection("rewardTransactions").document()
                            let batch = db.batch()
                            batch.updateData(["balance": FieldValue.increment(rewardAmount)], forDocument: userRef)
                            batch.setData([
                                "userId": assigneeId,
                                "familyId": task.familyId,
                                "taskId": id,
                                "amount": rewardAmount,
                                "type": "task_reward",
                                "reason": "Task completion reward",
                                "createdAt": FieldValue.serverTimestamp()
                            ], forDocument: txnRef)
                            try? await batch.commit()
                        }
                    }
                }
            }
            
            // #SOUND: Play approval sound for the approver
            if task.hasReward {
                SoundManager.shared.playRewardEarned()
            } else {
                SoundManager.shared.playTaskCompleted()
            }
        } else {
            updated.status = .inProgress
            updated.proofURL = nil
            updated.proofURLs = nil  // Clear all proof URLs on rejection
            
            // #SOUND: Subtle haptic for rejection
            SoundManager.shared.playConfirm()
        }
        
        do {
            try db.collection("tasks").document(id).setData(from: updated, merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Lookups
    
    func tasksFor(date: Date) -> [FamilyTask] {
        activeTasksByDate[Self.dateFormatter.string(from: date)] ?? []
    }
    
    func tasksFor(groupId: String) -> [FamilyTask] {
        (tasksByGroup[groupId] ?? []).filter { !$0.isCompletedOneOff }
    }
    
    // MARK: - Implicit Priority Sorting

    /// Returns tasks sorted by implicit priority (due date urgency + reward bonus)
    func tasksSortedByPriority(_ tasks: [FamilyTask]) -> [FamilyTask] {
        tasks.sortedByPriority()
    }

    /// My tasks sorted by implicit priority
    func myTasksSortedByPriority(userId: String) -> [FamilyTask] {
        myTasksFiltered(userId: userId)  // Already sorted by priority after CHANGE 1
    }

    /// Today's tasks sorted by implicit priority
    var todayTasksSortedByPriority: [FamilyTask] {
        todayTasks  // Already sorted by priority after CHANGE 2
    }

    /// Tasks for a specific date, sorted by priority
    func tasksFor(date: Date, sortedByPriority: Bool = true) -> [FamilyTask] {
        let tasks = activeTasksByDate[Self.dateFormatter.string(from: date)] ?? []
        return sortedByPriority ? tasks.sortedByPriority() : tasks
    }
    
    // NOTE: overdueTasks, tasksDueSoon, tasksNeedingAttention are now cached
    // private(set) var properties (declared above), computed in recomputeDerivedCaches().
    
    // MARK: - Private
    
    // P-8 FIX: Debounced notification scheduling.
    // Before: 400+ UNUserNotificationCenter.add() calls synchronously on main thread
    // per Firestore snapshot (2 notifications × 200 tasks).
    // After: Waits 500ms for rapid-fire snapshots to settle, then schedules once.
    private func scheduleNotificationsDebounced(tasks: [FamilyTask], userId: String) {
        notificationScheduleTask?.cancel()
        notificationScheduleTask = Task { [tasks, userId] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            LocalNotificationService.shared.scheduleTaskDueDateNotifications(
                tasks: tasks,
                userId: userId
            )
        }
    }
    
    private func setTasks(_ tasks: [FamilyTask]) {
        // DEBUG: Structured logging — .debug is stripped from Release builds
        print(" setTasks called with \(tasks.count) tasks:")
        for task in tasks.prefix(5) {
            print("   - \(task.title): id=\(task.id ?? "nil")")
        }
        
        // P-9 FIX: Dictionary-based diff — O(n) instead of O(n log n) sort-based diff.
        // Only compares changed fields for tasks with matching IDs.
        let needsUpdate: Bool
        if tasks.count == allTasks.count {
            needsUpdate = tasks.contains { task in
                guard let id = task.id, let old = taskSnapshotById[id] else { return true }
                return old.status != task.status ||
                       old.title != task.title ||
                       old.completedAt != task.completedAt ||
                       old.proofURL != task.proofURL ||
                       old.rewardPaid != task.rewardPaid ||
                       old.assignees != task.assignees
            }
        } else {
            needsUpdate = true
        }
        
        guard needsUpdate else { return }
        
        // Update source array
        allTasks = tasks
        
        // Active tasks = hide completed non-recurring (they auto-delete after 30 days)
        activeTasks = tasks.filter { !$0.isCompletedOneOff }
        
        // Rebuild all caches
        tasksByStatus = Dictionary(grouping: tasks) { $0.status }
        tasksByGroup = Dictionary(grouping: tasks) { $0.groupId ?? "" }
        tasksByDate = Dictionary(grouping: tasks) { Self.dateFormatter.string(from: $0.dueDate) }
        activeTasksByDate = Dictionary(grouping: activeTasks) { Self.dateFormatter.string(from: $0.dueDate) }
        
        // P-5 FIX: Build stableId index for O(1) lookup from TaskDetailView
        tasksByStableId = Dictionary(tasks.map { ($0.stableId, $0) }, uniquingKeysWith: { _, new in new })
        
        // P-9 FIX: Snapshot for next diff cycle
        taskSnapshotById = Dictionary(
            tasks.compactMap { task -> (String, TaskSnapshot)? in
                guard let id = task.id else { return nil }
                return (id, TaskSnapshot(
                    status: task.status,
                    title: task.title,
                    completedAt: task.completedAt,
                    proofURL: task.proofURL,
                    rewardPaid: task.rewardPaid,
                    assignees: task.assignees
                ))
            },
            uniquingKeysWith: { _, new in new }
        )
        
        // PERFORMANCE: Build user-specific indexes for O(1) lookup
        // Multi-assignee: Index by ALL assignees using allAssignees computed property
        var assignedToIndex: [String: [FamilyTask]] = [:]
        for task in tasks {
            for assigneeId in task.allAssignees {
                assignedToIndex[assigneeId, default: []].append(task)
            }
        }
        tasksByAssignedTo = assignedToIndex
        tasksByAssignedBy = Dictionary(grouping: tasks) { $0.assignedBy }
        
        // Recompute all derived caches
        recomputeDerivedCaches()
    }
    
    /// Recomputes all derived/cached properties.
    /// Called only when source data (allTasks) changes — never during body evaluation.
    ///
    /// P-6 FIX: overdueTasks, tasksDueSoon, and tasksNeedingAttention are now cached
    /// here instead of being computed properties. Views get O(1) reads.
    private func recomputeDerivedCaches() {
        let todayKey = Self.dateFormatter.string(from: Date())
        let now = Date()
        
        // Today's visible tasks - sorted by implicit priority
        let todayRaw = activeTasksByDate[todayKey] ?? []
        todayTasks = todayRaw.sortedByPriority()
        
        // In progress - sorted by priority
        let inProgressRaw = tasksByStatus[.inProgress] ?? []
        inProgressTasks = inProgressRaw.sortedByPriority()
        
        // Pending verification - sorted by priority
        let pendingRaw = tasksByStatus[.pendingVerification] ?? []
        pendingVerificationTasks = pendingRaw.sortedByPriority()
        
        // Completion percentage uses ALL today's tasks (including completed one-offs)
        let allToday = tasksByDate[todayKey] ?? []
        if allToday.isEmpty {
            completionPercentage = 0
        } else {
            let completed = allToday.filter { $0.status == .completed }.count
            completionPercentage = Double(completed) / Double(allToday.count) * 100
        }
        
        // P-6 FIX: Cache overdue tasks (were O(n) computed properties)
        overdueTasks = activeTasks
            .filter { $0.dueDate < now && !Calendar.current.isDateInToday($0.dueDate) && $0.status != .completed }
            .sorted { $0.dueDate < $1.dueDate }
        
        // P-6 FIX: Cache tasks due soon (within 2 hours)
        tasksDueSoon = activeTasks
            .filter { $0.isDueSoon }
            .sortedByPriority()
        
        // P-6 FIX: Cache tasks needing attention (overdue + due soon + in progress, deduped)
        var attentionResult: [FamilyTask] = []
        var attentionIds = Set<String>()
        for task in overdueTasks {
            if let id = task.id, attentionIds.insert(id).inserted { attentionResult.append(task) }
        }
        for task in tasksDueSoon {
            if let id = task.id, attentionIds.insert(id).inserted { attentionResult.append(task) }
        }
        for task in inProgressTasks {
            if let id = task.id, attentionIds.insert(id).inserted { attentionResult.append(task) }
        }
        tasksNeedingAttention = attentionResult
    }
}

// MARK: - TaskSnapshot (lightweight struct for dictionary diff)

/// P-9 FIX: Captures only the fields checked during dedup diffing.
/// Avoids hashing/comparing the entire FamilyTask struct.
private struct TaskSnapshot {
    let status: FamilyTask.TaskStatus
    let title: String
    let completedAt: Date?
    let proofURL: String?
    let rewardPaid: Bool
    let assignees: [String]
}


// MARK: - Improvements & Code Quality Notes
//
// SUGGESTION 1 — Magic number 200:
//   The task limit `200` appears in both loadTasks() and setupListener().
//   Extract to a private constant: `private static let taskQueryLimit = 200`
//
// SUGGESTION 2 — Magic number 30 (days):
//   The 30-day lookback appears twice. Extract to:
//   `private static let taskHistoryDays = -30`
//
// SUGGESTION 3 — RESOLVED: Reward payment is now transaction-safe.
//   payRewardSafely() uses a Firestore transaction to check rewardPaid == false
//   before paying. Double-tap is prevented and a rewardTransaction ledger entry
//   is written atomically alongside the balance increment.
//
// SUGGESTION 4 — verifyProof authorization is client-side only:
//   The `task.assignedBy == verifierId` check can be bypassed by a malicious client.
//   This must also be enforced in Firestore security rules.
//
// SUGGESTION 5 — submitProof sequential uploads:
//   Uploading proof images sequentially could be slow for 6 images. Consider
//   `async let` or TaskGroup for concurrent uploads with aggregated progress.
//
// SUGGESTION 6 — setTasks deep check sorts on every call:
//   The deep diff sorts both arrays on every Firestore event. For large task lists,
//   consider a dictionary-based diff: `[id: FamilyTask]` comparison instead.
