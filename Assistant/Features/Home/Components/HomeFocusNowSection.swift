//
//  HomeFocusNowSection.swift
//  FamilyHub
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "target")
                    .font(DS.Typography.label())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text("10n.focusNow")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.screenH)
            
            // Task list
            if tasks.isEmpty {
                emptyState
            } else {
                VStack(spacing: DS.Spacing.xs) {
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
                .padding(.horizontal, DS.Spacing.screenH)
            }
        }
    }
    
    private var emptyState: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentGreen.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark.circle")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.accentGreen)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("L10n.allCaughtUp")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
                
                Text("L10n.noUrgentTasksRightNow")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
            }
            
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .padding(.horizontal, DS.Spacing.screenH)
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
        case .urgent: return Color.accentRed
        case .high: return Color.accentOrange
        case .medium: return Color.accentPrimary
        case .low: return Color.textTertiary
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
        if task.isOverdue { return Color.accentRed }
        if Calendar.current.isDateInToday(task.dueDate) { return Color.accentOrange }
        return Color.textSecondary
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
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
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: DS.Spacing.sm) {
                        // Due badge
                        Text(dueBadgeText)
                            .font(DS.Typography.micro())
                            .foregroundStyle(dueBadgeColor)
                        
                        // Group name
                        if let groupName = groupName {
                            Text("•")
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textTertiary)
                            Text(groupName)
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textTertiary)
                                .lineLimit(1)
                        }
                        
                        // Scheduled time
                        if let time = task.scheduledTime {
                            Text("•")
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textTertiary)
                            Text(time.formatted(.dateTime.hour().minute()))
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Priority indicator
                if task.priority == .urgent || task.priority == .high {
                    Image(systemName: task.priority == .urgent ? "exclamationmark.2" : "exclamationmark")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(priorityColor)
                }
                
                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
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
