// ============================================================================
// FirestoreDecode.swift
// 
//
// PURPOSE:
//   Performance utility for decoding Firestore query results off the main thread.
//
// PROBLEM SOLVED:
//   Firestore's `.compactMap { try? $0.data(as: T.self) }` uses Swift's `Codable`
//   infrastructure to decode each document. For large query results (e.g., 200 tasks
//   or 50 notifications), this can take 5–20ms of CPU time — enough to cause
//   a perceptible UI hiccup if run on the main thread.
//
// SOLUTION:
//   `Task.detached(priority: .userInitiated)` creates a Swift concurrency task
//   that runs on a background thread pool (not the main actor). The decoded array
//   is then awaited back on the calling context (the caller is responsible for
//   dispatching to @MainActor before publishing to @Observable properties).
//
// USAGE PATTERN (from TaskViewModel):
//   Task {
//       let tasks = await FirestoreDecode.documents(documents, as: FamilyTask.self)
//       await MainActor.run { self.setTasks(tasks) }
//   }
//
//  Shared helper for off-main-thread Firestore decoding.
//  Moves heavy compactMap/decode work to background to keep UI responsive.
//
//  FIX: Manually injects document IDs because custom init(from decoder:)
//  in models breaks @DocumentID property wrapper injection.
//

import Foundation
import FirebaseFirestore
import os

enum FirestoreDecode {
    
    /// Decodes an array of Firestore documents on a background thread
    /// and manually injects document IDs
    static func documents<T: Decodable & Sendable>(
        _ documents: [QueryDocumentSnapshot],
        as type: T.Type
    ) async -> [T] {
        guard !documents.isEmpty else { return [] }
        
        return await Task.detached(priority: .userInitiated) { @Sendable in
            documents.compactMap { doc -> T? in
                let decoded = try? doc.data(as: T.self)
                return injectID(decoded, documentID: doc.documentID)
            }
        }.value
    }
    
    /// Decodes a single Firestore document on a background thread
    /// and manually injects document ID
    static func document<T: Decodable & Sendable>(
        _ document: DocumentSnapshot,
        as type: T.Type
    ) async -> T? {
        return await Task.detached(priority: .userInitiated) { @Sendable in
            injectID(try? document.data(as: T.self), documentID: document.documentID)
        }.value
    }
    
    /// Injects document ID into decoded model
    /// Required because custom decoders break @DocumentID
    private static func injectID<T>(_ result: T?, documentID: String) -> T? {
        guard let decoded = result else { return nil }
        
        // Type-specific ID injection
        switch decoded {
        case var task as FamilyTask:
            Log.data.debug("Injecting ID '\(documentID, privacy: .private)' into task '\(task.title, privacy: .private)'")
            task.id = documentID
            return task as? T
        case var group as TaskGroup:
            group.id = documentID
            return group as? T
        case var habit as Habit:
            habit.id = documentID
            return habit as? T
        case var event as CalendarEvent:
            event.id = documentID
            return event as? T
        case var user as FamilyUser:
            user.id = documentID
            return user as? T
        case var notification as FamilyNotification:
            notification.id = documentID
            return notification as? T
        case var family as Family:
            family.id = documentID
            return family as? T
        default:
            return decoded
        }
    }
}
// MARK: - Improvements & Code Quality Notes
//
// SUGGESTION 1 — Silent decode failures are unobservable:
//   `try?` swallows all decode errors. In development builds, consider logging
//   failures to track schema mismatches:
//     #if DEBUG
//     do { return try doc.data(as: T.self) }
//     catch { print("Decode failed for \(doc.documentID): \(error)"); return nil }
//     #else
//     return try? doc.data(as: T.self)
//     #endif
//
// SUGGESTION 2 — No progress reporting:
//   For very large document arrays (approaching the 200-document limit),
//   there is no way for the caller to observe partial progress.
//   An AsyncStream variant could enable progressive loading.
//
// SUGGESTION 3 — documents() could be made generic over any Sequence:
//   The `[QueryDocumentSnapshot]` constraint ties this to Firestore's API.
//   A more generic signature would be easier to unit test:
//   `static func decode<T: Decodable>(_ data: [Data]) async -> [T]`
