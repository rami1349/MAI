// ============================================================================
// AccountDeletionService.swift
//
//
// PURPOSE:
//   Handles the complete, multi-step deletion of a user account and ALL
//   associated Firestore data AND Firebase Storage files. Extracted from
//   AuthViewModel for separation of concerns — this is a complex, stateful
//   operation that doesn't belong in a ViewModel.
//
// ARCHITECTURE:
//   Declared as a Swift `actor` to prevent concurrent deletion attempts
//   from racing against each other (e.g., two devices triggering deletion
//   simultaneously). All calls are serialized through the actor's executor.
//
// DELETION SEQUENCE (11 steps):
//   1. Batch-delete user-owned collections (habits, habitLogs, notifications)
//   2. Batch-unassign tasks assigned to this user (clears `assignedTo` field)
//   3. Delete tasks CREATED by this user (including focusSessions subcollections)
//   4. Batch-delete calendar events created by this user
//   5. Delete Firebase Storage files (avatars, proof images for user-created tasks)
//   6. Delete reward transactions and withdrawal requests for this user
//   7. Remove FCM token (stops push delivery to this device)
//   8. Remove user from family's `memberIds` array
//   9. Delete the Firestore user profile document
//  10. Delete the Firebase Auth account (CRITICAL — must be last)
//
// ERROR STRATEGY:
//   - Steps 1–9 (data cleanup): failures are collected as `warnings` but do NOT
//     abort the deletion. Orphaned data is preferable to a stuck account.
//   - Step 10 (Firebase Auth delete): failure DOES abort and return an error.
//     If Firebase requires re-authentication, `requiresReauthentication = true`
//     is returned so AuthViewModel can prompt the user to re-verify identity.
//
// BATCH WRITE STRATEGY:
//   Firestore batch writes are used for collections with multiple documents.
//   The batch limit is 500 operations. A safety cap of 450 is used with
//   chunking for overflow (see `batchDeleteUserOwnedData`).
//
// STORAGE CLEANUP STRATEGY:
//   Firebase Storage does not support "delete all files under a path" atomically.
//   We use `StorageReference.listAll()` to enumerate files under known prefixes,
//   then delete each file individually. Deletion failures are collected as
//   warnings — orphaned Storage files are preferable to a stuck account.
//
//   Known Storage paths:
//   - avatars/{userId}/                   — user profile avatars
//   - proofs/{familyId}/{taskId}/         — proof images (v2 path from FamilyViewModel)
//   - proofs/{taskId}/                    — proof images (v1 path from TaskViewModel)
//
//   Family banner images (families/{familyId}/) are NOT deleted here because
//   they belong to the family, not the departing user. A Cloud Function should
//   handle family cleanup if the last member leaves.
//
// ============================================================================

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import os

// MARK: - Result Model

/// Encapsulates the outcome of an account deletion attempt.
///
/// - `success`: `true` if the Firebase Auth account was deleted successfully.
///   Data cleanup failures are reported in `warnings` but don't affect `success`.
/// - `requiresReauthentication`: `true` if Firebase rejected the Auth delete
///   because the session is too old. AuthViewModel should prompt reauth and retry.
/// - `error`: Human-readable error message when `success == false`.
/// - `warnings`: Non-fatal data cleanup failures. Account was deleted but some
///   Firestore/Storage data may remain.
struct AccountDeletionResult {
    let success: Bool
    let requiresReauthentication: Bool
    let error: String?
    let warnings: [String]
}

// MARK: - Service

/// Performs complete, ordered account and data deletion for a user.
///
/// Implemented as a Swift `actor` to serialize concurrent deletion attempts.
/// Accessed via the `shared` singleton.
actor AccountDeletionService {

    static let shared = AccountDeletionService()

    private var db: Firestore { Firestore.firestore() }
    private var storage: Storage { Storage.storage() }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.app",
        category: "AccountDeletion"
    )

    private init() {}

    // MARK: - Main Deletion Entry Point

    /// Permanently and irreversibly deletes the user's account and all associated data.
    ///
    /// Executes the 11-step deletion sequence. Data cleanup failures (steps 1–9) are
    /// collected as warnings but do not abort the deletion — an account with orphaned
    /// data is better than an account the user can't delete.
    ///
    /// Firebase Auth deletion (step 10) is the only step that can abort with an error:
    /// - `AuthErrorCode.requiresRecentLogin`: Session too old → caller must reauthenticate.
    /// - All other Auth errors: Returned in `result.error`.
    ///
    /// State reset after successful deletion is handled by `AuthViewModel`'s auth listener
    /// (same path as a normal sign-out).
    ///
    /// - Parameters:
    ///   - userId: Firebase Auth UID of the user to delete.
    ///   - familyId: The user's family ID (if any). Nil for users who never joined a family.
    /// - Returns: `AccountDeletionResult` describing the outcome.
    func deleteAccount(userId: String, familyId: String?) async -> AccountDeletionResult {
        guard let user = Auth.auth().currentUser else {
            return AccountDeletionResult(
                success: false,
                requiresReauthentication: false,
                error: "No user logged in",
                warnings: []
            )
        }

        var cleanupWarnings: [String] = []

        // ── Step 1: Batch-delete habits, habitLogs, notifications ──
        // These are user-owned collections that no other user needs after deletion.
        do {
            try await batchDeleteUserOwnedData(userId: userId)
        } catch {
            cleanupWarnings.append("User data cleanup: \(error.localizedDescription)")
        }

        // ── Step 2: Unassign tasks assigned to this user ──
        // Clears `assignedTo` rather than deleting — tasks were created by parents
        // and belong to the family record, not the departing user.
        do {
            try await batchUnassignUserTasks(userId: userId)
        } catch {
            cleanupWarnings.append("Unassign tasks: \(error.localizedDescription)")
        }

        // ── Step 3: Delete tasks CREATED by this user ──
        // Tasks the departing user created are cleaned up entirely.
        // focusSessions subcollections must be deleted before parent documents.
        // Returns task IDs + familyId pairs so Storage can be cleaned in step 5.
        var deletedTaskIds: [(taskId: String, familyId: String)] = []
        do {
            deletedTaskIds = try await deleteUserCreatedTasks(userId: userId)
        } catch {
            cleanupWarnings.append("Created tasks: \(error.localizedDescription)")
        }

        // ── Step 4: Delete calendar events created by this user ──
        do {
            try await batchDeleteUserCreatedEvents(userId: userId)
        } catch {
            cleanupWarnings.append("Events: \(error.localizedDescription)")
        }

        // ── Step 5: Delete Firebase Storage files ──
        // Avatars + proof images for tasks that were deleted in step 3.
        // Non-fatal: orphaned Storage files are acceptable.
        let storageWarnings = await deleteUserStorageFiles(
            userId: userId,
            deletedTaskIds: deletedTaskIds
        )
        cleanupWarnings.append(contentsOf: storageWarnings)

        // ── Step 6: Delete reward transactions and withdrawal requests ──
        do {
            try await deleteUserRewardData(userId: userId, familyId: familyId)
        } catch {
            cleanupWarnings.append("Reward data: \(error.localizedDescription)")
        }

        // ── Step 7: Remove FCM token (stops push delivery to this device) ──
        // Not wrapped in do/catch — removeFCMToken is already non-throwing.
        await LocalNotificationService.shared.removeFCMToken(userId: userId)

        // ── Step 8: Remove user from family memberIds ──
        if let familyId = familyId {
            do {
                try await removeUserFromFamily(userId: userId, familyId: familyId)
            } catch {
                cleanupWarnings.append("Family removal: \(error.localizedDescription)")
            }
        }

        // ── Step 9: Delete user Firestore profile document ──
        do {
            try await db.collection(FirestoreCollections.users).document(userId).delete()
        } catch {
            cleanupWarnings.append("User doc: \(error.localizedDescription)")
        }

        // ── Step 10: Delete Firebase Auth account (CRITICAL — must be last) ──
        // This is the point of no return. If it succeeds, the account is gone.
        // The auth listener in AuthViewModel handles state teardown automatically.
        do {
            try await user.delete()

            if cleanupWarnings.isEmpty {
                Self.logger.info("Account \(userId, privacy: .private) deleted cleanly")
            } else {
                Self.logger.info("Account \(userId, privacy: .private) deleted with \(cleanupWarnings.count, privacy: .public) warnings")
                Log.account.info("Account deleted with cleanup warnings: \(cleanupWarnings, privacy: .public)")
            }

            return AccountDeletionResult(
                success: true,
                requiresReauthentication: false,
                error: nil,
                warnings: cleanupWarnings
            )

        } catch let error as NSError {
            // Detect Firebase's "session too old" error — requires reauthentication
            if error.domain == AuthErrorDomain,
               error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                return AccountDeletionResult(
                    success: false,
                    requiresReauthentication: true,
                    error: "Please re-enter your password to delete your account",
                    warnings: cleanupWarnings
                )
            } else {
                return AccountDeletionResult(
                    success: false,
                    requiresReauthentication: false,
                    error: error.localizedDescription,
                    warnings: cleanupWarnings
                )
            }
        }
    }

    // MARK: - Private: Batch Delete User-Owned Collections

    /// Batch-deletes all habits, habitLogs, and notifications for the user.
    ///
    /// Uses proper chunking to handle large datasets safely. All document references
    /// are collected first, then processed in batches of 450 (below Firestore's 500-op limit).
    ///
    /// - Parameter userId: Firebase UID of the user whose data to delete.
    private func batchDeleteUserOwnedData(userId: String) async throws {
        let maxBatchSize = 450 // Conservative cap below Firestore's 500-op limit
        
        // Collect ALL document references first (no early exit)
        var allDocRefs: [DocumentReference] = []
        
        // Fetch habits
        let habitsSnapshot = try await db.collection(FirestoreCollections.habits)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        allDocRefs.append(contentsOf: habitsSnapshot.documents.map { $0.reference })
        
        // Fetch habit logs
        let habitLogsSnapshot = try await db.collection(FirestoreCollections.habitLogs)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        allDocRefs.append(contentsOf: habitLogsSnapshot.documents.map { $0.reference })
        
        // Fetch notifications
        let notificationsSnapshot = try await db.collection(FirestoreCollections.notifications)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        allDocRefs.append(contentsOf: notificationsSnapshot.documents.map { $0.reference })
        
        // Process in chunks of maxBatchSize
        guard !allDocRefs.isEmpty else { return }
        
        for chunk in allDocRefs.chunked(into: maxBatchSize) {
            let batch = db.batch()
            for docRef in chunk {
                batch.deleteDocument(docRef)
            }
            try await batch.commit()
        }
    }

    // MARK: - Private: Unassign Tasks

    /// Batch-clears the `assignedTo` field on all tasks assigned to this user.
    ///
    /// Uses `FieldValue.delete()` to atomically remove the field rather than
    /// setting it to nil or empty string.
    ///
    /// ⚠️ Only handles the v1 single-assignee field (`assignedTo`). Tasks that
    /// include this user in the v2 `assignees` array are NOT cleaned up.
    /// See improvement suggestion below.
    ///
    /// - Parameter userId: Firebase UID of the user being unassigned.
    private func batchUnassignUserTasks(userId: String) async throws {
        let snapshot = try await db.collection(FirestoreCollections.tasks)
            .whereField(FirestoreFields.assignedTo, isEqualTo: userId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        for doc in snapshot.documents {
            // Remove the assignedTo field entirely rather than setting to null
            batch.updateData([FirestoreFields.assignedTo: FieldValue.delete()], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Private: Delete User-Created Tasks

    /// Deletes all tasks created by this user, including their focusSessions subcollections.
    ///
    /// Firestore does not cascade-delete subcollections — they must be deleted explicitly.
    /// This method deletes `focusSessions` child documents before deleting each task document.
    ///
    /// Returns the IDs and familyIds of deleted tasks so that the caller can clean up
    /// associated Firebase Storage files (proof images).
    ///
    /// - Parameter userId: Firebase UID of the user whose created tasks to delete.
    /// - Returns: Array of (taskId, familyId) tuples for Storage cleanup.
    @discardableResult
    private func deleteUserCreatedTasks(userId: String) async throws -> [(taskId: String, familyId: String)] {
        let snapshot = try await db.collection(FirestoreCollections.tasks)
            .whereField(FirestoreFields.createdBy, isEqualTo: userId)
            .getDocuments()

        var deletedTasks: [(taskId: String, familyId: String)] = []

        for document in snapshot.documents {
            let taskId = document.documentID
            let familyId = document.data()[FirestoreFields.familyId] as? String ?? ""

            // Collect task info for Storage cleanup before deleting the Firestore doc
            deletedTasks.append((taskId: taskId, familyId: familyId))

            // Delete subcollection first — Firestore doesn't cascade parent deletes
            let sessionsSnapshot = try await document.reference
                .collection(FirestoreCollections.focusSessions)
                .getDocuments()

            if !sessionsSnapshot.documents.isEmpty {
                let batch = db.batch()
                for session in sessionsSnapshot.documents {
                    batch.deleteDocument(session.reference)
                }
                try await batch.commit()
            }

            // Now safe to delete the parent task document
            try await document.reference.delete()
        }

        return deletedTasks
    }

    // MARK: - Private: Delete User-Created Events

    /// Batch-deletes all calendar events created by this user.
    ///
    /// - Parameter userId: Firebase UID of the user whose events to delete.
    private func batchDeleteUserCreatedEvents(userId: String) async throws {
        let snapshot = try await db.collection(FirestoreCollections.events)
            .whereField(FirestoreFields.createdBy, isEqualTo: userId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Private: Delete Firebase Storage Files

    /// Deletes all Firebase Storage files owned by or associated with this user.
    ///
    /// Covers three categories of files:
    /// 1. **Avatar images** at `avatars/{userId}/` — uploaded via profile editing
    /// 2. **Proof images (v2 path)** at `proofs/{familyId}/{taskId}/` — uploaded via FamilyViewModel
    /// 3. **Proof images (v1 path)** at `proofs/{taskId}/` — uploaded via TaskViewModel
    ///
    /// Each deletion is independent — a failure in one category does not block others.
    /// All failures are collected as warning strings.
    ///
    /// - Parameters:
    ///   - userId: Firebase UID of the user whose files to delete.
    ///   - deletedTaskIds: Task IDs + family IDs from step 3, used to locate proof files.
    /// - Returns: Array of non-fatal warning messages for any failed deletions.
    private func deleteUserStorageFiles(
        userId: String,
        deletedTaskIds: [(taskId: String, familyId: String)]
    ) async -> [String] {
        var warnings: [String] = []
        let storageRef = storage.reference()

        // ── 1. Delete avatar images ──
        // Path: avatars/{userId}/
        // Users may have multiple avatars (old ones aren't cleaned up on re-upload).
        do {
            let deleted = try await deleteStoragePrefix(storageRef.child("avatars/\(userId)"))
            if deleted > 0 {
                Self.logger.debug("Deleted \(deleted, privacy: .public) avatar file(s) for user \(userId, privacy: .private)")
            }
        } catch {
            warnings.append("Avatar cleanup: \(error.localizedDescription)")
            Self.logger.error("Avatar cleanup failed: \(error.localizedDescription, privacy: .public)")
        }

        // ── 2. Delete proof images for user-created tasks ──
        // Two path patterns exist due to codebase evolution:
        //   v2: proofs/{familyId}/{taskId}/  (FamilyViewModel.uploadProofFile)
        //   v1: proofs/{taskId}/             (TaskViewModel.submitProof)
        //
        // We attempt both patterns for each deleted task. If a prefix doesn't exist,
        // listAll() returns empty results — no error is thrown.
        for (taskId, familyId) in deletedTaskIds {
            // v2 path: proofs/{familyId}/{taskId}/
            if !familyId.isEmpty {
                do {
                    let deleted = try await deleteStoragePrefix(
                        storageRef.child("proofs/\(familyId)/\(taskId)")
                    )
                    if deleted > 0 {
                        Self.logger.debug("Deleted \(deleted, privacy: .public) proof file(s) at proofs/\(familyId, privacy: .private)/\(taskId, privacy: .private)")
                    }
                } catch {
                    warnings.append("Proof cleanup (v2) for task \(taskId): \(error.localizedDescription)")
                }
            }

            // v1 path: proofs/{taskId}/
            do {
                let deleted = try await deleteStoragePrefix(
                    storageRef.child("proofs/\(taskId)")
                )
                if deleted > 0 {
                    Self.logger.debug("Deleted \(deleted, privacy: .public) proof file(s) at proofs/\(taskId, privacy: .private)")
                }
            } catch {
                warnings.append("Proof cleanup (v1) for task \(taskId): \(error.localizedDescription)")
            }
        }

        return warnings
    }

    /// Enumerates and deletes all files under a Firebase Storage prefix.
    ///
    /// Firebase Storage does not support recursive deletion natively. This method
    /// uses `listAll()` to get all items under the prefix, then deletes each one.
    /// Recursion handles nested subdirectories.
    ///
    /// `listAll()` returns ALL items (no page token needed, unlike `list(maxResults:)`).
    /// For users with thousands of proof files, consider switching to `list(maxResults:)`
    /// with pagination to avoid memory spikes.
    ///
    /// - Parameter prefix: The `StorageReference` pointing to the directory prefix.
    /// - Returns: The number of files successfully deleted.
    /// - Throws: If `listAll()` fails. Individual file deletion failures are logged
    ///   but do not throw — partial cleanup is acceptable.
    private func deleteStoragePrefix(_ prefix: StorageReference) async throws -> Int {
        let result = try await prefix.listAll()

        var deletedCount = 0

        // Delete all files under this prefix
        for item in result.items {
            do {
                try await item.delete()
                deletedCount += 1
            } catch {
                // Log but don't throw — orphaned files are acceptable
                Self.logger.error("Failed to delete Storage file \(item.fullPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        // Recurse into subdirectories (e.g., proofs/{familyId}/{taskId}/ may have nested paths)
        for subPrefix in result.prefixes {
            do {
                let subDeleted = try await deleteStoragePrefix(subPrefix)
                deletedCount += subDeleted
            } catch {
                Self.logger.error("Failed to list Storage prefix \(subPrefix.fullPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return deletedCount
    }

    // MARK: - Private: Delete Reward Data

    /// Deletes reward transactions and withdrawal requests for this user.
    ///
    /// Reward transactions record task completions with payments. Withdrawal requests
    /// are pending/approved/rejected cash-out records. Both are user-owned PII and
    /// must be removed for full account deletion compliance.
    ///
    /// - Parameters:
    ///   - userId: Firebase UID of the user whose reward data to delete.
    ///   - familyId: The user's family ID (needed to scope transaction queries).
    private func deleteUserRewardData(userId: String, familyId: String?) async throws {
        let maxBatchSize = 450
        var allDocRefs: [DocumentReference] = []

        guard let familyId = familyId else { return }

        // Reward transactions for this user
        let txSnapshot = try await db.collection(FirestoreCollections.families)
            .document(familyId)
            .collection(FirestoreCollections.transactions)
            .whereField(FirestoreFields.userId, isEqualTo: userId)
            .getDocuments()
        allDocRefs.append(contentsOf: txSnapshot.documents.map { $0.reference })

        // Withdrawal requests by this user
        let withdrawalSnapshot = try await db.collection(FirestoreCollections.families)
            .document(familyId)
            .collection(FirestoreCollections.withdrawals)
            .whereField(FirestoreFields.userId, isEqualTo: userId)
            .getDocuments()
        allDocRefs.append(contentsOf: withdrawalSnapshot.documents.map { $0.reference })

        guard !allDocRefs.isEmpty else { return }

        for chunk in allDocRefs.chunked(into: maxBatchSize) {
            let batch = db.batch()
            for docRef in chunk {
                batch.deleteDocument(docRef)
            }
            try await batch.commit()
        }
    }

    // MARK: - Private: Remove from Family

    /// Removes the user's UID from the family's `memberIds` array.
    ///
    /// Uses `FieldValue.arrayRemove` for atomic array mutation — safe against
    /// concurrent membership changes from other family members.
    ///
    /// - Parameters:
    ///   - userId: Firebase UID to remove.
    ///   - familyId: Firestore document ID of the family.
    private func removeUserFromFamily(userId: String, familyId: String) async throws {
        try await db.collection(FirestoreCollections.families).document(familyId).updateData([
            FirestoreFields.memberIds: FieldValue.arrayRemove([userId])
        ])
    }
}
