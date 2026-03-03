//
//  MemberDetailView.swift
//  Assistant
//
//  Created by Ramiro  on 2/9/26.
//  Detail sheet for a family member showing profile, stats, activity heatmap, and recent tasks
//

import SwiftUI

// MARK: - Member Detail View
struct MemberDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(TaskViewModel.self) var taskVM
    @Environment(HabitViewModel.self) var habitVM
    let member: FamilyUser
    
    @State private var heatmapMonth: Date = Date()
    
    /// All tasks belonging to this member (for stats / heatmap).
    private var allMemberTasks: [FamilyTask] {
        taskVM.allTasks.filter { task in
            task.assignedTo == member.id || (task.assignedTo == nil && task.assignedBy == member.id)
        }
    }
    
    /// Active tasks only — hides completed (for the task list).
    private var activeMemberTasks: [FamilyTask] {
        allMemberTasks.filter { $0.status != .completed }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    private var completedCount: Int {
        allMemberTasks.filter { $0.status == .completed }.count
    }
    
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    private var memberHabitLogs: [String: Set<String>] {
        habitVM.habitLogs
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xl) {
                    profileHeader
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text("Stats")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.textSecondary)
                        }
                        statsCard
                    }
                    
                    if let goal = member.goal, !goal.isEmpty {
                        goalSection(goal: goal)
                    }
                    
                    MonthlyActivityHeatmap(
                        tasks: allMemberTasks,
                        habitLogs: memberHabitLogs,
                        displayMonth: $heatmapMonth,
                        onMonthChange: nil
                    )
                    
                    if !activeMemberTasks.isEmpty {
                        recentTasksSection
                    }
                    
                    Spacer().frame(height: DS.Control.large)
                }
                .padding(DS.Layout.adaptiveScreenPadding)
                .constrainedWidth(.card)
            }
            .background(AdaptiveBackgroundView())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var profileHeader: some View {
        HStack(spacing: DS.Spacing.lg) {
            AvatarView(user: member, size: DS.Avatar.lg + 14)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(member.displayName)
                    .font(.headline)
                
                HStack(spacing: DS.Spacing.sm) {
                    RoleBadge(role: member.role)
                    if member.isAdult {
                        Text("Adult")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                Text("Balance")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                Text(member.balance.currencyString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentGreen)
            }
        }
        .padding(DS.Spacing.xl)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xxl).fill(Color.themeCardBackground))
        .elevation1()
    }
    
    private var statsCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: DS.Spacing.xs) {
                Text("\(activeMemberTasks.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Active")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: DS.Spacing.jumbo)
            
            VStack(spacing: DS.Spacing.xs) {
                Text("\(completedCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentGreen)
                Text("Completed")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: DS.Spacing.jumbo)
            
            VStack(spacing: DS.Spacing.xs) {
                let total = allMemberTasks.count
                let rate = total == 0 ? 0 : Int((Double(completedCount) / Double(total)) * 100)
                Text("\(rate)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentPrimary)
                Text("Rate")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DS.Spacing.xl)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.themeCardBackground))
        .elevation1()
    }
    
    private func goalSection(goal: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Goal for \(currentYear)")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                Text(goal)
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.accentPrimary.opacity(0.05)))
    }
    
    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(Color.accentPrimary)
                Text("Active Tasks")
                    .font(.headline)
            }
            
            ForEach(activeMemberTasks.prefix(5), id: \.id) { task in
                MemberTaskRow(task: task)
            }
        }
        .padding(DS.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.themeCardBackground))
        .elevation1()
    }
}

// MARK: - Member Task Row
struct MemberTaskRow: View {
    let task: FamilyTask
    
    private var statusColor: Color {
        switch task.status {
        case .todo: return .statusTodo
        case .inProgress: return Color.statusInProgress
        case .pendingVerification: return Color.statusPending
        case .completed: return .statusCompleted
        }
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(statusColor)
                .frame(width: DS.IconSize.xs - 2, height: DS.IconSize.xs - 2)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                
                Text(task.dueDate.formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Text(task.status.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(Capsule().fill(statusColor.opacity(0.15)))
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
