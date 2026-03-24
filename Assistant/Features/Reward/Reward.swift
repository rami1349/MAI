// ============================================================================
// Reward.swift
// 
//
// PURPOSE:
//   Models the reward ledger (RewardTransaction) and withdrawal workflow
//   (WithdrawalRequest) for the family reward wallet system.
//
// DESIGN:
//   - Immutable ledger: every balance change is recorded as a RewardTransaction.
//   - Children request withdrawals; parents approve or reject.
//   - The `amount` field on RewardTransaction is signed:
//       positive = earned reward
//       negative = approved withdrawal
//
// FIRESTORE COLLECTIONS:
//   `rewardTransactions/{id}` — Ledger entries (family-scoped).
//   `withdrawalRequests/{id}` — Pending/reviewed withdrawal requests (family-scoped).
//
// ============================================================================

import Foundation
import FirebaseFirestore

// MARK: - Reward Transaction (Ledger Entry)

/// Every balance change is recorded as a RewardTransaction.
/// This forms the immutable ledger / history.
struct RewardTransaction: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var familyId: String
    var userId: String           // Who received / lost the reward
    var amount: Double           // Positive = earned, negative = withdrawn
    var type: TransactionType
    var status: TransactionStatus
    var description: String      // e.g. "Cleaning room", "Homework"
    var taskId: String?          // Link to originating task (if any)
    var createdBy: String        // Who created this transaction (parent who assigned)
    var createdByName: String    // Display name of creator
    var recipientName: String    // Display name of recipient
    var createdAt: Date
    var reviewedBy: String?      // Who approved/rejected (for withdrawals)
    var reviewedAt: Date?
    
    enum TransactionType: String, Codable, CaseIterable {
        case taskReward = "taskReward"       // Earned from completing a task
        case manualReward = "manualReward"   // Parent manually gave reward
        case withdrawal = "withdrawal"       // Child withdrew funds
    }
    
    enum TransactionStatus: String, Codable, CaseIterable {
        case completed = "completed"   // Earned rewards are immediately completed
        case pending = "pending"       // Withdrawal pending parent approval
        case approved = "approved"     // Withdrawal approved
        case rejected = "rejected"     // Withdrawal rejected
    }
    
    enum CodingKeys: String, CodingKey {
        case id, familyId, userId, amount, type, status, description
        case taskId, createdBy, createdByName, recipientName, createdAt, reviewedBy, reviewedAt
    }
}

// MARK: - Withdrawal Request

/// A child's request to withdraw funds from their reward balance.
/// Parents see pending requests and can approve/reject.
struct WithdrawalRequest: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var familyId: String
    var userId: String           // Child requesting withdrawal
    var userName: String         // Child's display name
    var amount: Double
    var note: String?            // Optional note from child
    var status: RequestStatus
    var createdAt: Date
    var reviewedBy: String?
    var reviewedByName: String?
    var reviewedAt: Date?
    var rejectionReason: String?
    
    enum RequestStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case approved = "approved"
        case rejected = "rejected"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, familyId, userId, userName, amount, note
        case status, createdAt, reviewedBy, reviewedByName, reviewedAt, rejectionReason
    }
}
