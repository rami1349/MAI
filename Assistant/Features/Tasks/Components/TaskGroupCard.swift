//
//  TaskGroupCard.swift
//  FamilyHub
//
//  Task group card with progress indicator
//

import SwiftUI

struct TaskGroupCard: View {
    let group: TaskGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.lg) {
                Image(systemName: group.icon)
                    .font(.system(size: DS.IconSize.lg)) // DT-exempt: icon sizing
                    .foregroundStyle(.accentPrimary)
                    .frame(width: DS.IconContainer.lg, height: DS.IconContainer.lg)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.themeHighlight))
                
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(group.name)
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                    Text("\(group.taskCount) \(L10n.tasks)")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textSecondary)
                }
                
                Spacer()
                
                ProgressRing(progress: group.completionPercentage, size: 50, lineWidth: 5, color: Color.accentPrimary)
            }
            .padding(DS.Spacing.cardPadding)
            .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.themeCardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(Color.themeCardBorder, lineWidth: DS.Border.standard)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        TaskGroupCard(
            group: {
                var g = TaskGroup(
                    familyId: "test",
                    name: "Daily Chores",
                    icon: "house.fill",
                    color: "7C3AED",
                    createdBy: "user1",
                    createdAt: Date()
                )
                g.taskCount = 5
                g.completionPercentage = 60
                return g
            }(),
            onTap: {}
        )
    }
    .padding()
    .background(Color.themeSurfacePrimary)
}
