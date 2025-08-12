//
//  PriorityChip.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//


//  Shared selectable chip components for task creation and editing.
//  Place in: Components/Chips/TaskChips.swift
//

import SwiftUI

// MARK: - Priority Chip

struct PriorityChip: View {
    let priority: FamilyTask.TaskPriority
    let isSelected: Bool
    let action: () -> Void
    
    var color: Color {
        switch priority {
        case .low: return .accentGreen
        case .medium: return .accentYellow
        case .high: return .accentOrange
        case .urgent: return .accentRed
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(priority.rawValue)
                .font(DS.Typography.badge())
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(isSelected ? color : color.opacity(0.15)))
        }
    }
}

// MARK: - Recurrence Frequency Chip

struct RecurrenceFrequencyChip: View {
    let frequency: FamilyTask.RecurrenceRule.Frequency
    let isSelected: Bool
    let action: () -> Void
    
    var label: String {
        switch frequency {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Typography.badge())
                .foregroundColor(isSelected ? .white : .accentBlue)
                .padding(.horizontal, DS.Spacing.md + 2)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(isSelected ? Color.accentBlue : Color.accentBlue.opacity(0.15)))
        }
    }
}

// MARK: - Day of Week Chip

struct DayOfWeekChip: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    var label: String {
        ["", "S", "M", "T", "W", "T", "F", "S"][day]
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .textSecondary)
                .frame(width: DS.IconContainer.md, height: DS.IconContainer.md)
                .background(Circle().fill(isSelected ? Color.accentPrimary : Color.backgroundSecondary))
        }
    }
}