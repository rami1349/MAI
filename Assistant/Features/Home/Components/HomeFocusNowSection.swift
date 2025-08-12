//
//  HomeFocusNowSection.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//


//  "Focus Now" section: Top 5 highest-priority tasks needing attention.
//  Shows overdue, due today, urgent/high priority tasks.
//  Clean, minimal design focused on action.
//

import SwiftUI

struct HomeFocusNowSection: View {
    let tasks: [FamilyTask]
    let groupLookup: (String) -> TaskGroup?
    let onSelectTask: (FamilyTask) -> Void
    let onCompleteTask: (FamilyTask) async -> Void
    
    @State private var completingTasks: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: Luxury.Spacing.md) {
            // Header
            HStack(spacing: Luxury.Spacing.sm) {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text("Focus Now")
                    .font(Luxury.Typography.subheading())
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, Luxury.Spacing.screenH)
            
            // Task list
            if tasks.isEmpty {
                emptyState
            } else {
                VStack(spacing: Luxury.Spacing.xs) {
                    ForEach(tasks, id: \.stableId) { task in
                        FocusTaskRow(
                            task: task,
                            groupName: task.groupId.flatMap { groupLookup($0)?.name },
                            isCompleting: completingTasks.contains(task.stableId),
                            onTap: { onSelectTask(task) },
                            onComplete: {
                                guard !task.requiresProof else {
                                    onSelectTask(task)
                                    return
                                }
                                completingTasks.insert(task.stableId)
                                Task {
                                    await onCompleteTask(task)
                                    completingTasks.remove(task.stableId)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, Luxury.Spacing.screenH)
            }
        }
    }
    
    private var emptyState: some View {
        HStack(spacing: Luxury.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentGreen.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.accentGreen)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("All caught up!")
                    .font(Luxury.Typography.body())
                    .foregroundColor(.textPrimary)
                
                Text("No urgent tasks right now")
                    .font(Luxury.Typography.caption())
                    .foregroundColor(.textTertiary)
            }
            
            Spacer()
        }
        .padding(Luxury.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Luxury.Radius.md)
                .fill(Color.themeCardBackground)
        )
        .padding(.horizontal, Luxury.Spacing.screenH)
    }
}

// MARK: - Focus Task Row

struct FocusTaskRow: View {
    let task: FamilyTask
    let groupName: String?
    let isCompleting: Bool
    let onTap: () -> Void
    let onComplete: () -> Void
    
    private var priorityColor: Color {
        switch task.priority {
        case .urgent: return .accentRed
        case .high: return .accentOrange
        case .medium: return .accentPrimary
        case .low: return .textTertiary
        }
    }
    
    private var dueBadgeText: String {
        if task.isOverdue {
            return "Overdue"
        } else if Calendar.current.isDateInToday(task.dueDate) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(task.dueDate) {
            return "Tomorrow"
        } else {
            return task.dueDate.formatted(.dateTime.weekday(.abbreviated))
        }
    }
    
    private var dueBadgeColor: Color {
        if task.isOverdue { return .accentRed }
        if Calendar.current.isDateInToday(task.dueDate) { return .accentOrange }
        return .textSecondary
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Luxury.Spacing.md) {
                // Complete button
                Button(action: onComplete) {
                    ZStack {
                        Circle()
                            .stroke(priorityColor, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isCompleting {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isCompleting)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Luxury.Typography.label())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: Luxury.Spacing.sm) {
                        // Due badge
                        Text(dueBadgeText)
                            .font(Luxury.Typography.micro())
                            .foregroundColor(dueBadgeColor)
                        
                        // Group name
                        if let groupName = groupName {
                            Text("•")
                                .font(Luxury.Typography.micro())
                                .foregroundColor(.textTertiary)
                            Text(groupName)
                                .font(Luxury.Typography.micro())
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                        }
                        
                        // Scheduled time
                        if let time = task.scheduledTime {
                            Text("•")
                                .font(Luxury.Typography.micro())
                                .foregroundColor(.textTertiary)
                            Text(time.formatted(.dateTime.hour().minute()))
                                .font(Luxury.Typography.micro())
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Priority indicator
                if task.priority == .urgent || task.priority == .high {
                    Image(systemName: task.priority == .urgent ? "exclamationmark.2" : "exclamationmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(priorityColor)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .padding(Luxury.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Luxury.Radius.md)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Luxury.Radius.md)
                    .stroke(task.isOverdue ? Color.accentRed.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            HomeFocusNowSection(
                tasks: [],
                groupLookup: { _ in nil },
                onSelectTask: { _ in },
                onCompleteTask: { _ in }
            )
        }
        .padding(.vertical)
    }
    .background(Color.themeSurfacePrimary)
}