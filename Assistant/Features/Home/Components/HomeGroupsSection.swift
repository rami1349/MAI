// ============================================================================
// HomeGroupsSection.swift
//
// SLOT 6: My Folders
//
// Collapsible section showing task groups with progress bars and task counts.
// Used on both iPhone (full-width list) and iPad (left column below Focus Now).
//
// ============================================================================

import SwiftUI

struct HomeGroupsSection: View {
    let groups: [TaskGroup]
    let onSelectGroup: (TaskGroup) -> Void
    var onAddTask: ((TaskGroup) -> Void)? = nil
    var onDropTask: ((String, String) async -> Void)? = nil
    
    @State private var isExpanded = true
    
    @ViewBuilder
    var body: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "folder.fill")
                            .font(DS.Typography.label())
                            .foregroundStyle(.accentPrimary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.accentPrimary.opacity(0.1))
                            )
                        
                        Text("task_groups")
                            .font(DS.Typography.subheading())
                            .foregroundStyle(.textPrimary)
                        
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
                }
                .buttonStyle(.plain)
                
                // Group cards
                if isExpanded {
                    VStack(spacing: DS.Spacing.xs) {
                        ForEach(groups) { group in
                            GroupRow(
                                group: group,
                                onTap: { onSelectGroup(group) },
                                onAdd: onAddTask.map { callback in { callback(group) } },
                                onDropTask: onDropTask
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Group Row

private struct GroupRow: View {
    let group: TaskGroup
    let onTap: () -> Void
    var onAdd: (() -> Void)? = nil
    var onDropTask: ((String, String) async -> Void)? = nil
    
    @State private var isDropTargeted = false
    
    private var groupColor: Color { Color(hex: group.color) }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(groupColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: group.icon)
                        .font(DS.Typography.body())
                        .foregroundStyle(groupColor)
                }
                
                // Name + progress
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(group.name)
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    
                    // Progress bar
                    HStack(spacing: DS.Spacing.xs) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(groupColor.opacity(0.15))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(groupColor)
                                    .frame(width: geo.size.width * (group.completionPercentage / 100), height: 4)
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(group.taskCount)")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                    }
                }
                
                Spacer()
                
                // Quick-add button
                if let onAdd {
                    Button(action: {
                        DS.Haptics.light()
                        onAdd()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(DS.Typography.body())
                            .foregroundStyle(groupColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                Image(systemName: "chevron.right")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isDropTargeted ? groupColor : Color.themeCardBorder,
                            lineWidth: isDropTargeted ? 2 : 0.5)
            )
            .scaleEffect(isDropTargeted ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        // iPad drag & drop: accept task stableIds
        .dropDestination(for: String.self) { stableIds, _ in
            guard let stableId = stableIds.first,
                  let gid = group.id,
                  let onDropTask
            else { return false }
            Task { await onDropTask(stableId, gid) }
            DS.Haptics.success()
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTargeted = targeted
            }
        }
    }
}
