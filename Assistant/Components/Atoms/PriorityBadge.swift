//
//  PriorityBadge.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//  Task priority badge component
//

import SwiftUI

struct PriorityBadge: View {
    let priority: FamilyTask.TaskPriority
    
    private var color: Color {
        switch priority {
        case .low: return .accentGreen
        case .medium: return .accentYellow
        case .high: return .accentOrange
        case .urgent: return .accentRed
        }
    }
    
    private var text: String {
        switch priority {
        case .low: return L10n.low
        case .medium: return L10n.medium
        case .high: return L10n.high
        case .urgent: return L10n.urgent
        }
    }
    
    var body: some View {
        Text(text)
            .font(DS.Typography.badge())
            .foregroundColor(color)
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
