// ============================================================================
// HomeOtherTasksSection.swift
//
// SLOT 7: Other Tasks
//
// Shows active tasks that didn't make the Focus Now top 5.
// Compact rows, "Show more" pagination, sorted by due date.
//
// ============================================================================

import SwiftUI

struct HomeOtherTasksSection: View {
    let tasks: [FamilyTask]
    let groups: [TaskGroup]
    let onSelectTask: (FamilyTask) -> Void
    let onMoveTask: (FamilyTask, String?) async -> Void
    
    @State private var showAll = false
    
    private let previewCount = 4
    
    private var visibleTasks: [FamilyTask] {
        showAll ? tasks : Array(tasks.prefix(previewCount))
    }
    
    @ViewBuilder
    var body: some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "tray")
                        .font(DS.Typography.label())
                        .foregroundStyle(.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.textSecondary.opacity(0.1))
                        )
                    
                    Text("upcoming_tasks")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                    
                    Text("\(tasks.count)")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.textSecondary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.textSecondary.opacity(0.1))
                        )
                    
                    Spacer()
                }
                
                // Task rows
                VStack(spacing: 0) {
                    ForEach(visibleTasks, id: \.stableId) { task in
                        CompactTaskRow(task: task, onTap: { onSelectTask(task) })
                            .draggable(task)
                            .contextMenu {
                                Button {
                                    onSelectTask(task)
                                } label: {
                                    Label("view_details", systemImage: "eye")
                                }
                                
                                if !groups.isEmpty {
                                    MoveToFolderMenu(
                                        task: task,
                                        groups: groups,
                                        onMove: onMoveTask
                                    )
                                }
                            }
                        
                        if task.stableId != visibleTasks.last?.stableId {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(Color.themeCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.themeCardBorder, lineWidth: 0.5)
                )
                
                // Show more/less
                if tasks.count > previewCount {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
                    }) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(showAll ? "show_less" : "show_more")
                                .font(DS.Typography.caption())
                            Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                .font(DS.Typography.micro())
                        }
                        .foregroundStyle(.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Compact Task Row

private struct CompactTaskRow: View {
    let task: FamilyTask
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(task.priority.color)
                    .frame(width: 8, height: 8)
                    .padding(.leading, DS.Spacing.md)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    
                    Text(relativeDate)
                        .font(DS.Typography.micro())
                        .foregroundStyle(dateColor)
                }
                
                Spacer()
                
                if task.hasReward, let amount = task.rewardAmount {
                    Text(amount.currencyString)
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.accentGreen)
                }
                
                Image(systemName: "chevron.right")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
                    .padding(.trailing, DS.Spacing.md)
            }
            .padding(.vertical, DS.Spacing.sm)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - ADHD: Relative time instead of absolute
    
    private var relativeDate: String {
        let calendar = Calendar.current
        let now = Date.now
        
        if task.isOverdue {
            let days = calendar.dateComponents([.day], from: task.dueDate, to: now).day ?? 0
            if days == 0 { return AppStrings.localized("overdue") }
            return "\(days)d " + AppStrings.localized("overdue")
        }
        
        if calendar.isDateInToday(task.dueDate) {
            if let time = task.scheduledTime {
                let hours = calendar.dateComponents([.hour], from: now, to: time).hour ?? 0
                if hours > 0 {
                    return String(format: AppStrings.localized("due_in_hours"), hours)
                }
            }
            return AppStrings.localized("today")
        }
        
        if calendar.isDateInTomorrow(task.dueDate) {
            return AppStrings.localized("tomorrow")
        }
        
        let days = calendar.dateComponents([.day], from: now, to: task.dueDate).day ?? 0
        if days <= 7 {
            return task.dueDate.formatted(.dateTime.weekday(.abbreviated))
        }
        return task.dueDate.formatted(.dateTime.month(.abbreviated).day())
    }
    
    private var dateColor: Color {
        if task.isOverdue { return .accentRed }
        if Calendar.current.isDateInToday(task.dueDate) { return .accentOrange }
        return .textTertiary
    }
}
