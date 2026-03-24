//
//  PriorityBadge.swift
//  
//
//  Task priority badge component
//

import SwiftUI

struct PriorityBadge: View {
    let priority: FamilyTask.TaskPriority
    
    private var color: Color {
        switch priority {
        case .low: return Color.accentGreen
        case .medium: return Color.accentYellow
        case .high: return Color.accentOrange
        case .urgent: return Color.accentRed
        }
    }
    
    private var text: String {
        switch priority {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var body: some View {
        Text(text)
            .font(DS.Typography.badge())
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(RoundedRectangle(cornerRadius: DS.Radius.badge).fill(color.opacity(0.1)))
    }
}

#Preview {
    VStack(spacing: 12) {
        PriorityBadge(priority: .low)
        PriorityBadge(priority: .medium)
        PriorityBadge(priority: .high)
        PriorityBadge(priority: .urgent)
    }
    .padding()
}
