//
//  TaskType.swift
//  Assistant
//
//  Created by Ramiro  on 2/26/26.
//


//
//  TaskType.swift
//  FamilyHub
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
        case .chore: return L10n.taskTypeChore
        case .homework: return L10n.taskTypeHomework
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
        case .math: return L10n.subjectMath
        case .language: return L10n.subjectLanguage
        case .reading: return L10n.subjectReading
        case .science: return L10n.subjectScience
        case .other: return L10n.subjectOther
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
        case .photo: return L10n.photoLabel
        case .video: return L10n.videoLabel
        }
    }
    
    var icon: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video"
        }
    }
}