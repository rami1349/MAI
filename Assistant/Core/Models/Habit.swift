//
//  Habit.swift
//  FamilyHub
//
//  Habit tracking models
//

import Foundation
import FirebaseFirestore

struct Habit: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var familyId: String
    var userId: String
    var name: String
    var icon: String
    var colorHex: String
    var createdAt: Date
    var isActive: Bool
    
    // Not stored in Firestore - populated locally
    var completedDates: Set<String> = []
    
    enum CodingKeys: String, CodingKey {
        case id, familyId, userId, name, icon, colorHex, createdAt, isActive
    }
}

// MARK: - Habit Log Model
struct HabitLog: Identifiable, Codable {
    @DocumentID var id: String?
    var habitId: String
    var userId: String
    var date: String // Format: "yyyy-MM-dd"
    var completedAt: Date
}
