// ============================================================================
// MyTasksView.swift
//
// v2: PURE TASK EXECUTION
//
// Three columns: To Do · In Progress · Done
//
// WHAT CHANGED (v1 → v2):
//   - Search bar added (blueprint §6.2)
//   - Filter chips: All / Assigned to me / Created by me + group chips
//   - .pendingVerification → shows in To Do (blueprint §6)
//   - camelCase keys → snake_case matching xcstrings
//   - Removed: TasksViewMode, habits toggle
//   - Uses existing FilterChip / IconFilterChip components
//
// ============================================================================

import SwiftUI

struct MyTasksView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM

    // MARK: - State

    @State private var selectedStatus: TaskStatusFilter = .todo
    @State private var selectedOwnership: OwnershipFilter = .all
    @State private var selectedGroupId: String? = nil
    @State private var searchText = ""
    @State private var selectedTask: FamilyTask? = nil
    @State private var focusTask: FamilyTask? = nil
    @State private var inFlightActions: Set<String> = []
    @State private var toast: ToastMessage? = nil
    @State private var showCreateGroup = false
    @State private var showGroupDetail: TaskGroup? = nil

    // MARK: - Status Filter (3-state)

    enum TaskStatusFilter: CaseIterable {
        case todo
        case inProgress
        case done

        var label: String {
            switch self {
            case .todo:       AppStrings.localized("todo")
            case .inProgress: AppStrings.localized("in_progress")
            case .done:       AppStrings.localized("done")
            }
        }
    }

    // MARK: - Ownership Filter

    enum OwnershipFilter: CaseIterable {
        case all
        case assignedToMe
        case createdByMe

        var label: String {
            switch self {
            case .all:          AppStrings.localized("all")
            case .assignedToMe: AppStrings.localized("assigned_to_me")
            case .createdByMe:  AppStrings.localized("created_by_me")
            }
        }
    }

    // MARK: - Derived Data

    private var userId: String {
        authViewModel.currentUser?.id ?? ""
    }

    /// All tasks the user is involved with.
    private var allMyTasks: [FamilyTask] {
        taskVM.tasksFor(userId: userId)
    }

    /// Task groups visible to this user (created by me OR containing my tasks).
    private var visibleGroups: [TaskGroup] {
        let userId = self.userId
        let myGroupIds = Set(allMyTasks.compactMap { $0.groupId })
        return familyMemberVM.taskGroups.filter { group in
            guard let gid = group.id else { return false }
            return group.createdBy == userId || myGroupIds.contains(gid)
        }
    }

    /// Fully filtered: status → ownership → group → search.
    private var filteredTasks: [FamilyTask] {
        var tasks = allMyTasks

        // 1. Status
        switch selectedStatus {
        case .todo:
            tasks = tasks.filter { $0.status == .todo || $0.status == .pendingVerification }
        case .inProgress:
            tasks = tasks.filter { $0.status == .inProgress }
        case .done:
            tasks = tasks.filter { $0.status == .completed }
        }

        // 2. Ownership
        switch selectedOwnership {
        case .all: break
        case .assignedToMe:
            tasks = tasks.filter { $0.isAssigned(to: userId) }
        case .createdByMe:
            tasks = tasks.filter { $0.assignedBy == userId }
        }

        // 3. Group
        if let groupId = selectedGroupId {
            tasks = tasks.filter { $0.groupId == groupId }
        }

        // 4. Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            tasks = tasks.filter { task in
                task.title.lowercased().contains(query) ||
                (task.description?.lowercased().contains(query) == true) ||
                assigneeName(for: task).lowercased().contains(query) ||
                groupName(for: task).lowercased().contains(query)
            }
        }

        // Sort: overdue first, then by due date
        return tasks.sorted { lhs, rhs in
            if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue }
            return lhs.dueDate < rhs.dueDate
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            statusFilterSection
            filterChipsSection

            if taskVM.isLoading {
                skeletonList
            } else if filteredTasks.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "checklist",
                    title: "no_tasks",
                    message: "no_tasks_filter"
                )
                Spacer()
            } else {
                tasksList
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateTaskGroupView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(item: $showGroupDetail) { group in
            NavigationStack {
                TaskGroupDetailView(taskGroup: group)
            }
            .presentationBackground(Color.themeSurfacePrimary)
        }
        .toastBanner(item: $toast)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(DS.Typography.body())
                .foregroundStyle(.textTertiary)

            TextField("search_tasks", text: $searchText)
                .font(DS.Typography.body())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textTertiary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
        .padding(.bottom, DS.Spacing.md)
    }

    // MARK: - Status Filter (3-state toggle)

    private var statusFilterSection: some View {
        HStack(spacing: 0) {
            ForEach(TaskStatusFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedStatus = filter
                    }
                } label: {
                    Text(filter.label)
                        .font(DS.Typography.label())
                        .foregroundStyle(selectedStatus == filter ? .textPrimary : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Group {
                                if selectedStatus == filter {
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

    // MARK: - Filter Toolbar (Ownership + Folder Pickers)

    private var filterChipsSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Ownership picker
            Menu {
                ForEach(OwnershipFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedOwnership = filter
                        }
                    } label: {
                        if selectedOwnership == filter {
                            Label(filter.label, systemImage: "checkmark")
                        } else {
                            Text(filter.label)
                        }
                    }
                }
            } label: {
                PickerPill(
                    icon: "person.fill",
                    text: selectedOwnership.label
                )
            }

            // Folder picker
            Menu {
                // "All Folders" option
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedGroupId = nil
                    }
                } label: {
                    if selectedGroupId == nil {
                        Label(String(localized: "all_folders"), systemImage: "checkmark")
                    } else {
                        Text(String(localized: "all_folders"))
                    }
                }

                if !visibleGroups.isEmpty {
                    Divider()

                    ForEach(visibleGroups, id: \.id) { group in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedGroupId = selectedGroupId == group.id ? nil : group.id
                            }
                        } label: {
                            Label {
                                Text(group.name)
                            } icon: {
                                Image(systemName: selectedGroupId == group.id ? "checkmark" : group.icon)
                            }
                        }
                    }
                }

                Divider()

                Button {
                    showCreateGroup = true
                } label: {
                    Label(String(localized: "new_group"), systemImage: "folder.badge.plus")
                }
            } label: {
                PickerPill(
                    icon: "folder.fill",
                    text: selectedGroupId.flatMap { id in
                        visibleGroups.first { $0.id == id }?.name
                    } ?? String(localized: "all_folders")
                )
            }

            Spacer()
        }
        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
        .padding(.bottom, DS.Spacing.md)
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
                                toast = .success(AppStrings.localized("task_started"))
                            }
                        },
                        onStartFocus: { focusTask = task },
                        onMarkComplete: {
                            guard !inFlightActions.contains(taskId) else { return }
                            inFlightActions.insert(taskId)
                            Task {
                                await familyViewModel.updateTaskStatus(task, to: .completed, authViewModel: authViewModel)
                                inFlightActions.remove(taskId)
                                toast = .success(AppStrings.localized("task_completed"))
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

    // MARK: - Skeleton

    private var skeletonList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    TaskCardSkeleton()
                }
            }
            .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
            .constrainedWidth(.content)
        }
    }

    // MARK: - Helpers

    private func assigneeName(for task: FamilyTask) -> String {
        guard let id = task.assignedTo else { return "" }
        return familyMemberVM.getMember(by: id)?.displayName ?? ""
    }

    private func groupName(for task: FamilyTask) -> String {
        guard let id = task.groupId else { return "" }
        return familyMemberVM.getTaskGroup(by: id)?.name ?? ""
    }
}

// MARK: - Picker Pill (compact dropdown trigger)

private struct PickerPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.accentPrimary)

            Text(text)
                .font(DS.Typography.captionMedium())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9))
                .foregroundStyle(.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            Capsule()
                .fill(Color.themeCardBackground)
        )
        .overlay(
            Capsule()
                .stroke(Color.themeCardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    let familyVM = FamilyViewModel()
    NavigationStack {
        MyTasksView()
            .environment(AuthViewModel())
            .environment(familyVM)
            .environment(familyVM.familyMemberVM)
            .environment(familyVM.taskVM)
            .environment(familyVM.calendarVM)
            .environment(familyVM.habitVM)
            .environment(familyVM.notificationVM)
    }
}
