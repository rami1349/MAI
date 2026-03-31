// ============================================================================
// TaskFolderInteractions.swift
//
// Shared components for all 4 task-to-folder interactions:
//   1. Transferable conformance → enables .draggable() / .dropDestination()
//   2. MoveToFolderMenu → reusable context menu submenu
//   3. moveTaskToGroup() → shared update logic
//
// ============================================================================

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Transferable (Drag & Drop)

/// Makes FamilyTask draggable by transferring its stableId as a string.
/// The receiving drop destination looks up the full task from TaskViewModel.
/// Export-only (no importing) — drop targets accept String.self, not FamilyTask.
extension FamilyTask: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.stableId)
    }
}


// MARK: - Move To Folder Menu (Context Menu Submenu)

/// A reusable menu section that shows "Move to folder >" with all available groups.
/// Use inside `.contextMenu { }` on any task row.
///
/// Usage:
/// ```swift
/// .contextMenu {
///     MoveToFolderMenu(task: task, groups: groups) { task, groupId in
///         await viewModel.moveTaskToGroup(task, groupId: groupId)
///     }
/// }
/// ```
struct MoveToFolderMenu: View {
    let task: FamilyTask
    let groups: [TaskGroup]
    let onMove: (FamilyTask, String?) async -> Void
    
    var body: some View {
        Menu {
            // Remove from folder (if currently in one)
            if task.groupId != nil {
                Button {
                    Task { await onMove(task, nil) }
                } label: {
                    Label("remove_from_folder", systemImage: "folder.badge.minus")
                }
                
                Divider()
            }
            
            // Available folders
            ForEach(groups) { group in
                if group.id != task.groupId {
                    Button {
                        Task { await onMove(task, group.id) }
                    } label: {
                        Label {
                            Text(group.name)
                        } icon: {
                            Image(systemName: group.icon)
                        }
                    }
                }
            }
        } label: {
            Label("move_to_folder", systemImage: "folder")
        }
    }
}


// MARK: - Drop-on-Folder Modifier

/// Modifier that makes a view accept dropped task stableIds and moves them to a group.
/// Applied to folder rows in HomeGroupsSection and TaskGroupDetailView.
struct FolderDropModifier: ViewModifier {
    let groupId: String
    let taskVM: TaskViewModel
    let onDrop: (FamilyTask, String) async -> Void
    
    @State private var isTargeted = false
    
    func body(content: Content) -> some View {
        content
            .dropDestination(for: String.self) { stableIds, _ in
                guard let stableId = stableIds.first,
                      let task = taskVM.task(byStableId: stableId)
                            ?? taskVM.allTasks.first(where: { $0.stableId == stableId })
                else { return false }
                Task { await onDrop(task, groupId) }
                DS.Haptics.success()
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isTargeted = targeted
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isTargeted ? Color.accentPrimary : .clear, lineWidth: 2)
            )
            .scaleEffect(isTargeted ? 1.02 : 1.0)
    }
}

extension View {
    /// Makes this view a drop target for tasks being moved to a folder.
    func folderDropTarget(
        groupId: String,
        taskVM: TaskViewModel,
        onDrop: @escaping (FamilyTask, String) async -> Void
    ) -> some View {
        modifier(FolderDropModifier(groupId: groupId, taskVM: taskVM, onDrop: onDrop))
    }
}


// MARK: - FamilyViewModel Extension: Move Task

extension FamilyViewModel {
    /// Move a task to a different group (or remove from group if groupId is nil).
    func moveTaskToGroup(_ task: FamilyTask, groupId: String?) async {
        var updated = task
        updated.groupId = groupId
        await updateTask(updated)
    }
}
