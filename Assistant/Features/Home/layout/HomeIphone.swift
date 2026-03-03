//  HomeIphone.swift
//  FamilyHub
//
//  SIMPLIFIED HOME LAYOUT
//  - Focus Now: Top 5 priority tasks (what needs attention)
//  - Today habits (quick daily tracking)
//  - Timeline: Merged tasks + events for today/tomorrow
//  - All Tasks: Search + full task list
//  - Groups: Task organization
//
//  Empty-state inline CTAs appear when sections are empty,
//  doubling as tour targets for first-time users.

import SwiftUI

extension HomeView {
    
    // MARK: - iPhone Layout (Linear Scroll)
    
    var iPhoneLayout: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DS.Spacing.xl) {
                // Header (includes date + greeting)
                headerSection
                
                // ── Tasks Section ──
                if !derived.focusTasks.isEmpty {
                    HomeFocusNowSection(
                        tasks: derived.focusTasks,
                        groupLookup: { familyMemberVM.getTaskGroup(by: $0) },
                        onSelectTask: { selectedTask = $0 },
                        onCompleteTask: { task in
                            await familyVM.updateTaskStatus(task, to: .completed)
                        }
                    )
                    .tourTarget("home.focusNow")
                } else if derived.activeTasks.isEmpty {
                    addTaskCTA
                        .padding(.horizontal, DS.Spacing.screenH)
                }
                
                // ── Habits Section ──
                if !habitVM.habits.isEmpty {
                    QuickHabitsWidget()
                        .tourTarget("home.habitsWidget")
                        .padding(.horizontal, DS.Spacing.screenH)
                } else {
                    addHabitCTA
                        .padding(.horizontal, DS.Spacing.screenH)
                }
                
                // Calendar Permission (if needed)
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
                    .padding(.horizontal, DS.Spacing.screenH)
                }
                
                // ── Events / Timeline Section ──
                if !derived.timelineItems.isEmpty {
                    HomeTimelineSection(
                        items: derived.timelineItems,
                        groupLookup: { familyMemberVM.getTaskGroup(by: $0) },
                        memberLookup: { familyMemberVM.getMember(by: $0) },
                        onSelectTask: { selectedTask = $0 },
                        onDeleteEvent: deleteUpcomingEvent
                    )
                    .tourTarget("home.timeline")
                }
                
                if !derived.weekEvents.isEmpty {
                    HomeWeekEventsSection(
                        events: derived.weekEvents,
                        isLoading: eventKitService.isLoading,
                        onDeleteEvent: deleteUpcomingEvent
                    )
                    .tourTarget("home.upcomingEvents")
                } else if derived.timelineItems.isEmpty {
                    addEventCTA
                        .padding(.horizontal, DS.Spacing.screenH)
                }
                
                // All Tasks (search + full list) — only show when tasks exist
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
                
                // Task Groups
                if !derived.myVisibleGroups.isEmpty {
                    HomeCompactGroupsSection(
                        groups: derived.myVisibleGroups,
                        onSelectGroup: { showTaskGroup = $0 },
                        onDeleteGroup: { group in
                            await familyVM.deleteTaskGroup(group)
                        }
                    )
                }
                
                // Pending Verification (for parents)
                if !derived.myPendingVerificationTasks.isEmpty {
                    HomePendingVerificationSection(
                        tasks: derived.myPendingVerificationTasks
                    )
                }
                
                Spacer().frame(height: 120)
            }
            .padding(.top, DS.Spacing.md)
        }
        .refreshable {
            await refreshData()
        }
    }
}

// MARK: - Inline CTA (Empty State Action Card)

/// Compact inline card shown when a home section is empty.
/// Doubles as a tour target for first-time onboarding.
struct HomeInlineCTA: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonLabel: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(DS.Typography.heading())
                        .foregroundStyle(iconColor)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)
                    
                    Text(subtitle)
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 0)
            }
            
            // Action button
            Button(action: action) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(DS.Typography.labelSmall())
                    Text(buttonLabel)
                        .font(DS.Typography.label())
                }
                .foregroundStyle(.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(iconColor)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
    }
}
