//
//  TaskCard.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
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
        case .urgent: return .statusError      // Red
        case .high: return .accentOrange       // Orange
        case .medium: return .statusWarning    // Yellow
        case .low: return .textTertiary        // Gray
        }
    }
    
    /// Status color for action buttons only
    private var statusColor: Color {
        switch task.status {
        case .todo: return .statusTodo
        case .inProgress: return .statusInProgress
        case .pendingVerification: return .statusPending
        case .completed: return .statusCompleted
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
                VStack(alignment: .leading, spacing: Luxury.Spacing.sm) {
                    // Top row: Group name + due time indicator
                    HStack {
                        if let groupName {
                            Text(groupName)
                                .font(Luxury.Typography.caption())
                                .foregroundColor(.textTertiary)
                        }
                        
                        Spacer()
                        
                        // Due time indicator (replaces status badge)
                        if task.isOverdue {
                            HStack(spacing: Luxury.Spacing.xxs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                Text(L10n.overdue)
                                    .font(Luxury.Typography.micro())
                            }
                            .foregroundColor(.statusError)
                        } else if task.isDueSoon {
                            HStack(spacing: Luxury.Spacing.xxs) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                Text(task.timeUntilDueText)
                                    .font(Luxury.Typography.micro())
                            }
                            .foregroundColor(.accentOrange)
                        } else if let time = task.scheduledTime {
                            Label(time.formattedTime, systemImage: "clock")
                                .font(Luxury.Typography.caption())
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    // Task title
                    Text(task.title)
                        .font(Luxury.Typography.subheading())
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Metadata row (recurring + task type)
                    HStack(spacing: Luxury.Spacing.sm) {
                        // Task type badge (Chore/Homework)
                        if let taskType = task.taskType {
                            HStack(spacing: Luxury.Spacing.xxs) {
                                Image(systemName: taskType.icon)
                                    .font(.system(size: 10))
                                Text(taskType.displayName)
                                    .font(Luxury.Typography.micro())
                            }
                            .foregroundColor(taskType == .homework ? .accentBlue : .textTertiary)
                        }
                        
                        if task.isRecurring {
                            HStack(spacing: Luxury.Spacing.xxs) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 10))
                                Text(L10n.repeats)
                                    .font(Luxury.Typography.micro())
                            }
                            .foregroundColor(.accentTertiary)
                        }
                        
                        Spacer()
                        
                        // Reward badge
                        if task.hasReward, let amount = task.rewardAmount {
                            HStack(spacing: Luxury.Spacing.xxs) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 12))
                                Text(amount.currencyString)
                                    .font(Luxury.Typography.captionMedium())
                            }
                            .foregroundColor(.accentGreen)
                        }
                    }
                    
                    // Action buttons based on status
                    if showActions {
                        taskActionButtons
                            .padding(.top, Luxury.Spacing.xxs)
                    }
                }
                .padding(Luxury.Spacing.cardPadding)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Luxury.Radius.md)
                    .fill(Color.themeCardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: Luxury.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Luxury.Radius.md)
                    .stroke(Color.luxuryCardBorder, lineWidth: 0.5)
            )
            .luxuryLevel2()
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
                HStack(spacing: Luxury.Spacing.xs) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    }
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.startTask)
                        .font(Luxury.Typography.captionMedium())
                }
                .foregroundColor(.white)
                .padding(.horizontal, Luxury.Spacing.md)
                .padding(.vertical, Luxury.Spacing.xs)
                .background(
                    Capsule()
                        .fill(isLoading ? Color.gray : Color.accentPrimary)
                )
                .luxuryAccent(isLoading ? .gray : .accentPrimary)
            }
            .disabled(isLoading)
            
        case .inProgress:
            // Start Focus and Mark Complete buttons
            HStack(spacing: Luxury.Spacing.sm) {
                Button(action: { onStartFocus?() }) {
                    HStack(spacing: Luxury.Spacing.xxs) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .medium))
                        Text(L10n.focus)
                            .font(Luxury.Typography.captionMedium())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Luxury.Spacing.sm)
                    .padding(.vertical, Luxury.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.accentTertiary)
                    )
                }
                .disabled(isLoading)
                
                if !task.requiresProof {
                    Button(action: { onMarkComplete?() }) {
                        HStack(spacing: Luxury.Spacing.xxs) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            }
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                            Text(L10n.complete)
                                .font(Luxury.Typography.captionMedium())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, Luxury.Spacing.sm)
                        .padding(.vertical, Luxury.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(isLoading ? Color.gray : Color.statusSuccess)
                        )
                    }
                    .disabled(isLoading)
                }
            }
            
        case .pendingVerification:
            HStack(spacing: Luxury.Spacing.xs) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 12))
                Text(L10n.awaitingVerification)
                    .font(Luxury.Typography.caption())
            }
            .foregroundColor(.statusPending)
            
        case .completed:
            HStack(spacing: Luxury.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                Text(L10n.completed)
                    .font(Luxury.Typography.caption())
            }
            .foregroundColor(.statusCompleted)
        }
    }
}

// MARK: - Compact Task Card (for lists)

struct CompactTaskCard: View {
    let task: FamilyTask
    var onTap: (() -> Void)?
    
    private var priorityBorderColor: Color {
        switch task.displayPriority {
        case .urgent: return .statusError
        case .high: return .accentOrange
        case .medium: return .statusWarning
        case .low: return .textTertiary
        }
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 0) {
                // Priority border
                RoundedRectangle(cornerRadius: 2)
                    .fill(priorityBorderColor)
                    .frame(width: 3)
                
                HStack(spacing: Luxury.Spacing.sm) {
                    // Status indicator dot
                    Circle()
                        .fill(task.status == .completed ? Color.statusCompleted : priorityBorderColor)
                        .frame(width: 8, height: 8)
                    
                    // Title
                    Text(task.title)
                        .font(Luxury.Typography.body())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Due indicator or reward
                    if task.isOverdue {
                        Text(L10n.overdue)
                            .font(Luxury.Typography.micro())
                            .foregroundColor(.statusError)
                    } else if task.hasReward, let amount = task.rewardAmount {
                        Text(amount.currencyString)
                            .font(Luxury.Typography.captionMedium())
                            .foregroundColor(.accentGreen)
                    } else if let time = task.scheduledTime {
                        Text(time.formattedTime)
                            .font(Luxury.Typography.caption())
                            .foregroundColor(.textTertiary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, Luxury.Spacing.md)
                .padding(.vertical, Luxury.Spacing.sm)
            }
            .background(Color.themeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Luxury.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Priority Border Cards") {
    ScrollView {
        VStack(spacing: Luxury.Spacing.md) {
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
                .padding(.vertical, Luxury.Spacing.md)
            
            Text("Compact Cards")
                .font(Luxury.Typography.heading())
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
        .padding(Luxury.Spacing.screenH)
    }
    .background(Color.themeSurfacePrimary)
}