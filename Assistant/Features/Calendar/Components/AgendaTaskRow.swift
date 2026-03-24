//
//  AgendaTaskRow.swift
//
//  LUXURY CALM REDESIGN
//  - Clean card design with soft shadows
//  - Refined priority indicators
//  - Elegant status badges
//  - Premium typography
//

import SwiftUI

// MARK: - Agenda Task Row

struct AgendaTaskRow: View {
    let task: FamilyTask
    let familyMembers: [FamilyUser]
    
    private var assignee: FamilyUser? {
        task.assignedTo.flatMap { id in familyMembers.first { $0.id == id } }
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
            
            // Content
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(task.title)
                    .font(DS.Typography.label())
                    .foregroundStyle(task.status == .completed ? .textTertiary : .textPrimary)
                    .strikethrough(task.status == .completed, color: Color.textTertiary)
                    .lineLimit(1)
                
                HStack(spacing: DS.Spacing.sm) {
                    // Status
                    statusIndicator
                    
                    // Time
                    if let time = task.scheduledTime {
                        Text(time.formattedTime)
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textTertiary)
                    }
                    
                    // Assignee
                    if let assignee = assignee {
                        Text(assignee.displayName)
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            // Reward
            if task.hasReward, let amount = task.rewardAmount {
                Text(amount.currencyString)
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.accentGreen)
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(DS.Typography.captionMedium())
                .foregroundStyle(.textTertiary)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch task.status {
        case .todo:
            HStack(spacing: DS.Spacing.xxs) {
                Circle()
                    .stroke(Color.textTertiary.opacity(0.4), lineWidth: 1)
                    .frame(width: 10, height: 10)
                Text("toDo")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
            }
            
        case .inProgress:
            HStack(spacing: DS.Spacing.xxs) {
                Circle()
                    .fill(Color.statusInProgress)
                    .frame(width: 6, height: 6)
                Text("inProgress")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.statusInProgress)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.statusInProgress.opacity(0.1))
            )
            
        case .pendingVerification:
            HStack(spacing: DS.Spacing.xxs) {
                Circle()
                    .fill(Color.statusPending)
                    .frame(width: 6, height: 6)
                Text("pending")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.statusPending)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.statusPending.opacity(0.1))
            )
            
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.body())
                .foregroundStyle(.accentGreen)
        }
    }
    
    // MARK: - Priority Color (Softer)
    
    private var priorityColor: Color {
        switch task.priority {
        case .urgent: return Color.statusError  // Soft red
        case .high: return Color(hex: "FFB74D")    // Soft orange
        case .medium: return Color.accentPrimary
        case .low: return Color.textTertiary
        }
    }
}

// MARK: - Agenda Event Row

struct AgendaEventRow: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.color))
                .frame(width: 4, height: 40)
            
            // Content
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(event.title)
                    .font(DS.Typography.label())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                
                Text(event.isAllDay ? "allDay" : timeRange)
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textSecondary)
            }
            
            Spacer()
            
            // Participants
            if event.participants.count > 1 {
                HStack(spacing: -6) {
                    ForEach(0..<min(event.participants.count, 3), id: \.self) { index in
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.15))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.themeCardBackground, lineWidth: 1.5)
                            )
                    }
                    
                    if event.participants.count > 3 {
                        Text("+\(event.participants.count - 3)")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                            .padding(.leading, DS.Spacing.xs)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
    }
    
    private var timeRange: String {
        "\(event.startDate.formattedTime) – \(event.endDate.formattedTime)"
    }
}
