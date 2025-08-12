//
//  FocusSession.swift
//  Assistant
//
//  Created by Ramiro  on 1/25/26.
//


//
//  FocusSession.swift
//  FamilyHub
//
//  Focus session model for Pomodoro tracking
//

import Foundation
import FirebaseFirestore

// MARK: - Focus Session Model
struct FocusSession: Identifiable, Codable, Hashable {
    var id: String
    var taskId: String
    var startedAt: Date
    var endedAt: Date?
    var plannedDurationSeconds: Int
    var actualDurationSeconds: Int
    var wasCompleted: Bool  // Did timer reach 0?
    var wasInterrupted: Bool
    
    init(
        id: String = UUID().uuidString,
        taskId: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        plannedDurationSeconds: Int,
        actualDurationSeconds: Int = 0,
        wasCompleted: Bool = false,
        wasInterrupted: Bool = false
    ) {
        self.id = id
        self.taskId = taskId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.actualDurationSeconds = actualDurationSeconds
        self.wasCompleted = wasCompleted
        self.wasInterrupted = wasInterrupted
    }
    
    var plannedDurationMinutes: Int {
        plannedDurationSeconds / 60
    }
    
    var actualDurationMinutes: Int {
        actualDurationSeconds / 60
    }
    
    var formattedDuration: String {
        let minutes = actualDurationSeconds / 60
        let seconds = actualDurationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Task Focus Extension
struct TaskFocusData: Codable, Hashable {
    var pomodoroDurationMinutes: Int
    var totalFocusedSeconds: Int
    var focusSessionHistory: [FocusSession]
    var lastFocusDate: Date?
    
    init(
        pomodoroDurationMinutes: Int = 25,
        totalFocusedSeconds: Int = 0,
        focusSessionHistory: [FocusSession] = [],
        lastFocusDate: Date? = nil
    ) {
        self.pomodoroDurationMinutes = pomodoroDurationMinutes
        self.totalFocusedSeconds = totalFocusedSeconds
        self.focusSessionHistory = focusSessionHistory
        self.lastFocusDate = lastFocusDate
    }
    
    var totalFocusedMinutes: Int {
        totalFocusedSeconds / 60
    }
    
    var totalFocusedHours: Double {
        Double(totalFocusedSeconds) / 3600.0
    }
    
    var formattedTotalTime: String {
        let hours = totalFocusedSeconds / 3600
        let minutes = (totalFocusedSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var completedSessionsCount: Int {
        focusSessionHistory.filter { $0.wasCompleted }.count
    }
    
    mutating func addSession(_ session: FocusSession) {
        focusSessionHistory.append(session)
        totalFocusedSeconds += session.actualDurationSeconds
        lastFocusDate = session.endedAt ?? Date()
    }
}

// MARK: - Focus Timer State
enum FocusTimerState: String, Codable {
    case idle
    case running
    case paused
    case completed
    case breakTime
}

// MARK: - Break Type
enum BreakType: String, CaseIterable {
    case short = "Short Break"
    case long = "Long Break"
    
    var durationMinutes: Int {
        switch self {
        case .short: return 5
        case .long: return 15
        }
    }
    
    var icon: String {
        switch self {
        case .short: return "cup.and.saucer.fill"
        case .long: return "figure.walk"
        }
    }
}