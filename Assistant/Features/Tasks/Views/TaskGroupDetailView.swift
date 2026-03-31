//
//  TaskGroupDetailView.swift
//
//
//  Detailed view for a task group
//

import SwiftUI

struct TaskGroupDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @Environment(NavigationRouter.self) var router
    let taskGroup: TaskGroup
    
    @State private var showDeleteConfirm = false
    @State private var selectedTask: FamilyTask? = nil
    @State private var isDeleting = false
    @State private var toast: ToastMessage? = nil
    
    private var groupColor: Color {
        Color(hex: taskGroup.color)
    }
    
    private var tasksInGroup: [FamilyTask] {
        taskVM.tasksFor(groupId: taskGroup.id ?? "")
    }
    
    private var completedTasks: Int {
        tasksInGroup.filter { $0.status == .completed }.count
    }
    
    private var completionPercentage: Double {
        guard !tasksInGroup.isEmpty else { return 0 }
        return Double(completedTasks) / Double(tasksInGroup.count) * 100
    }
    
    var body: some View {
        ZStack {
            Color.themeSurfacePrimary
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerCard
                    statsCard
                    
                    if tasksInGroup.isEmpty {
                        EmptyStateView(
                            icon: "checklist",
                            title: "no_tasks_in_group",
                            message: "add_tasks_to_start"
                        )
                        .padding(.top, 40)
                    } else {
                        tasksListSection
                    }
                }
                .padding(DS.Layout.adaptiveScreenPadding)
                .constrainedWidth(.card)
            }
        }
        .navigationTitle(taskGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.sm) {
                    // Create task in this folder
                    Button(action: {
                        DS.Haptics.light()
                        router.present(.addTask(groupId: taskGroup.id))
                    }) {
                        Image(systemName: "plus")
                            .font(DS.Typography.body())
                            .foregroundStyle(.accentPrimary)
                    }
                    
                    // Overflow menu
                    Menu {
                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            Label("delete_group", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isDeleting)
                }
            }
        }
        // Drop target: drag tasks here to add to this folder
        .dropDestination(for: String.self) { stableIds, _ in
            guard let stableId = stableIds.first,
                  let task = taskVM.task(byStableId: stableId)
                        ?? taskVM.allTasks.first(where: { $0.stableId == stableId }),
                  let gid = taskGroup.id
            else { return false }
            Task { await familyViewModel.moveTaskToGroup(task, groupId: gid) }
            DS.Haptics.success()
            return true
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .onAppear {
            // Track that user is viewing this group (for FAB pre-selection)
            familyViewModel.currentViewingGroupId = taskGroup.id
        }
        .onDisappear {
            // Clear when leaving the group
            familyViewModel.currentViewingGroupId = nil
        }
        .alert("delete_task_group", isPresented: $showDeleteConfirm) {
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) {
                guard !isDeleting else { return }
                isDeleting = true
                Task {
                    await familyViewModel.deleteTaskGroup(taskGroup)
                    isDeleting = false
                    dismiss()
                }
            }
        } message: {
            if tasksInGroup.isEmpty {
                Text("action_cannot_be_undone")
            } else {
                Text(AppStrings.deleteGroupWarning(tasksInGroup.count))
            }
        }
        .toastBanner(item: $toast)
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: taskGroup.icon)
                .font(.system(size: DS.EmptyState.icon)) // DT-exempt: decorative icon
                .foregroundStyle(groupColor)
                .frame(width: DS.EmptyState.iconContainer, height: DS.EmptyState.iconContainer)
                .background(Circle().fill(groupColor.opacity(0.15)))
            
            Text(taskGroup.name)
                .font(DS.Typography.displayMedium())
                .foregroundStyle(.textPrimary)
            
            if let creator = familyMemberVM.getMember(by: taskGroup.createdBy) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("created_by")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                    Text(creator.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.themeCardBackground))
        .elevation1()
    }
    
    // MARK: - Stats Card
    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("\(tasksInGroup.count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(groupColor)
                Text("total_tasks")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: 40)
            
            VStack(spacing: 8) {
                Text("\(completedTasks)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.statusCompleted)
                
                Text("completed")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: 40)
            
            VStack(spacing: 8) {
                Text("\(Int(completionPercentage))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.accentGreen)
                
                Text("progress")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.themeCardBackground))
        .elevation1()
    }
    
    // MARK: - Tasks List Section
    private var tasksListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("tasks")
                .font(.headline)
                .foregroundStyle(.textPrimary)
            
            VStack(spacing: 12) {
                ForEach(tasksInGroup, id: \.stableId) { task in
                    TaskRowCard(task: task, groupColor: groupColor)
                        .onTapGesture {
                            selectedTask = task
                        }
                        .draggable(task)
                        .contextMenu {
                            Button {
                                selectedTask = task
                            } label: {
                                Label("view_details", systemImage: "eye")
                            }
                            
                            MoveToFolderMenu(
                                task: task,
                                groups: familyMemberVM.taskGroups
                            ) { task, groupId in
                                await familyViewModel.moveTaskToGroup(task, groupId: groupId)
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Task Row Card
struct TaskRowCard: View {
    let task: FamilyTask
    let groupColor: Color
    
    var statusColor: Color {
        switch task.status {
        case .todo: return Color.statusTodo
        case .inProgress: return Color.statusInProgress
        case .pendingVerification: return Color.statusPending
        case .completed: return Color.statusCompleted
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.textPrimary)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(task.dueDate.formattedDate)
                            .font(.caption)
                    }
                    .foregroundStyle(.textSecondary)
                    
                    if task.hasReward, let amount = task.rewardAmount {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption2)
                            Text(amount.currencyString)
                                .font(.caption)
                        }
                        .foregroundStyle(.accentGreen)
                    }
                }
            }
            
            Spacer()
            
            Text(task.status.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(statusColor.opacity(0.15)))
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.themeCardBackground))
    }
}

#Preview {
    let familyVM = FamilyViewModel()
    NavigationStack {
        TaskGroupDetailView(
            taskGroup: TaskGroup(
                familyId: "test",
                name: "Daily Project",
                icon: "book.fill",
                color: "7C3AED",
                createdBy: "test",
                createdAt: Date.now
            )
        )
        .environment(AuthViewModel())
        .environment(familyVM)
        .environment(familyVM.familyMemberVM)
        .environment(familyVM.taskVM)
        .environment(NavigationRouter())
        .environment(familyVM.calendarVM)
        .environment(familyVM.habitVM)
        .environment(familyVM.notificationVM)
    }
}
