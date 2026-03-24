//
//  TaskType.swift
//  Assistant
//
//  Created by Ramiro  on 2/26/26.
//


//
//  TaskType.swift
//  
//
//  Task categorization for different verification flows
//  - Chore: Manual parent approval
//  - Homework: AI verification (for supported subjects)
//

import Foundation

// MARK: - Task Type

enum TaskType: String, Codable, CaseIterable {
    case chore = "chore"
    case homework = "homework"
    
    var displayName: String {
        switch self {
        case .chore: return "task_type_chore"
        case .homework: return "task_type_homework"
        }
    }
    
    var icon: String {
        switch self {
        case .chore: return "sparkles"
        case .homework: return "book.fill"
        }
    }
}

// MARK: - Homework Subject

enum HomeworkSubject: String, Codable, CaseIterable {
    case math = "math"
    case language = "language"
    case reading = "reading"
    case science = "science"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .math: return "subject_math"
        case .language: return "subject_language"
        case .reading: return "subject_reading"
        case .science: return "subject_science"
        case .other: return "subject_other"
        }
    }
    
    /// Whether AI can objectively verify answers for this subject
    var isAIVerifiable: Bool {
        switch self {
        case .math, .language, .science: return true
        case .reading, .other: return false
        }
    }
}

// MARK: - Proof Type

enum ProofType: String, Codable, CaseIterable {
    case photo = "photo"
    case video = "video"
    
    var displayName: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video"
        }
    }
    
    var icon: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video"
        }
    }
}
