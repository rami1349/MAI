//
//  HomeCompactTaskRow.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//




import SwiftUI

struct HomeCompactTaskRow: View {
    let task: FamilyTask
    let groupName: String?
    let assigneeName: String?
    let onTap: () -> Void
    
    private var priorityColor: Color {
        switch task.priority {
        case .urgent: return Color(hex: "E57373")  // Soft red
        case .high: return Color(hex: "FFB74D")    // Soft orange
        case .medium: return .accentPrimary
        case .low: return .textTertiary
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Luxury.Spacing.md) {
                // Priority indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    // Title row
                    HStack(spacing: Luxury.Spacing.xs) {
                        Text(task.title)
                            .font(Luxury.Typography.label())
                            .foregroundColor(task.status == .completed ? .textTertiary : .textPrimary)
                            .lineLimit(1)
                            .strikethrough(task.status == .completed, color: .textTertiary)
                        
                        if task.hasReward {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.accentGreen)
                        }
                        
                        if task.isRecurring {
                            Image(systemName: "repeat")
                                .font(.system(size: 10))
                                .foregroundColor(.textTertiary)
                        }
                    }
                    
                    // Subtitle row
                    HStack(spacing: Luxury.Spacing.xs) {
                        if let groupName {
                            Text(groupName)
                                .font(Luxury.Typography.micro())
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                        }
                        
                        if groupName != nil && (assigneeName != nil || task.scheduledTime != nil) {
                            Text("·")
                                .font(Luxury.Typography.micro())
                                .foregroundColor(.textTertiary)
                        }
                        
                        if let assigneeName {
                            Text(assigneeName)
                                .font(Luxury.Typography.micro())
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                        }
                        
                        if let time = task.scheduledTime {
                            Text(time.formattedTime)
                                .font(Luxury.Typography.micro())
                                .foregroundColor(.textTertiary)
                        }
                    }
                }
                
                Spacer(minLength: Luxury.Spacing.xs)
                
                // Status indicator
                statusIndicator
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .padding(.vertical, Luxury.Spacing.sm)
            .padding(.horizontal, Luxury.Spacing.md)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Luxury.Radius.md)
                    .fill(Color.themeCardBackground)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch task.status {
        case .todo:
            Circle()
                .stroke(Color.textTertiary.opacity(0.4), lineWidth: 1.5)
                .frame(width: 16, height: 16)
            
        case .inProgress:
            HStack(spacing: 3) {
                Circle()
                    .fill(Color.statusInProgress)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.statusInProgress.opacity(0.12))
            )
            
        case .pendingVerification:
            HStack(spacing: 3) {
                Circle()
                    .fill(Color.statusPending)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.statusPending.opacity(0.12))
            )
            
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.accentGreen)
        }
    }
    
    private var accessibilityDescription: String {
        var parts = [task.title, task.status.rawValue, task.priority.rawValue]
        if let groupName { parts.append("in \(groupName)") }
        if let assigneeName { parts.append("assigned to \(assigneeName)") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    VStack(spacing: 8) {
        HomeCompactTaskRow(
            task: FamilyTask(
                familyId: "test", groupId: nil, title: "Take out trash",
                description: nil, assignedTo: nil, assignedBy: "u1",
                dueDate: Date(), scheduledTime: Date(),
                status: .todo, priority: .medium,
                createdAt: Date(), completedAt: nil,
                hasReward: true, rewardAmount: 5, requiresProof: false,
                proofType: nil, proofURL: nil, proofVerifiedBy: nil,
                proofVerifiedAt: nil, rewardPaid: false,
                isRecurring: false, recurrenceRule: nil
            ),
            groupName: "Daily Chores",
            assigneeName: "Alex",
            onTap: {}
        )
        
        HomeCompactTaskRow(
            task: FamilyTask(
                familyId: "test", groupId: nil, title: "Urgent homework",
                description: nil, assignedTo: nil, assignedBy: "u1",
                dueDate: Date(), scheduledTime: nil,
                status: .inProgress, priority: .urgent,
                createdAt: Date(), completedAt: nil,
                hasReward: false, rewardAmount: nil, requiresProof: false,
                proofType: nil, proofURL: nil, proofVerifiedBy: nil,
                proofVerifiedAt: nil, rewardPaid: false,
                isRecurring: true, recurrenceRule: nil
            ),
            groupName: nil,
            assigneeName: nil,
            onTap: {}
        )
    }
    .padding()
    .background(Color.themeSurfacePrimary)
}