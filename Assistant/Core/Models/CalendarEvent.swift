//
//  CalendarEvent.swift
//  FamilyHub
//
//  Calendar event model
//

import Foundation
import FirebaseFirestore

struct CalendarEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var familyId: String
    var title: String
    var description: String?
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var color: String
    var createdBy: String
    var participants: [String]
    var linkedTaskId: String?
    var eventType: String?
    var createdAt: Date
}
