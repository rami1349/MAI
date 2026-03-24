//
//  HomeCompactGroupsSection.swift



import SwiftUI

struct HomeCompactGroupsSection: View {
    let groups: [TaskGroup]
    let onSelectGroup: (TaskGroup) -> Void
    let onDeleteGroup: (TaskGroup) async -> Void
    
    @State private var isExpanded = false
    @State private var showDeleteAlert = false
    @State private var groupToDelete: TaskGroup? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section header with collapse toggle
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: DS.Spacing.sm) {
                    // Icon badge
                    Image(systemName: "folder.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(.accentPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                    
                    Text("task_Groups")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                    
                    // Count badge
                    Text("\(groups.count)")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.accentPrimary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.textTertiary)
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("Task groups, \(groups.count) groups")
            .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")
            
            // Group rows
            if isExpanded {
                VStack(spacing: DS.Spacing.xs) {
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
        .padding(.horizontal, DS.Spacing.screenH)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .alert("delete_task_group", isPresented: $showDeleteAlert) {
            Button("cancel", role: .cancel) { groupToDelete = nil }
            Button("delete", role: .destructive) {
                if let group = groupToDelete {
                    Task { await onDeleteGroup(group) }
                }
                groupToDelete = nil
            }
        } message: {
            if let group = groupToDelete {
                Text(AppStrings.deleteGroupConfirm(group.name))
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
            HStack(spacing: DS.Spacing.md) {
                // Group icon
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(Color(hex: group.color).opacity(0.12))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: group.icon)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color(hex: group.color))
                }
                
                // Name + count
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.name)
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(group.taskCount) \(AppStrings.localized("tasks"))")
                        .font(DS.Typography.micro())
                        .foregroundStyle(.textTertiary)
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
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.md)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
            )
            .elevation1()
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
