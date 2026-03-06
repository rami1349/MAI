// ============================================================================
// AccountDeletionService.swift
// FamilyHub
//
// PURPOSE:
//   Handles the complete, multi-step deletion of a user account and ALL
//   associated Firestore data. Extracted from AuthViewModel for separation
//   of concerns — this is a complex, stateful operation that doesn't belong
//   in a ViewModel.
//
// ARCHITECTURE:
//   Declared as a Swift `actor` to prevent concurrent deletion attempts
//   from racing against each other (e.g., two devices triggering deletion
//   simultaneously). All calls are serialized through the actor's executor.
//
// DELETION SEQUENCE (10 steps):
//   1. Batch-delete user-owned collections (habits, habitLogs, notifications)
//   2. Batch-unassign tasks assigned to this user (clears `assignedTo` field)
//   3. Delete tasks CREATED by this user (including focusSessions subcollections)
//   4. Batch-delete calendar events created by this user
//   5. Remove FCM token (stops push delivery to this device)
//   6. Remove user from family's `memberIds` array
//   7. Delete the Firestore user profile document
//   8. Delete the Firebase Auth account (CRITICAL — must be last)
//
// ERROR STRATEGY:
//   - Steps 1–7 (data cleanup): failures are collected as `warnings` but do NOT
//     abort the deletion. Orphaned data is preferable to a stuck account.
//   - Step 8 (Firebase Auth delete): failure DOES abort and return an error.
//     If Firebase requires re-authentication, `requiresReauthentication = true`
//     is returned so AuthViewModel can prompt the user to re-verify identity.
//
// BATCH WRITE STRATEGY:
//   Firestore batch writes are used for collections with multiple documents.
//   The batch limit is 500 operations. A safety cap of 450 is used with a
//   recursive retry for overflow (see `batchDeleteUserOwnedData`).
//
// MISSING DATA (known gaps):
//   - Firebase Storage files (avatars, proof images) are NOT deleted.
//     This leaves orphaned files in Storage. A Cloud Function or manual cleanup
//     is required for full data removal.
//   - Reward transactions and withdrawal requests are NOT deleted.
//   - Family deletion if user was the last member is NOT handled here.
//
// ============================================================================

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Result Model

/// Encapsulates the outcome of an account deletion attempt.
///
/// - `success`: `true` if the Firebase Auth account was deleted successfully.
///   Data cleanup failures are reported in `warnings` but don't affect `success`.
/// - `requiresReauthentication`: `true` if Firebase rejected the Auth delete
///   because the session is too old. AuthViewModel should prompt reauth and retry.
/// - `error`: Human-readable error message when `success == false`.
/// - `warnings`: Non-fatal data cleanup failures. Account was deleted but some
///   Firestore data may remain.
struct AccountDeletionResult {
    let success: Bool
    let requiresReauthentication: Bool
    let error: String?
    let warnings: [String]
}

// MARK: - Service

/// Performs complete, ordered account and data deletion for a FamilyHub user.
///
/// Implemented as a Swift `actor` to serialize concurrent deletion attempts.
/// Accessed via the `shared` singleton.
actor AccountDeletionService {

    static let shared = AccountDeletionService()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    // MARK: - Main Deletion Entry Point

    /// Permanently and irreversibly deletes the user's account and all associated data.
    ///
    /// Executes the 10-step deletion sequence. Data cleanup failures (steps 1–7) are
    /// collected as warnings but do not abort the deletion — an account with orphaned
    /// data is better than an account the user can't delete.
    ///
    /// Firebase Auth deletion (step 8) is the only step that can abort with an error:
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
        do {
            try await deleteUserCreatedTasks(userId: userId)
        } catch {
            cleanupWarnings.append("Created tasks: \(error.localizedDescription)")
        }

        // ── Step 4: Delete calendar events created by this user ──
        do {
            try await batchDeleteUserCreatedEvents(userId: userId)
        } catch {
            cleanupWarnings.append("Events: \(error.localizedDescription)")
        }

        // ── Step 5: Remove FCM token (stops push delivery to this device) ──
        // Not wrapped in do/catch — removeFCMToken is already non-throwing.
        await LocalNotificationService.shared.removeFCMToken(userId: userId)

        // ── Step 6: Remove user from family memberIds ──
        if let familyId = familyId {
            do {
                try await removeUserFromFamily(userId: userId, familyId: familyId)
            } catch {
                cleanupWarnings.append("Family removal: \(error.localizedDescription)")
            }
        }

        // ── Step 7: Delete user Firestore profile document ──
        do {
            try await db.collection("users").document(userId).delete()
        } catch {
            cleanupWarnings.append("User doc: \(error.localizedDescription)")
        }

        // ── Step 8: Delete Firebase Auth account (CRITICAL — must be last) ──
        // This is the point of no return. If it succeeds, the account is gone.
        // The auth listener in AuthViewModel handles state teardown automatically.
        do {
            try await user.delete()

            if !cleanupWarnings.isEmpty {
                print("⚠️ Account deleted with cleanup warnings: \(cleanupWarnings)")
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
    /// Uses a single Firestore `WriteBatch` for all three collections, capped at
    /// 450 operations (below the Firestore 500-op limit). If the total document count
    /// exceeds 450, this method commits the current batch and recursively calls itself
    /// for the remaining documents.
    ///
    /// ⚠️ KNOWN BUG: The recursive retry pattern is flawed. After the first batch
    /// is committed, the recursive call re-queries ALL documents (including those
    /// already deleted). On the first recursion, it will attempt to delete already-
    /// deleted documents (no-op) but may stop prematurely if total docs remain > 450.
    /// See improvement suggestions below for a correct chunking pattern.
    ///
    /// - Parameter userId: Firebase UID of the user whose data to delete.
    private func batchDeleteUserOwnedData(userId: String) async throws {
        let batch = db.batch()
        var operationCount = 0
        let maxBatchSize = 450 // Conservative cap below Firestore's 500-op limit

        // Fetch and queue habits for deletion
        let habitsSnapshot = try await db.collection("habits")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in habitsSnapshot.documents {
            batch.deleteDocument(doc.reference)
            operationCount += 1
        }

        // Fetch and queue habit logs for deletion (may be many more than habits)
        let habitLogsSnapshot = try await db.collection("habitLogs")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in habitLogsSnapshot.documents {
            if operationCount >= maxBatchSize {
                // Commit current batch and recurse for remaining documents
                try await batch.commit()
                return try await batchDeleteUserOwnedData(userId: userId)
            }
            batch.deleteDocument(doc.reference)
            operationCount += 1
        }

        // Fetch and queue notifications for deletion
        let notificationsSnapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in notificationsSnapshot.documents {
            if operationCount >= maxBatchSize {
                try await batch.commit()
                return try await batchDeleteUserOwnedData(userId: userId)
            }
            batch.deleteDocument(doc.reference)
            operationCount += 1
        }

        // Commit all queued deletions
        if operationCount > 0 {
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
        let snapshot = try await db.collection("tasks")
            .whereField("assignedTo", isEqualTo: userId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        for doc in snapshot.documents {
            // Remove the assignedTo field entirely rather than setting to null
            batch.updateData(["assignedTo": FieldValue.delete()], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Private: Delete User-Created Tasks

    /// Deletes all tasks created by this user, including their focusSessions subcollections.
    ///
    /// Firestore does not cascade-delete subcollections — they must be deleted explicitly.
    /// This method deletes `focusSessions` child documents before deleting each task document.
    ///
    /// ⚠️ NOTE: The query uses `"createdBy"` but FamilyTask stores `assignedBy` (not `createdBy`).
    /// This query will return zero results unless a `createdBy` field exists.
    /// Verify the Firestore field name matches the FamilyTask.assignedBy key.
    ///
    /// - Parameter userId: Firebase UID of the user whose created tasks to delete.
    private func deleteUserCreatedTasks(userId: String) async throws {
        let snapshot = try await db.collection("tasks")
            .whereField("createdBy", isEqualTo: userId) // ⚠️ Verify field name vs FamilyTask model
            .getDocuments()

        for document in snapshot.documents {
            // Delete subcollection first — Firestore doesn't cascade parent deletes to subcollections
            let sessionsSnapshot = try await document.reference
                .collection("focusSessions")
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
    }

    // MARK: - Private: Delete User-Created Events

    /// Batch-deletes all calendar events created by this user.
    ///
    /// - Parameter userId: Firebase UID of the user whose events to delete.
    private func batchDeleteUserCreatedEvents(userId: String) async throws {
        let snapshot = try await db.collection("events")
            .whereField("createdBy", isEqualTo: userId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
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
        try await db.collection("families").document(familyId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])
    }
}

// MARK: - Improvements & Code Quality Notes
//
// CRITICAL BUG 1 — batchDeleteUserOwnedData recursive retry is incorrect:
//   After committing a batch of 450 docs, the method re-queries ALL documents
//   (the Firestore queries don't filter already-deleted documents until the
//   batch write propagates). This can lead to infinite loops or missed deletions.
//   Fix: Process documents in chunks of 450 within a single query result:
//     let allDocs = [...habits...] + [...logs...] + [...notifications...]
//     for chunk in allDocs.chunked(into: 450) {
//         let batch = db.batch()
//         chunk.forEach { batch.deleteDocument($0.reference) }
//         try await batch.commit()
//     }
//
// CRITICAL BUG 2 — deleteUserCreatedTasks uses "createdBy" not "assignedBy":
//   FamilyTask stores the creator as `assignedBy`. The field "createdBy" likely
//   returns zero results, meaning tasks created by deleted users are never cleaned up.
//   Fix: Change to .whereField("assignedBy", isEqualTo: userId)
//
// SUGGESTION 3 — Multi-assignee unassign not implemented:
//   batchUnassignUserTasks() only clears the v1 `assignedTo` field.
//   It should also use FieldValue.arrayRemove to remove the user from the
//   v2 `assignees` array: batch.updateData(["assignees": FieldValue.arrayRemove([userId])], ...)
//
// SUGGESTION 4 — Firebase Storage files are not deleted:
//   Profile photos (avatarURL) and proof images (proofURLs) in Firebase Storage
//   remain after account deletion. A Cloud Function delete trigger or a
//   Storage cleanup step should be added here.
//
// SUGGESTION 5 — Reward data is not deleted:
//   RewardTransactions and WithdrawalRequests for the deleted user remain in Firestore.
//   Add batchDeleteUserRewardData() to complete data cleanup.
//
// SUGGESTION 6 — Family-last-member case not handled:
//   If the deleted user is the only family member, the family document becomes an
//   orphan in Firestore. Add logic to delete the family document if memberIds is
//   empty after removal.
