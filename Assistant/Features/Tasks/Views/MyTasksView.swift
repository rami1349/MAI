//
//  MyTasksView.swift
//  FamilyHub
//
//  FIX-VISIBILITY: Uses myTasksFiltered to hide completed tasks from assignee
//

import SwiftUI

struct MyTasksView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    
    @State private var selectedFilter: TaskStatusFilter = .todo
    @State private var selectedTask: FamilyTask? = nil
    @State private var focusTask: FamilyTask? = nil
    @State private var inFlightActions: Set<String> = []
    @State private var toast: ToastMessage? = nil
    
    // MARK: - Filter Enum (3-state: matches mental model)
    
    enum TaskStatusFilter: CaseIterable {
        case todo
        case inProgress
        case done
        
        var displayName: String {
            switch self {
            case .todo: return L10n.todo
            case .inProgress: return L10n.inProgress
            case .done: return L10n.done
            }
        }
    }
    
    // MARK: - Task Filtering
    
    // FIX-VISIBILITY: Use myTasksFiltered instead of tasksFor
    // This hides completed tasks that were assigned TO the user
    // But shows completed tasks that the user assigned to others (for monitoring)
    var myTasks: [FamilyTask] {
        guard let userId = authViewModel.currentUser?.id else { return [] }
        return taskVM.myTasksFiltered(userId: userId)
    }
    
    // For the "Done" filter, we need ALL tasks (including hidden completed ones)
    // so users can still see their completed tasks if they specifically filter for them
    var allMyTasks: [FamilyTask] {
        guard let userId = authViewModel.currentUser?.id else { return [] }
        return taskVM.tasksFor(userId: userId)
    }
    
    var filteredTasks: [FamilyTask] {
        switch selectedFilter {
        case .todo:
            return myTasks.filter { $0.status == .todo }
        case .inProgress:
            return myTasks.filter { $0.status == .inProgress || $0.status == .pendingVerification }
        case .done:
            // Only show completed recurring tasks - one-offs are hidden and auto-deleted
            return allMyTasks.filter { $0.status == .completed && $0.isRecurring }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            filterSection
            statsSection
            
            if taskVM.isLoading {
                // Skeleton loading state
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: DS.Spacing.md) {
                        ForEach(0..<5, id: \.self) { _ in
                            TaskCardSkeleton()
                        }
                    }
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                    .constrainedWidth(.content)
                }
            } else if filteredTasks.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "checklist",
                    title: L10n.noTasks,
                    message: L10n.noTasksFilter
                )
                Spacer()
            } else {
                tasksList
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .toastBanner(item: $toast)
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        HStack(spacing: 0) {
            ForEach(TaskStatusFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.displayName)
                        .font(DS.Typography.label())
                        .foregroundStyle(selectedFilter == filter ? .textPrimary : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Group {
                                if selectedFilter == filter {
                                    RoundedRectangle(cornerRadius: DS.Radius.md)
                                        .fill(Color.backgroundCard)
                                        .elevation1()
                                }
                            }
                        )
                }
            }
        }
        .padding(DS.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
        .padding(.bottom, DS.Spacing.md)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        Group {
            if taskVM.isLoading {
                HStack(spacing: DS.Spacing.md) {
                    StatCardSkeleton()
                    StatCardSkeleton()
                    StatCardSkeleton()
                }
            } else {
                let todoCount = allMyTasks.filter { $0.status == .todo }.count
                let inProgressCount = allMyTasks.filter { $0.status == .inProgress || $0.status == .pendingVerification }.count
                let doneCount = allMyTasks.filter { $0.status == .completed && $0.isRecurring }.count
                
                HStack(spacing: DS.Spacing.md) {
                    StatCard(title: L10n.todo, count: todoCount, color: Color.statusTodo)
                    StatCard(title: L10n.inProgress, count: inProgressCount, color: Color.statusInProgress)
                    StatCard(title: L10n.done, count: doneCount, color: Color.statusCompleted)
                }
            }
        }
        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
        .padding(.bottom, DS.Spacing.lg)
    }
    
    // MARK: - Tasks List
    
    private var tasksList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(filteredTasks, id: \.id) { task in
                    let taskId = task.id ?? ""
                    let group = task.groupId.flatMap { familyMemberVM.getTaskGroup(by: $0) }
                    let canComplete = task.status != .completed && task.status != .pendingVerification
                    let isBusy = inFlightActions.contains(taskId)
                    
                    TaskCard(
                        task: task,
                        groupName: group?.name,
                        onTap: { selectedTask = task },
                        onStartTask: {
                            guard !inFlightActions.contains(taskId) else { return }
                            inFlightActions.insert(taskId)
                            Task {
                                await familyViewModel.updateTaskStatus(task, to: .inProgress)
                                inFlightActions.remove(taskId)
                                toast = .success(L10n.taskStarted)
                            }
                        },
                        onStartFocus: {
                            focusTask = task
                        },
                        onMarkComplete: {
                            guard !inFlightActions.contains(taskId) else { return }
                            inFlightActions.insert(taskId)
                            Task {
                                await familyViewModel.updateTaskStatus(task, to: .completed, authViewModel: authViewModel)
                                inFlightActions.remove(taskId)
                                toast = .success(L10n.taskCompleted)
                            }
                        },
                        showActions: true,
                        isLoading: isBusy
                    )
                    .swipeToCompleteOrDelete(
                        canComplete: canComplete && !isBusy,
                        onComplete: {
                            guard !inFlightActions.contains(taskId) else { return }
                            inFlightActions.insert(taskId)
                            Task {
                                if task.requiresProof {
                                    selectedTask = task
                                } else {
                                    await familyViewModel.updateTaskStatus(task, to: .completed)
                                }
                                inFlightActions.remove(taskId)
                            }
                        },
                        onDelete: {
                            guard !inFlightActions.contains(taskId) else { return }
                            inFlightActions.insert(taskId)
                            Task {
                                await familyViewModel.deleteTask(task)
                                inFlightActions.remove(taskId)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
            .padding(.bottom, DS.Spacing.jumbo * 2.5)
            .constrainedWidth(.content)
        }
        .sheet(item: $focusTask) { task in
            FocusTimerView(task: task)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    let familyVM = FamilyViewModel()
    MyTasksView()
        .environment(AuthViewModel())
        .environment(familyVM)
        .environment(familyVM.familyMemberVM)
        .environment(familyVM.taskVM)
        .environment(familyVM.calendarVM)
        .environment(familyVM.habitVM)
        .environment(familyVM.notificationVM)
}
