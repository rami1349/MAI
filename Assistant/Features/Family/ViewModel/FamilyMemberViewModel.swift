//
//  FamilyMemberViewModel.swift
//  
//
//  ViewModel for family and member management - uses Firestore directly
//
//  PATCHES APPLIED:
//  - #PERF-1: Off-main-thread Firestore decoding via FirestoreDecode helper
//  - #PERF-2: Batched updates to prevent re-render storms
//

import Foundation
import Observation
import FirebaseFirestore
import FirebaseStorage

@MainActor
@Observable
final class FamilyMemberViewModel {
    // MARK: - Published State
    private(set) var family: Family?
    private(set) var familyMembers: [FamilyUser] = []
    private(set) var taskGroups: [TaskGroup] = []
    private(set) var isLoading = false
    var errorMessage: String?
    
    // MARK: - Private
    // Firestore singleton — @ObservationIgnored (infrastructure, not UI state)
    private var db: Firestore { Firestore.firestore() }
    @ObservationIgnored private var membersListener: ListenerRegistration?
    
    // Caches for O(1) lookup
    @ObservationIgnored private var memberCache: [String: FamilyUser] = [:]
    private var groupCache: [String: TaskGroup] = [:]
    
    deinit {
        membersListener?.remove()
    }
    
    // MARK: - Load Data
    
    func loadFamilyData(familyId: String) async {
        isLoading = true
        
        do {
            // Fetch all documents concurrently
            async let familyDoc = db.collection("families").document(familyId).getDocument()
            async let membersSnapshot = db.collection("users").whereField("familyId", isEqualTo: familyId).getDocuments()
            async let groupsSnapshot = db.collection("taskGroups").whereField("familyId", isEqualTo: familyId).getDocuments()
            
            let (f, m, g) = try await (familyDoc, membersSnapshot, groupsSnapshot)
            
            // PERF-1: Decode all documents off main thread in parallel
            async let decodedFamily = FirestoreDecode.document(f, as: Family.self)
            async let decodedMembers = FirestoreDecode.documents(m.documents, as: FamilyUser.self)
            async let decodedGroups = FirestoreDecode.documents(g.documents, as: TaskGroup.self)
            
            let (familyResult, membersResult, groupsResult) = await (decodedFamily, decodedMembers, decodedGroups)
            
            // PERF-2: Batch all updates together in single main thread transaction
            family = familyResult
            familyMembers = membersResult
            taskGroups = groupsResult
            
            rebuildCaches()
            
            // Schedule countdown notifications for birthdays and holidays
            LocalNotificationService.shared.scheduleCountdownNotifications(familyMembers: familyMembers)
            
            // Real-time listener keeps member balances in sync
            setupMembersListener(familyId: familyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Real-time listener for family members — keeps balances in sync across the app.
    private func setupMembersListener(familyId: String) {
        membersListener?.remove()
        
        membersListener = db.collection("users")
            .whereField("familyId", isEqualTo: familyId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    let updated = await FirestoreDecode.documents(docs, as: FamilyUser.self)
                    self.familyMembers = updated
                    self.rebuildCaches()
                }
            }
    }
    
    // MARK: - Lookups
    
    func getMember(by id: String) -> FamilyUser? {
        memberCache[id]
    }
    
    func getTaskGroup(by id: String) -> TaskGroup? {
        groupCache[id]
    }
    
    // MARK: - Task Group Operations
    
    func createTaskGroup(name: String, icon: String, color: String, familyId: String, userId: String) async {
        let group = TaskGroup(
            familyId: familyId,
            name: name,
            icon: icon,
            color: color,
            createdBy: userId,
            createdAt: Date()
        )
        
        // Generate a temporary ID for optimistic update
        let tempId = UUID().uuidString
        var optimisticGroup = group
        optimisticGroup.id = tempId
        
        // OPTIMISTIC UPDATE: Add to local state BEFORE Firestore write
        // This ensures the UI updates immediately, before any listener fires
        taskGroups.append(optimisticGroup)
        groupCache[tempId] = optimisticGroup
        
        do {
            // Write to Firestore - if there's a listener, it will update with real ID
            let ref = try db.collection(FirestoreCollections.taskGroups).addDocument(from: group)
            
            // Update cache with real ID (listener may or may not exist for taskGroups)
            groupCache.removeValue(forKey: tempId)
            var realGroup = group
            realGroup.id = ref.documentID
            groupCache[ref.documentID] = realGroup
            
            // Update the taskGroups array with real ID
            if let index = taskGroups.firstIndex(where: { $0.id == tempId }) {
                taskGroups[index] = realGroup
            }
        } catch {
            // ROLLBACK: Remove the optimistic group on failure
            taskGroups.removeAll { $0.id == tempId }
            groupCache.removeValue(forKey: tempId)
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteTaskGroup(_ group: TaskGroup, deleteRelatedTasks: Bool = true) async {
        guard let id = group.id else {
            errorMessage = "Cannot delete group: invalid ID"
            return
        }
        
        // Store for potential rollback
        let originalGroups = taskGroups
        
        // OPTIMISTIC UPDATE: Remove from local state FIRST for instant UI response
        taskGroups.removeAll { $0.id == id }
        groupCache.removeValue(forKey: id)
        
        do {
            let batch = db.batch()
            
            // Delete related tasks if requested
            if deleteRelatedTasks {
                // IMPORTANT: Include familyId in query to satisfy Firestore security rules
                let tasksSnapshot = try await db.collection(FirestoreCollections.tasks)
                    .whereField(FirestoreFields.familyId, isEqualTo: group.familyId)
                    .whereField("groupId", isEqualTo: id)
                    .getDocuments()
                
                for document in tasksSnapshot.documents {
                    batch.deleteDocument(document.reference)
                }
            }
            
            // Add the group itself to batch
            let groupRef = db.collection(FirestoreCollections.taskGroups).document(id)
            batch.deleteDocument(groupRef)
            
            // Commit the batch
            try await batch.commit()
            
        } catch {
            errorMessage = "Failed to delete group: \(error.localizedDescription)"
            
            // ROLLBACK: Restore local state on error
            taskGroups = originalGroups
            groupCache[id] = group
        }
    }
    
    func taskGroupsWithStats(allTasks: [FamilyTask]) -> [TaskGroup] {
        // PERFORMANCE: Pre-index tasks by groupId for O(1) lookup per group
        // Instead of O(n) filter per group, we do O(n) once + O(1) per group
        var tasksByGroupId: [String: [FamilyTask]] = [:]
        for task in allTasks {
            if let groupId = task.groupId {
                tasksByGroupId[groupId, default: []].append(task)
            }
        }
        
        return taskGroups.map { group in
            var g = group
            // O(1) dictionary lookup instead of O(n) filter
            let tasks = tasksByGroupId[group.id ?? ""] ?? []
            g.taskCount = tasks.count
            let completed = tasks.filter { $0.status == .completed }.count
            g.completionPercentage = tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count) * 100
            return g
        }
    }
    
    /// Returns task groups visible to a user: groups they created or have tasks assigned in.
    func visibleTaskGroups(userId: String, allTasks: [FamilyTask]) -> [TaskGroup] {
        let userGroupIds = Set(
            allTasks
                .filter { $0.assignedTo == userId || $0.assignedBy == userId }
                .compactMap { $0.groupId }
        )
        
        return taskGroups.filter { group in
            guard let gid = group.id else { return false }
            return group.createdBy == userId || userGroupIds.contains(gid)
        }
    }

    // MARK: - User Profile Operations
    
    func updateUserProfile(
        userId: String,
        displayName: String? = nil,
        dateOfBirth: Date? = nil,
        goal: String? = nil,
        avatarData: Data? = nil
    ) async {
        var updates: [String: Any] = [:]
        
        if let displayName = displayName {
            updates["displayName"] = displayName
        }
        
        if let dateOfBirth = dateOfBirth {
            updates["dateOfBirth"] = Timestamp(date: dateOfBirth)
        }
        
        if let goal = goal {
            updates["goal"] = goal
        }
        
        // Upload avatar if provided
        if let avatarData = avatarData {
            do {
                let path = "avatars/\(userId)/\(UUID().uuidString).jpg"
                let ref = Storage.storage().reference().child(path)
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                _ = try await ref.putDataAsync(avatarData, metadata: metadata)
                let avatarURL = try await ref.downloadURL().absoluteString
                updates["avatarURL"] = avatarURL
            } catch {
                // Avatar upload failed - continue without avatar update
            }
        }
        
        guard !updates.isEmpty else { return }
        
        do {
            try await db.collection("users").document(userId).updateData(updates)
            
            // Update local cache
            if let index = familyMembers.firstIndex(where: { $0.id == userId }) {
                var updated = familyMembers[index]
                if let displayName = displayName { updated.displayName = displayName }
                if let dateOfBirth = dateOfBirth { updated.dateOfBirth = dateOfBirth }
                if let goal = goal { updated.goal = goal }
                if let avatarURL = updates["avatarURL"] as? String { updated.avatarURL = avatarURL }
                familyMembers[index] = updated
                memberCache[userId] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Family Operations
    
    func updateFamily(
        familyId: String,
        name: String? = nil,
        backgroundImageData: Data? = nil
    ) async {
        var updates: [String: Any] = [:]
        
        if let name = name {
            updates["name"] = name
        }
        
        // Upload background image if provided
        if let imageData = backgroundImageData {
            do {
                let path = "families/\(familyId)/banner_\(UUID().uuidString).jpg"
                let ref = Storage.storage().reference().child(path)
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                _ = try await ref.putDataAsync(imageData, metadata: metadata)
                let imageURL = try await ref.downloadURL().absoluteString
                updates["bannerURL"] = imageURL
            } catch {
                errorMessage = "Failed to upload image: \(error.localizedDescription)"
                return
            }
        }
        
        guard !updates.isEmpty else { return }
        
        do {
            try await db.collection("families").document(familyId).updateData(updates)
            
            // Update local family - force refresh
            if var updatedFamily = family {
                if let name = name { updatedFamily.name = name }
                if let imageURL = updates["bannerURL"] as? String {
                    updatedFamily.bannerURL = imageURL
                }
                family = updatedFamily
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateFamilyBanner(imageData: Data) async {
        guard let familyId = family?.id else { return }
        await updateFamily(familyId: familyId, backgroundImageData: imageData)
    }
    
    // MARK: - Capabilities
    
    /// Persist updated capabilities and preset to a member's Firestore document.
    ///
    /// Uses `merge: true` to update only capability fields without
    /// overwriting the rest of the document.
    func saveCapabilities(
        _ capabilities: MemberCapabilities,
        preset: CapabilityPreset,
        for memberId: String
    ) async {
        do {
            let capsData: [String: Any] = [
                "canAssignTasks":   capabilities.canAssignTasks,
                "canAssignTo":      capabilities.canAssignTo,
                "canAttachRewards": capabilities.canAttachRewards,
                "canApprovePayouts": capabilities.canApprovePayouts,
                "canVerifyHomework": capabilities.canVerifyHomework,
                "canManageFamily":  capabilities.canManageFamily,
            ]

            try await Firestore.firestore()
                .collection("users")
                .document(memberId)
                .setData([
                    "capabilities": capsData,
                    "capabilityPreset": preset.rawValue,
                ], merge: true)

            // Update local array so UI reflects immediately
            if let idx = familyMembers.firstIndex(where: { $0.id == memberId }) {
                familyMembers[idx].capabilities = capabilities
                familyMembers[idx].capabilityPreset = preset.rawValue
                rebuildCaches()
            }
        } catch {
            errorMessage = "Failed to update permissions: \(error.localizedDescription)"
        }
    }
    // MARK: - Private
    
    private func rebuildCaches() {
        memberCache = familyMembers.reduce(into: [:]) { $0[$1.id ?? ""] = $1 }
        groupCache = taskGroups.reduce(into: [:]) { $0[$1.id ?? ""] = $1 }
    }
}

