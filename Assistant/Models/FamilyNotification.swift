//  FamilyNotification.swift
//
//  Notification model
//

import Foundation
import FirebaseFirestore

struct FamilyNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var familyId: String
    var type: NotificationType
    var title: String
    var message: String
    var relatedTaskId: String?
    var relatedEventId: String? = nil
    var isRead: Bool
    var createdAt: Date
    
    enum NotificationType: String, Codable {
        case taskAssigned
        case taskCompleted
        case taskDeleted
        case proofSubmitted
        case proofVerified
        case rewardReceived
        case reminder
        case familyInvite
        case memberJoined
        case eventCreated
        case eventUpdated
        case eventCanceled
        case taskOverdue
        case dailySummary
    }
}
