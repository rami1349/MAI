//
//  HomeCompactGroupsSection.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//




import SwiftUI

struct HomeCompactGroupsSection: View {
    let groups: [TaskGroup]
    let onSelectGroup: (TaskGroup) -> Void
    let onDeleteGroup: (TaskGroup) async -> Void
    
    @State private var isExpanded = false
    @State private var showDeleteAlert = false
    @State private var groupToDelete: TaskGroup? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: Luxury.Spacing.sm) {
            // Section header with collapse toggle
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: Luxury.Spacing.sm) {
                    // Icon badge
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                    
                    Text(L10n.taskGroups)
                        .font(Luxury.Typography.subheading())
                        .foregroundColor(.textPrimary)
                    
                    // Count badge
                    Text("\(groups.count)")
                        .font(Luxury.Typography.captionMedium())
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, Luxury.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                .padding(.vertical, Luxury.Spacing.xs)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("Task groups, \(groups.count) groups")
            .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")
            
            // Group rows
            if isExpanded {
                VStack(spacing: Luxury.Spacing.xs) {
                    ForEach(groups) { group in
                        CompactGroupRow(group: group, onTap: { onSelectGroup(group) })
                            .swipeToDelete {
                                groupToDelete = group
                                showDeleteAlert = true
                            }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Luxury.Spacing.screenH)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .alert(L10n.deleteTaskGroup, isPresented: $showDeleteAlert) {
            Button(L10n.cancel, role: .cancel) { groupToDelete = nil }
            Button(L10n.delete, role: .destructive) {
                if let group = groupToDelete {
                    Task { await onDeleteGroup(group) }
                }
                groupToDelete = nil
            }
        } message: {
            if let group = groupToDelete {
                Text(L10n.deleteGroupConfirm(group.name))
            }
        }
    }
}

// MARK: - Compact Group Row

struct CompactGroupRow: View {
    let group: TaskGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Luxury.Spacing.md) {
                // Group icon
                ZStack {
                    RoundedRectangle(cornerRadius: Luxury.Radius.sm)
                        .fill(Color(hex: group.color).opacity(0.12))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: group.icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: group.color))
                }
                
                // Name + count
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.name)
                        .font(Luxury.Typography.label())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(group.taskCount) \(L10n.tasks)")
                        .font(Luxury.Typography.micro())
                        .foregroundColor(.textTertiary)
                }
                
                Spacer()
                
                // Progress ring
                if group.taskCount > 0 {
                    ProgressRing(
                        progress: group.completionPercentage,
                        size: 28,
                        lineWidth: 3,
                        color: Color(hex: group.color)
                    )
                }
                
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
        .accessibilityLabel("\(group.name), \(group.taskCount) tasks, \(Int(group.completionPercentage))% complete")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HomeCompactGroupsSection(
        groups: [
            {
                var g = TaskGroup(familyId: "t", name: "Daily Chores", icon: "house.fill", color: "7C3AED", createdBy: "u1", createdAt: Date())
                g.taskCount = 5
                g.completionPercentage = 60
                return g
            }(),
            {
                var g = TaskGroup(familyId: "t", name: "Homework", icon: "book.fill", color: "3B82F6", createdBy: "u1", createdAt: Date())
                g.taskCount = 3
                g.completionPercentage = 33
                return g
            }()
        ],
        onSelectGroup: { _ in },
        onDeleteGroup: { _ in }
    )
    .padding()
    .background(Color.themeSurfacePrimary)
}