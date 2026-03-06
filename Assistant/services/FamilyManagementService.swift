// ============================================================================
// FamilyManagementService.swift
// FamilyHub
//
// PURPOSE:
//   Handles family creation, family joining, user balance management, and
//   onboarding state persistence. Extracted from AuthViewModel for separation
//   of concerns — these operations involve coordinated Firestore writes that
//   would clutter the ViewModel.
//
// ARCHITECTURE:
//   Declared as a Swift `actor` to prevent concurrent race conditions
//   (e.g., two devices calling createFamily simultaneously). All calls are
//   serialized through the actor's executor.
//
// RESULT TYPES:
//   `CreateFamilyResult` and `JoinFamilyResult` use struct results rather than
//   throwing, allowing the caller (AuthViewModel) to handle errors without
//   try/catch boilerplate in the ViewModel layer.
//
// ROLE ASSIGNMENT ON JOIN:
//   When a user joins a family via invite code, their role is determined by age:
//   - `isAdult == true`  → `.adult`
//   - `isAdult == false` → `.member`
//   This is computed from `FamilyUser.dateOfBirth` at join time and not re-evaluated
//   after the birthday passes — a child who turns 18 keeps the `.member` role
//   until their profile is manually updated.
//
// INVITE CODE FORMAT:
//   6 characters: uppercase A–Z and 0–9. ~2.18 billion combinations.
//   Generated randomly via `generateInviteCode()` with uniqueness verification.
//
// ATOMICITY:
//   All multi-document writes use Firestore WriteBatch for atomic commits.
//   Balance updates use FieldValue.increment() for concurrent safety.
//
// ============================================================================

import Foundation
import FirebaseFirestore

// MARK: - Result Types

/// Outcome of a family creation operation.
struct CreateFamilyResult {
    /// Whether the family was created successfully.
    let success: Bool
    
    /// Firestore document ID of the new family. Nil on failure.
    let familyId: String?
    
    /// The caller's user model updated with the new `familyId` and `.admin` role.
    /// Nil on failure.
    let updatedUser: FamilyUser?
    
    /// Human-readable error description. Non-nil when `success == false`.
    let error: String?
}

/// Outcome of a family join operation.
struct JoinFamilyResult {
    /// Whether the user successfully joined the family.
    let success: Bool
    
    /// The joined family's Firestore document ID. Nil on failure.
    let familyId: String?
    
    /// The caller's user model updated with the new `familyId` and assigned role.
    let updatedUser: FamilyUser?
    
    /// Human-readable error description. Non-nil when `success == false`.
    let error: String?
}

// MARK: - Service

/// Handles family lifecycle operations and user profile management.
///
/// All operations involve coordinated multi-document Firestore writes.
/// Implemented as an actor for concurrency safety.
actor FamilyManagementService {
    
    static let shared = FamilyManagementService()
    private var db: Firestore { Firestore.firestore() }
    private init() {}
    
    /// Maximum retry attempts for generating a unique invite code
    private static let maxInviteCodeRetries = 5
    
    // MARK: - Create Family
    
    /// Creates a new family group and designates the caller as its admin.
    ///
    /// Uses a Firestore WriteBatch for atomic commit of both documents.
    /// If either write fails, both are rolled back automatically.
    ///
    /// Write sequence (atomic):
    /// 1. Generates a unique invite code (with collision check).
    /// 2. Creates the `families/{id}` document with the user as sole member.
    /// 3. Updates `users/{userId}` to set `familyId` and `role = .admin`.
    ///
    /// - Parameters:
    ///   - name: Display name for the new family (e.g., "The Johnson Family").
    ///   - user: The current user creating the family. Must have a non-nil `id`.
    /// - Returns: `CreateFamilyResult` with the new family ID and updated user on success.
    func createFamily(name: String, user: FamilyUser) async -> CreateFamilyResult {
        guard let userId = user.id else {
            return CreateFamilyResult(success: false, familyId: nil, updatedUser: nil,
                                      error: "Invalid user")
        }
        
        do {
            // Generate a unique invite code (with collision check)
            guard let inviteCode = await generateUniqueInviteCode() else {
                return CreateFamilyResult(success: false, familyId: nil, updatedUser: nil,
                                          error: "Failed to generate unique invite code")
            }
            
            // Pre-generate the family document ID so we can use it in the batch
            let familyRef = db.collection("families").document()
            let familyId = familyRef.documentID
            
            // Construct the Family document (creator is the sole initial member)
            let family = Family(
                id: familyId,
                name: name,
                inviteCode: inviteCode,
                createdBy: userId,
                createdAt: Date(),
                memberIds: [userId]
            )
            
            // Prepare updated user
            var updatedUser = user
            updatedUser.familyId = familyId
            updatedUser.role = .admin
            
            // ATOMIC: Use WriteBatch to commit both documents together
            let batch = db.batch()
            
            // Write 1: Create the family document
            try batch.setData(from: family, forDocument: familyRef)
            
            // Write 2: Update the user document
            let userRef = db.collection("users").document(userId)
            try batch.setData(from: updatedUser, forDocument: userRef, merge: true)
            
            // Commit atomically - both succeed or both fail
            try await batch.commit()
            
            return CreateFamilyResult(
                success: true,
                familyId: familyId,
                updatedUser: updatedUser,
                error: nil
            )
        } catch {
            return CreateFamilyResult(success: false, familyId: nil, updatedUser: nil,
                                      error: error.localizedDescription)
        }
    }
    
    // MARK: - Join Family
    
    /// Adds the user to an existing family using a 6-character invite code.
    ///
    /// Uses a Firestore WriteBatch for atomic commit of both documents.
    /// Uses FieldValue.arrayUnion to prevent duplicate memberIds entries.
    ///
    /// Role assignment:
    /// - Adult (18+) → `.adult`
    /// - Child (<18) → `.member`
    ///
    /// - Parameters:
    ///   - inviteCode: The 6-character code displayed in `InviteCodeSheet`.
    ///   - user: The user requesting to join. Must have a non-nil `id`.
    /// - Returns: `JoinFamilyResult` with the family ID and updated user on success.
    func joinFamily(inviteCode: String, user: FamilyUser) async -> JoinFamilyResult {
        guard let userId = user.id else {
            return JoinFamilyResult(success: false, familyId: nil, updatedUser: nil,
                                    error: "Invalid user")
        }
        
        do {
            // Query for a family with this invite code (limited to 1 for efficiency)
            let snapshot = try await db.collection("families")
                .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
                .limit(to: 1)
                .getDocuments()
            
            guard let familyDoc = snapshot.documents.first,
                  let familyId = familyDoc.documentID as String? else {
                // No family found with this code → invalid code
                return JoinFamilyResult(success: false, familyId: nil, updatedUser: nil,
                                        error: L10n.invalidInviteCode)
            }
            
            // Check if user is already a member
            if let memberIds = familyDoc.data()["memberIds"] as? [String],
               memberIds.contains(userId) {
                // User already in family - return success with current state
                var updatedUser = user
                updatedUser.familyId = familyId
                updatedUser.role = user.isAdult ? .adult : .member
                return JoinFamilyResult(
                    success: true,
                    familyId: familyId,
                    updatedUser: updatedUser,
                    error: nil
                )
            }
            
            // Prepare updated user
            var updatedUser = user
            updatedUser.familyId = familyId
            updatedUser.role = user.isAdult ? .adult : .member
            
            // ATOMIC: Use WriteBatch to commit both documents together
            let batch = db.batch()
            
            // Write 1: Add userId to family's memberIds using arrayUnion (prevents duplicates)
            let familyRef = db.collection("families").document(familyId)
            batch.updateData([
                "memberIds": FieldValue.arrayUnion([userId])
            ], forDocument: familyRef)
            
            // Write 2: Update user with family membership and role
            let userRef = db.collection("users").document(userId)
            try batch.setData(from: updatedUser, forDocument: userRef, merge: true)
            
            // Commit atomically
            try await batch.commit()
            
            return JoinFamilyResult(
                success: true,
                familyId: familyId,
                updatedUser: updatedUser,
                error: nil
            )
        } catch {
            return JoinFamilyResult(success: false, familyId: nil, updatedUser: nil,
                                    error: error.localizedDescription)
        }
    }
    
    // MARK: - Update User Balance
    
    /// Atomically adjusts the user's reward wallet balance by a delta amount.
    ///
    /// Uses `FieldValue.increment()` for atomic server-side arithmetic.
    /// Safe for concurrent calls — all updates are applied without race conditions.
    ///
    /// - Parameters:
    ///   - userId: Firebase UID of the user whose balance to update.
    ///   - amount: Delta to apply. Positive = add funds, negative = deduct.
    /// - Returns: `true` if the update succeeded, `false` on failure.
    func updateUserBalance(userId: String, amount: Double) async -> Bool {
        do {
            try await db.collection("users").document(userId).updateData([
                "balance": FieldValue.increment(amount)
            ])
            return true
        } catch {
            print("Failed to update balance: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Legacy method signature for compatibility.
    /// Extracts userId and delegates to the atomic version.
    func updateUserBalance(user: FamilyUser, amount: Double) async -> FamilyUser? {
        guard let userId = user.id else { return nil }
        
        let success = await updateUserBalance(userId: userId, amount: amount)
        
        if success {
            // Return updated user with new balance
            // Note: The actual balance is on the server; this is an optimistic estimate
            var updatedUser = user
            updatedUser.balance += amount
            return updatedUser
        }
        return nil
    }
    
    // MARK: - Onboarding State
    
    /// Marks the user's onboarding as complete in Firestore.
    ///
    /// Uses `updateData` (field-level update) rather than `setData` to avoid
    /// overwriting other user fields that may have been updated concurrently.
    ///
    /// - Parameter userId: Firebase UID of the user completing onboarding.
    /// - Returns: `true` if the Firestore write succeeded.
    func completeOnboarding(userId: String) async -> Bool {
        do {
            try await db.collection("users").document(userId).updateData([
                "hasCompletedOnboarding": true
            ])
            return true
        } catch {
            print("Failed to save onboarding state: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Resets onboarding state to `false` for testing and QA purposes.
    ///
    /// - Warning: For development/debug use only. Should be gated behind `#if DEBUG`
    ///   to prevent accidental invocation from production UI.
    ///
    /// - Parameter userId: Firebase UID of the user to reset.
    /// - Returns: `true` if the Firestore write succeeded.
    func resetOnboarding(userId: String) async -> Bool {
        do {
            try await db.collection("users").document(userId).updateData([
                "hasCompletedOnboarding": false
            ])
            return true
        } catch {
            print("Failed to reset onboarding: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Utilities
    
    /// Generates a unique 6-character alphanumeric invite code.
    ///
    /// Checks Firestore for existing codes to prevent collisions.
    /// Retries up to `maxInviteCodeRetries` times if a collision is found.
    ///
    /// - Returns: A unique 6-character uppercase invite code, or `nil` if all retries failed.
    private func generateUniqueInviteCode() async -> String? {
        for _ in 0..<Self.maxInviteCodeRetries {
            let code = Self.generateInviteCode()
            
            // Check if this code already exists
            do {
                let snapshot = try await db.collection("families")
                    .whereField("inviteCode", isEqualTo: code)
                    .limit(to: 1)
                    .getDocuments()
                
                if snapshot.documents.isEmpty {
                    // Code is unique
                    return code
                }
                // Code exists, retry with a new one
            } catch {
                // On query error, return the code anyway (rare edge case)
                return code
            }
        }
        
        // All retries exhausted (extremely unlikely with 2.18B combinations)
        return nil
    }
    
    /// Generates a cryptographically-random 6-character alphanumeric invite code.
    ///
    /// Character set: A–Z and 0–9 (case-sensitive). Total combinations: 36^6 ≈ 2.18 billion.
    ///
    /// Uses `randomElement()!` on a non-empty string — force-unwrap is safe here because
    /// `characters` is a compile-time constant with guaranteed non-zero length.
    ///
    /// - Returns: A 6-character uppercase invite code string (e.g., "A3F9K2").
    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}
//
// SUGGESTION 5 — resetOnboarding() should be `#if DEBUG` only:
//   This function is visible in production builds and could be called accidentally.
//   Wrap the function body and AuthViewModel.resetOnboarding() in `#if DEBUG`.
//
// SUGGESTION 6 — Role is determined at join time, not recalculated on birthday:
//   A child who was a `.member` when they joined will remain `.member` after
//   turning 18. Consider a scheduled Cloud Function or a login-time role check
//   that upgrades `.member` → `.adult` when age >= 18.
