//
//  HomeUnifiedTaskList.swift
//  FamilyHub
//
//  Unified task list with search bar, compact rows, and swipe actions.
//  Uses LazyVStack for 60fps scrolling with stable IDs.
//  All filtering happens in HomeDerivedState — this view just renders.
//
//  UPDATED: Uses stableId for ForEach to prevent nil ID collisions
//  UPDATED: Multi-assignee display support
//

import SwiftUI

struct HomeUnifiedTaskList: View {
    let tasks: [FamilyTask]
    let totalActive: Int
    let completedCount: Int
    @Binding var searchText: String
    @Binding var showCompleted: Bool
    let isSearchActive: Bool
    let groupLookup: (String) -> TaskGroup?
    let memberLookup: (String) -> FamilyUser?
    let onSelectTask: (FamilyTask) -> Void
    let onCompleteTask: (FamilyTask) async -> Void
    let onDeleteTask: (FamilyTask) async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section header
            sectionHeader
            
            // Search bar
            searchBar
            
            // Show completed toggle
            if completedCount > 0 {
                completedToggle
            }
            
            // Task list or empty state
            if tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .padding(.horizontal, DS.Spacing.screenH)
    }
    
    // MARK: - Header
    
    private var sectionHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checklist")
                .font(.subheadline)
                .foregroundStyle(.accentPrimary)
            
            Text(L10n.myTasks)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.textPrimary)
            
            Text("\(totalActive)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.accentPrimary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(Capsule().fill(Color.accentPrimary.opacity(0.1)))
            
            Spacer()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.textTertiary)
            
            TextField(L10n.search, text: $searchText)
                .font(.subheadline)
                .foregroundStyle(.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.textTertiary)
                }
                .frame(minWidth: DS.Control.minTapTarget, minHeight: DS.Control.minTapTarget)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.input)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.input)
                .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("10n.searchTasks")
    }
    
    // MARK: - Completed Toggle
    
    private var completedToggle: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showCompleted.toggle() } }) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: showCompleted ? "eye.fill" : "eye.slash")
                    .font(.caption)
                // TODO: Add L10n keys: "show_completed" / "hide_completed"
                Text(showCompleted ? "Hide Completed" : "Show Completed")
                    .font(.caption)
                Text("(\(completedCount))")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            .foregroundStyle(.accentPrimary)
        }
        .controlSize(.small)
        .frame(minHeight: 36)
    }
    
    // MARK: - Task List
    
    private var taskList: some View {
        // LazyVStack with stable IDs for smooth 60fps scrolling
        // Uses stableId to prevent nil ID collisions during optimistic updates
        LazyVStack(spacing: DS.Spacing.xs) {
            ForEach(tasks,  id:\.stableId) { task in
                HomeCompactTaskRow(
                    task: task,
                    groupName: task.groupId.flatMap { groupLookup($0)?.name },
                    assigneeName: assigneeDisplayName(for: task),
                    onTap: { onSelectTask(task) }
                )
                .swipeToDelete {
                    Task { await onDeleteTask(task) }
                }
            }
        }
    }
    
    // MARK: - Multi-Assignee Display Helper
    
    /// Returns formatted assignee name(s) for display
    /// - Single assignee: "John"
    /// - Multiple assignees: "John, Sarah" or "John +2"
    private func assigneeDisplayName(for task: FamilyTask) -> String? {
        let assignees = task.allAssignees
        guard !assignees.isEmpty else { return nil }
        
        let names = assignees.compactMap { memberLookup($0)?.displayName }
        guard !names.isEmpty else { return nil }
        
        if names.count == 1 {
            return names[0]
        } else if names.count == 2 {
            return "\(names[0]), \(names[1])"
        } else {
            return "\(names[0]) +\(names.count - 1)"
        }
    }
    
    // MARK: - Empty States
    
    @ViewBuilder
    private var emptyState: some View {
        if isSearchActive {
            // No search results
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.textTertiary)
                Text(L10n.noTasksFilter)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxl)
        } else {
            // No tasks at all
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.textTertiary)
                Text(L10n.noTasks)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                Text(L10n.addTasksToStart)
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxl)
        }
    }
}
