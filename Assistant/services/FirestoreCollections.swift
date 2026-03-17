//
//  FirestoreCollections.swift
//  Assistant
//
//  Centralized Firestore collection name constants.
//  Eliminates magic strings and prevents typos across the codebase.
//

import Foundation

// MARK: - Collection Names

/// Firestore collection name constants to eliminate magic strings.
///
/// Usage:
/// ```swift
/// db.collection(FirestoreCollections.users).document(userId)
/// db.collection(FirestoreCollections.tasks).whereField(...)
/// ```
enum FirestoreCollections {
    static let users = "users"
    static let families = "families"
    static let tasks = "tasks"
    static let events = "events"
    static let habits = "habits"
    static let habitLogs = "habitLogs"
    static let notifications = "notifications"
    static let taskGroups = "taskGroups"
    static let rewards = "rewards"
    static let transactions = "transactions"
    static let withdrawals = "withdrawals"
    static let chatHistory = "chatHistory"
    static let aiUsage = "aiUsage"
    static let verifications = "verifications"
    static let conversationSummaries = "conversationSummaries"
    
    // Subcollections
    static let focusSessions = "focusSessions"
}

// MARK: - Firestore Field Names

/// Common Firestore field name constants.
enum FirestoreFields {
    static let familyId = "familyId"
    static let userId = "userId"
    static let assignedTo = "assignedTo"
    static let assignedBy = "assignedBy"
    static let createdBy = "createdBy"
    static let createdAt = "createdAt"
    static let updatedAt = "updatedAt"
    static let status = "status"
    static let dueDate = "dueDate"
    static let memberIds = "memberIds"
    static let balance = "balance"
    static let inviteCode = "inviteCode"
}

// MARK: - Array Chunking Extension

extension Array {
    /// Splits the array into chunks of the specified size.
    ///
    /// - Parameter size: Maximum number of elements per chunk.
    /// - Returns: Array of arrays, each containing up to `size` elements.
    ///
    /// Example:
    /// ```swift
    /// [1, 2, 3, 4, 5].chunked(into: 2)
    /// // Returns: [[1, 2], [3, 4], [5]]
    /// ```
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
