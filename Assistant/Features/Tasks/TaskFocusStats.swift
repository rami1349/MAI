//
//  TaskFocusStats.swift
//  Assistant
//
//  Created by Ramiro  on 1/25/26.
//
//  Extension to FamilyViewModel for focus session handling
//

import Foundation
import FirebaseFirestore

// MARK: - Focus Session Operations
extension FamilyViewModel {
    
    /// Save a completed focus session for a task
    func saveFocusSession(_ session: FocusSession, for task: FamilyTask) async {
        guard let taskId = task.id else { return }
        
        let db = Firestore.firestore()
        
        do {
            // 1. Save session to focusSessions subcollection
            let sessionData: [String: Any] = [
                "id": session.id,
                "taskId": session.taskId,
                "startedAt": Timestamp(date: session.startedAt),
                "endedAt": session.endedAt.map { Timestamp(date: $0) } ?? NSNull(),
                "plannedDurationSeconds": session.plannedDurationSeconds,
                "actualDurationSeconds": session.actualDurationSeconds,
                "wasCompleted": session.wasCompleted,
                "wasInterrupted": session.wasInterrupted
            ]
            
            try await db.collection("tasks")
                .document(taskId)
                .collection("focusSessions")
                .document(session.id)
                .setData(sessionData)
            
            // 2. Update task's total focused time
            try await db.collection("tasks")
                .document(taskId)
                .updateData([
                    "totalFocusedSeconds": FieldValue.increment(Int64(session.actualDurationSeconds)),
                    "lastFocusDate": Timestamp(date: Date())
                ])
            
        } catch {
            errorMessage = String(localized: "error_save_focus_session")
        }
    }
}
