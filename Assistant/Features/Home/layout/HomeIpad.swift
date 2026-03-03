//
//  HomeIpad.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//
//  SIMPLIFIED HOME LAYOUT - iPad
//  - Two-column layout maintained for wide screens
//  - Focus Now: Top priority tasks
//  - Timeline: Merged tasks + events
//  - All Tasks: Search + full list
//  - Groups: Task organization
//
//  Removed: Progress summary card (redundant)
//

import SwiftUI

extension HomeView {
    
    // MARK: - iPad Layout (Two Column)
    
    var iPadLayout: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: layout.sectionSpacing) {
                // Header (includes date + greeting)
                headerSection
                    .adaptiveHorizontalPadding()
                
                // Two-column grid
                HStack(alignment: .top, spacing: DS.Spacing.xl) {
                    // Left Column - Main Content
                    VStack(spacing: DS.Spacing.xl) {
                        // Focus Now
                        if !derived.focusTasks.isEmpty {
                            iPadFocusNowCard
                        } else if derived.activeTasks.isEmpty {
                            addTaskCTA
                        }
                        
                        // Task List — only show when tasks exist
                        if !derived.activeTasks.isEmpty || !derived.completedTasks.isEmpty {
                            HomeUnifiedTaskList(
                                tasks: derived.displayedTasks,
                                totalActive: derived.activeTasks.count,
                                completedCount: derived.completedTasks.count,
                                searchText: $derived.searchText,
                                showCompleted: $derived.showCompleted,
                                isSearchActive: !derived.searchText.isEmpty,
                                groupLookup: { familyMemberVM.getTaskGroup(by: $0) },
                                memberLookup: { familyMemberVM.getMember(by: $0) },
                                onSelectTask: { selectedTask = $0 },
                                onCompleteTask: { task in
                                    await familyVM.updateTaskStatus(task, to: .completed)
                                },
                                onDeleteTask: { task in
                                    await familyVM.deleteTask(task)
                                }
                            )
                        }
                        
                        // Task Groups Grid (2 columns on iPad)
                        if !derived.myVisibleGroups.isEmpty {
                            iPadTaskGroupsGrid
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Column - Sidebar Widgets
                    VStack(spacing: DS.Spacing.xl) {
                        // Habits Widget
                        if !habitVM.habits.isEmpty {
                            QuickHabitsWidget()
                                .hoverEffect()
                                .tourTarget("home.habitsWidget")
                        } else {
                            addHabitCTA
                        }
                        
                        // Calendar Permission
                        if eventKitService.authStatus == .denied || eventKitService.authStatus == .notDetermined {
                            CalendarPermissionPrompt(
                                authStatus: eventKitService.authStatus,
                                onRequestAccess: {
                                    Task {
                                        await eventKitService.requestAccessIfNeeded()
                                        await eventKitService.loadEvents()
                                    }
                                }
                            )
                        }
                        
                        // Timeline: Today & Tomorrow
                        if !derived.timelineItems.isEmpty {
                            iPadTimelineCard
                        }
                        
                        // Week Events (2-7 days out)
                        if !derived.weekEvents.isEmpty {
                            iPadWeekEventsCard
                        } else if derived.timelineItems.isEmpty {
                            addEventCTA
                        }
                        
                        // Pending Verification
                        if !derived.myPendingVerificationTasks.isEmpty {
                            iPadPendingVerificationCard
                        }
                    }
                    .frame(width: 360)
                }
                .adaptiveHorizontalPadding()
                
                Spacer().frame(height: 40)
            }
            .padding(.top, DS.Spacing.md)
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - iPad Focus Now Card
    
    var iPadFocusNowCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text("Focus Now")
                    .font(DS.Typography.subheading())
                    .foregroundColor(Color.textPrimary)
                
                Text("\(derived.focusTasks.count)")
                    .font(DS.Typography.captionMedium())
                    .foregroundColor(Color.accentPrimary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Spacer()
            }
            
            // Tasks grid (2 columns for iPad)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DS.Spacing.md),
                GridItem(.flexible(), spacing: DS.Spacing.md)
            ], spacing: DS.Spacing.sm) {
                ForEach(derived.focusTasks, id: \.stableId) { task in
                    iPadFocusTaskCard(task: task)
                }
            }
        }
        .tourTarget("home.focusNow")
    }
    
    func iPadFocusTaskCard(task: FamilyTask) -> some View {
        Button {
            selectedTask = task
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Priority indicator
                Circle()
                    .fill(task.priority.color)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(DS.Typography.label())
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: DS.Spacing.xs) {
                        if task.isOverdue {
                            Text("Overdue")
                                .font(DS.Typography.micro())
                                .foregroundColor(.accentRed)
                        } else if Calendar.current.isDateInToday(task.dueDate) {
                            Text("Today")
                                .font(DS.Typography.micro())
                                .foregroundColor(.accentOrange)
                        } else {
                            Text(task.dueDate.formatted(.dateTime.weekday(.abbreviated)))
                                .font(DS.Typography.micro())
                                .foregroundColor(Color.textTertiary)
                        }
                        
                        if let time = task.scheduledTime {
                            Text("•")
                                .foregroundColor(Color.textTertiary)
                            Text(time.formatted(.dateTime.hour().minute()))
                                .font(DS.Typography.micro())
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(task.isOverdue ? Color.accentRed.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
    
    // MARK: - iPad Timeline Card
    
    var iPadTimelineCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundColor(Color.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text("Today & Tomorrow")
                    .font(DS.Typography.subheading())
                    .foregroundColor(Color.textPrimary)
                
                Text("\(derived.timelineItems.count)")
                    .font(DS.Typography.captionMedium())
                    .foregroundColor(Color.accentPrimary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Spacer()
            }
            
            // Timeline items
            VStack(spacing: DS.Spacing.xs) {
                ForEach(derived.timelineItems.prefix(6)) { item in
                    iPadTimelineRow(item: item)
                }
                
                if derived.timelineItems.count > 6 {
                    Text("+\(derived.timelineItems.count - 6) more")
                        .font(DS.Typography.captionMedium())
                        .foregroundColor(Color.accentPrimary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, DS.Spacing.xs)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .tourTarget("home.timeline")
    }
    
    @ViewBuilder
    func iPadTimelineRow(item: TimelineItem) -> some View {
        switch item {
        case .task(let task):
            Button {
                selectedTask = task
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    // Time
                    Text(task.scheduledTime?.formatted(.dateTime.hour().minute()) ?? "--:--")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.textSecondary)
                        .frame(width: 44, alignment: .leading)
                    
                    Circle()
                        .fill(task.status.color)
                        .frame(width: 6, height: 6)
                    
                    Text(task.title)
                        .font(DS.Typography.bodySmall())
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "checklist")
                        .font(.system(size: 10))
                        .foregroundColor(Color.textTertiary)
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .buttonStyle(.plain)
            
        case .event(let event):
            HStack(spacing: DS.Spacing.sm) {
                Text(event.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .frame(width: 44, alignment: .leading)
                
                Circle()
                    .fill(event.color)
                    .frame(width: 6, height: 6)
                
                Text(event.title)
                    .font(DS.Typography.bodySmall())
                    .foregroundColor(Color.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: event.icon)
                    .font(.system(size: 10))
                    .foregroundColor(event.color)
            }
            .padding(.vertical, DS.Spacing.xs)
        }
    }
    
    // MARK: - iPad Task Groups Grid
    
    var iPadTaskGroupsGrid: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text(L10n.taskGroups)
                    .font(DS.Typography.subheading())
                    .foregroundColor(Color.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DS.Spacing.md),
                GridItem(.flexible(), spacing: DS.Spacing.md)
            ], spacing: DS.Spacing.md) {
                ForEach(derived.myVisibleGroups) { group in
                    iPadGroupCard(group: group)
                        .contextMenu {
                            Button {
                                showTaskGroup = group
                            } label: {
                                Label(L10n.openGroup, systemImage: "folder")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                Task {
                                    await familyVM.deleteTaskGroup(group)
                                }
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                }
            }
        }
        .tourTarget("home.taskGroups")
    }
    
    // MARK: - iPad Group Card
    
    func iPadGroupCard(group: TaskGroup) -> some View {
        Button {
            showTaskGroup = group
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: group.color).opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: group.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: group.color))
                }
                
                // Content
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(group.name)
                        .font(DS.Typography.label())
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(group.taskCount) tasks")
                        .font(DS.Typography.caption())
                        .foregroundColor(Color.textTertiary)
                }
                
                Spacer()
                
                // Progress
                if group.taskCount > 0 {
                    CircularProgressView(progress: group.completionPercentage / 100)
                        .frame(width: 32, height: 32)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(Color.themeCardBackground)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
    
    // MARK: - iPad Week Events Card
    
    var iPadWeekEventsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(Color.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text("This Week")
                    .font(DS.Typography.subheading())
                    .foregroundColor(Color.textPrimary)
                
                Text("\(derived.weekEvents.count)")
                    .font(DS.Typography.captionMedium())
                    .foregroundColor(Color.accentPrimary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Spacer()
            }
            
            // Content
            VStack(spacing: DS.Spacing.xs) {
                ForEach(derived.weekEvents.prefix(5)) { event in
                    iPadEventRow(event: event)
                        .hoverEffect(scale: 1.01)
                }
                
                if derived.weekEvents.count > 5 {
                    Text("+\(derived.weekEvents.count - 5) more")
                        .font(DS.Typography.captionMedium())
                        .foregroundColor(Color.accentPrimary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, DS.Spacing.xs)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .tourTarget("home.upcomingEvents")
    }
    
    // MARK: - iPad Event Row
    
    func iPadEventRow(event: UpcomingEvent) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)
            
            Image(systemName: event.icon)
                .font(.system(size: 12))
                .foregroundColor(event.color)
                .frame(width: 20)
            
            Text(event.title)
                .font(DS.Typography.body())
                .foregroundColor(Color.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            Text(event.countdownText)
                .font(DS.Typography.captionMedium())
                .foregroundColor(event.daysUntil <= 2 ? .white : Color.accentPrimary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(event.daysUntil <= 2 ? event.color : Color.accentPrimary.opacity(0.1))
                )
        }
        .padding(.vertical, DS.Spacing.xs)
    }
    
    // MARK: - iPad Pending Verification Card
    
    var iPadPendingVerificationCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 14))
                    .foregroundColor(Color.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text(L10n.awaitingVerification)
                    .font(DS.Typography.subheading())
                    .foregroundColor(Color.textPrimary)
                
                Circle()
                    .fill(Color.accentPrimary)
                    .frame(width: 8, height: 8)
                
                Spacer()
            }
            
            VStack(spacing: DS.Spacing.sm) {
                ForEach(derived.myPendingVerificationTasks.prefix(3), id: \.id) { task in
                    PendingVerificationCard(task: task)
                        .hoverEffect(scale: 1.01)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Task Priority Color Extension

private extension FamilyTask.TaskPriority {
    var color: Color {
        switch self {
        case .urgent: return .accentRed
        case .high: return .accentOrange
        case .medium: return Color.accentPrimary
        case .low: return Color.textTertiary
        }
    }
}

// MARK: - Task Status Color Extension

private extension FamilyTask.TaskStatus {
    var color: Color {
        switch self {
        case .todo: return .statusTodo
        case .inProgress: return Color.statusInProgress
        case .pendingVerification: return Color.statusPending
        case .completed: return .statusCompleted
        }
    }
}
