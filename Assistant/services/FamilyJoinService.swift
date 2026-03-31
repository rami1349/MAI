//
//  FamilyJoinService.swift
//  Assistant
//
//  Created by Ramiro  on 2/11/26.
//

import Foundation
import FirebaseFirestore

struct FamilyJoinService {
    
    // MARK: - Shared Instance
    
    static let shared = FamilyJoinService()
    
    private var db: Firestore { Firestore.firestore() }
    
    // MARK: - Create Family
    
    @discardableResult
    func createFamily(name: String, userId: String) async throws -> String {
        let inviteCode = Self.generateInviteCode()
        
        let family = Family(
            id: nil,
            name: name,
            inviteCode: inviteCode,
            createdBy: userId,
            createdAt: Date(),
            memberIds: [userId]
        )
        
        let familyRef = try db.collection("families").addDocument(from: family)
        let familyId = familyRef.documentID
        
        // Mark the creator as admin of this family
        try await db.collection("users").document(userId).updateData([
            "familyId": familyId,
            "role": FamilyUser.UserRole.admin.rawValue
        ])
        
        return familyId
    }
    
    // MARK: - Join Family
    
    @discardableResult
    func joinFamily(inviteCode: String, userId: String, isAdult: Bool) async throws -> String {
        let snapshot = try await db.collection("families")
            .whereField("invite_code", isEqualTo: inviteCode)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first,
              var family = try? document.data(as: Family.self),
              let familyId = family.id else {
            throw FamilyJoinError.invalidInviteCode
        }
        
        // Add user to the family's member list
        family.memberIds.append(userId)
        try db.collection("families").document(familyId).setData(from: family, merge: true)
        
        // Set user's family + role
        let role: FamilyUser.UserRole = isAdult ? .adult : .member
        try await db.collection("users").document(userId).updateData([
            "familyId": familyId,
            "role": role.rawValue
        ])
        
        return familyId
    }
    
    // MARK: - Onboarding
    
    func completeOnboarding(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "has_completed_onboarding": true
        ])
    }
    
    /// Resets onboarding state (useful for testing / debug builds).
    func resetOnboarding(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "hasCompletedOnboarding": false
        ])
    }
    
    // MARK: - Private Helpers
    
    /// Generates a random 6-character alphanumeric invite code.
    private static func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Errors

enum FamilyJoinError: LocalizedError {
    case invalidInviteCode
    
    var errorDescription: String? {
        switch self {
        case .invalidInviteCode:
            return "invalid_invite_code"
        }
    }
}
