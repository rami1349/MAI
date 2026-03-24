//
//  TaskCard.swift
//  
//
//  Reusable task card component with inline actions
//  UPDATED: Priority left border visualization (4px)
//  UPDATED: Removed status badge - border color implies urgency
//  UPDATED: Uses implicit priority (displayPriority) from due date + reward
//

import SwiftUI

struct TaskCard: View {
    let task: FamilyTask
    let groupName: String?
    var onTap: (() -> Void)?
    var onStartTask: (() -> Void)?
    var onStartFocus: (() -> Void)?
    var onMarkComplete: (() -> Void)?
    var showActions: Bool = false
    var isLoading: Bool = false
    
    /// Priority border color based on implicit priority (due date + reward)
    private var priorityBorderColor: Color {
        switch task.displayPriority {
        case .urgent: return Color.statusError      // Red
        case .high: return Color.accentOrange       // Orange
        case .medium: return Color.statusWarning    // Yellow
        case .low: return Color.textTertiary        // Gray
        }
    }
    
    /// Status color for action buttons only
    private var statusColor: Color {
        switch task.status {
        case .todo: return Color.statusTodo
        case .inProgress: return Color.statusInProgress
        case .pendingVerification: return Color.statusPending
        case .completed: return Color.statusCompleted
        }
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 0) {
                // Priority border (4px left edge)
                RoundedRectangle(cornerRadius: 2)
                    .fill(priorityBorderColor)
                    .frame(width: 4)
                
                // Card content
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // Top row: Group name + due time indicator
                    HStack {
                        if let groupName {
                            Text(groupName)
                                .font(DS.Typography.caption())
                                .foregroundStyle(.textTertiary)
                        }
                        
                        Spacer()
                        
                        // Due time indicator (replaces status badge)
                        if task.isOverdue {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(DS.Typography.micro())
                                Text("overdue")
                                    .font(DS.Typography.micro())
                            }
                            .foregroundStyle(.statusError)
                        } else if task.isDueSoon {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: "clock.fill")
                                    .font(DS.Typography.micro())
                                Text(task.timeUntilDueText)
                                    .font(DS.Typography.micro())
                            }
                            .foregroundStyle(.accentOrange)
                        } else if let time = task.scheduledTime {
                            Label(time.formattedTime, systemImage: "clock")
                                .font(DS.Typography.caption())
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    
                    // Task title
                    Text(task.title)
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Metadata row (recurring + task type)
                    HStack(spacing: DS.Spacing.sm) {
                        // Task type badge (Chore/Homework)
                        if let taskType = task.taskType {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: taskType.icon)
                                    .font(DS.Typography.micro())
                                Text(taskType.displayName)
                                    .font(DS.Typography.micro())
                            }
                            .foregroundStyle(taskType == .homework ? .accentBlue : .textTertiary)
                        }
                        
                        if task.isRecurring {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: "repeat")
                                    .font(DS.Typography.micro())
                                Text("repeats")
                                    .font(DS.Typography.micro())
                            }
                            .foregroundStyle(.accentTertiary)
                        }
                        
                        Spacer()
                        
                        // Reward badge
                        if task.hasReward, let amount = task.rewardAmount {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(DS.Typography.bodySmall())
                                Text(amount.currencyString)
                                    .font(DS.Typography.captionMedium())
                            }
                            .foregroundStyle(.accentGreen)
                        }
                    }
                    
                    // Action buttons based on status
                    if showActions {
                        taskActionButtons
                            .padding(.top, DS.Spacing.xxs)
                    }
                }
                .padding(DS.Spacing.cardPadding)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.themeCardBorder, lineWidth: 0.5)
            )
            .elevation2()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Task Action Buttons
    @ViewBuilder
    private var taskActionButtons: some View {
        switch task.status {
        case .todo:
            // Start Task button
            Button(action: { onStartTask?() }) {
                HStack(spacing: DS.Spacing.xs) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    }
                    Image(systemName: "play.fill")
                        .font(DS.Typography.micro())
                    Text("startTask")
                        .font(DS.Typography.captionMedium())
                }
                .foregroundStyle(.textOnAccent)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(isLoading ? Color.gray : Color.accentPrimary)
                )
                .elevationAccent(isLoading ? .gray : Color.accentPrimary)
            }
            .disabled(isLoading)
            
        case .inProgress:
            // Start Focus and Mark Complete buttons
            HStack(spacing: DS.Spacing.sm) {
                Button(action: { onStartFocus?() }) {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "timer")
                            .font(DS.Typography.micro())
                        Text("focus")
                            .font(DS.Typography.captionMedium())
                    }
                    .foregroundStyle(.textOnAccent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.accentTertiary)
                    )
                }
                .disabled(isLoading)
                
                if !task.requiresProof {
                    Button(action: { onMarkComplete?() }) {
                        HStack(spacing: DS.Spacing.xxs) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            }
                            Image(systemName: "checkmark")
                                .font(DS.Typography.micro())
                            Text("complete")
                                .font(DS.Typography.captionMedium())
                        }
                        .foregroundStyle(.textOnAccent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(isLoading ? Color.gray : Color.statusSuccess)
                        )
                    }
                    .disabled(isLoading)
                }
            }
            
        case .pendingVerification:
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "clock.badge.checkmark")
                    .font(DS.Typography.bodySmall())
                Text("awaitingVerification")
                    .font(DS.Typography.caption())
            }
            .foregroundStyle(.statusPending)
            
        case .completed:
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.bodySmall())
                Text("completed")
                    .font(DS.Typography.caption())
            }
            .foregroundStyle(.statusCompleted)
        }
    }
}

// MARK: - Compact Task Card (for lists)

struct CompactTaskCard: View {
    let task: FamilyTask
    var onTap: (() -> Void)?
    
    private var priorityBorderColor: Color {
        switch task.displayPriority {
        case .urgent: return Color.statusError
        case .high: return Color.accentOrange
        case .medium: return Color.statusWarning
        case .low: return Color.textTertiary
        }
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 0) {
                // Priority border
                RoundedRectangle(cornerRadius: 2)
                    .fill(priorityBorderColor)
                    .frame(width: 3)
                
                HStack(spacing: DS.Spacing.sm) {
                    // Status indicator dot
                    Circle()
                        .fill(task.status == .completed ? Color.statusCompleted : priorityBorderColor)
                        .frame(width: 8, height: 8)
                    
                    // Title
                    Text(task.title)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Due indicator or reward
                    if task.isOverdue {
                        Text("overdue")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.statusError)
                    } else if task.hasReward, let amount = task.rewardAmount {
                        Text(amount.currencyString)
                            .font(DS.Typography.captionMedium())
                            .foregroundStyle(.accentGreen)
                    } else if let time = task.scheduledTime {
                        Text(time.formattedTime)
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textTertiary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
            }
            .background(Color.themeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Priority Border Cards") {
    ScrollView {
        VStack(spacing: DS.Spacing.md) {
            // Urgent - Red border (overdue)
            TaskCard(
                task: FamilyTask(
                    familyId: "test",
                    groupId: nil,
                    title: "URGENT: Math homework due now!",
                    description: nil,
                    assignedTo: nil,
                    assignees: [],
                    assignedBy: "user1",
                    dueDate: Date().addingTimeInterval(-3600), // 1 hour ago
                    scheduledTime: nil,
                    status: .todo,
                    priority: .medium,
                    createdAt: Date(),
                    completedAt: nil,
                    hasReward: true,
                    rewardAmount: 10.0,
                    requiresProof: false,
                    proofType: nil,
                    proofURL: nil,
                    proofURLs: nil,
                    proofVerifiedBy: nil,
                    proofVerifiedAt: nil,
                    rewardPaid: false,
                    isRecurring: false,
                    recurrenceRule: nil,
                    taskType: .homework
                ),
                groupName: "School",
                showActions: true
            )
            
            // High - Orange border (due soon)
            TaskCard(
                task: FamilyTask(
                    familyId: "test",
                    groupId: nil,
                    title: "Clean your room before dinner",
                    description: nil,
                    assignedTo: nil,
                    assignees: [],
                    assignedBy: "user1",
                    dueDate: Date().addingTimeInterval(3600), // 1 hour from now
                    scheduledTime: Date().addingTimeInterval(3600),
                    status: .inProgress,
                    priority: .medium,
                    createdAt: Date(),
                    completedAt: nil,
                    hasReward: true,
                    rewardAmount: 5.0,
                    requiresProof: false,
                    proofType: nil,
                    proofURL: nil,
                    proofURLs: nil,
                    proofVerifiedBy: nil,
                    proofVerifiedAt: nil,
                    rewardPaid: false,
                    isRecurring: false,
                    recurrenceRule: nil,
                    taskType: .chore
                ),
                groupName: "Daily Chores",
                showActions: true
            )
            
            // Medium - Yellow border (due tomorrow)
            TaskCard(
                task: FamilyTask(
                    familyId: "test",
                    groupId: nil,
                    title: "Practice piano for 30 minutes",
                    description: nil,
                    assignedTo: nil,
                    assignees: [],
                    assignedBy: "user1",
                    dueDate: Date().addingTimeInterval(86400), // Tomorrow
                    scheduledTime: nil,
                    status: .pendingVerification,
                    priority: .medium,
                    createdAt: Date(),
                    completedAt: nil,
                    hasReward: false,
                    rewardAmount: nil,
                    requiresProof: true,
                    proofType: .photo,
                    proofURL: nil,
                    proofURLs: nil,
                    proofVerifiedBy: nil,
                    proofVerifiedAt: nil,
                    rewardPaid: false,
                    isRecurring: true,
                    recurrenceRule: nil,
                    taskType: nil
                ),
                groupName: "Music",
                showActions: true
            )
            
            // Low - Gray border (due later)
            TaskCard(
                task: FamilyTask(
                    familyId: "test",
                    groupId: nil,
                    title: "Organize bookshelf",
                    description: nil,
                    assignedTo: nil,
                    assignees: [],
                    assignedBy: "user1",
                    dueDate: Date().addingTimeInterval(604800), // 1 week
                    scheduledTime: nil,
                    status: .completed,
                    priority: .low,
                    createdAt: Date(),
                    completedAt: Date(),
                    hasReward: false,
                    rewardAmount: nil,
                    requiresProof: false,
                    proofType: nil,
                    proofURL: nil,
                    proofURLs: nil,
                    proofVerifiedBy: nil,
                    proofVerifiedAt: nil,
                    rewardPaid: false,
                    isRecurring: false,
                    recurrenceRule: nil,
                    taskType: .chore
                ),
                groupName: nil,
                showActions: true
            )
            
            Divider()
                .padding(.vertical, DS.Spacing.md)
            
            Text("compact cards")
                .font(DS.Typography.heading())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            CompactTaskCard(
                task: FamilyTask(
                    familyId: "test",
                    groupId: nil,
                    title: "Overdue task example",
                    description: nil,
                    assignedTo: nil,
                    assignees: [],
                    assignedBy: "user1",
                    dueDate: Date().addingTimeInterval(-7200),
                    scheduledTime: nil,
                    status: .todo,
                    priority: .medium,
                    createdAt: Date(),
                    completedAt: nil,
                    hasReward: true,
                    rewardAmount: 3.0,
                    requiresProof: false,
                    proofType: nil,
                    proofURL: nil,
                    proofURLs: nil,
                    proofVerifiedBy: nil,
                    proofVerifiedAt: nil,
                    rewardPaid: false,
                    isRecurring: false,
                    recurrenceRule: nil
                )
            )
            
            CompactTaskCard(
                task: FamilyTask(
                    familyId: "test",
                    groupId: nil,
                    title: "Normal task with time",
                    description: nil,
                    assignedTo: nil,
                    assignees: [],
                    assignedBy: "user1",
                    dueDate: Date().addingTimeInterval(86400 * 3),
                    scheduledTime: Date(),
                    status: .inProgress,
                    priority: .low,
                    createdAt: Date(),
                    completedAt: nil,
                    hasReward: false,
                    rewardAmount: nil,
                    requiresProof: false,
                    proofType: nil,
                    proofURL: nil,
                    proofURLs: nil,
                    proofVerifiedBy: nil,
                    proofVerifiedAt: nil,
                    rewardPaid: false,
                    isRecurring: false,
                    recurrenceRule: nil
                )
            )
        }
        .padding(DS.Spacing.screenH)
    }
    .background(Color.themeSurfacePrimary)
}
