// HomeIpad.swift
//
// v3: 8-Slot Two-Column Layout + ADHD upgrades
//
// FULL WIDTH:
//   SLOT 1: Greeting + Progress Ring (ADHD)
//   SLOT 2: Action Card
//
// LEFT COLUMN:              RIGHT COLUMN:
//   SLOT 3: Focus Now         SLOT 4: Today's Habits
//   SLOT 6: My Folders        SLOT 5: Today & Tomorrow Events
//   SLOT 7: Other Tasks       SLOT 8: Weekly Wins (ADHD)

import SwiftUI

extension HomeView {

    // MARK: - iPad Layout (Two Column)

    var iPadLayout: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: layout.sectionSpacing) {

                // ── SLOT 1: Greeting + Progress Ring (full width) ──
                HomeGreetingSection(
                    userName: authVM.currentUser?.displayName ?? "",
                    stat: derived.personalStat,
                    unreadNotificationCount: notificationVM.unreadCount,
                    onNotificationsTapped: { router.present(.notifications) },
                    todayCompleted: derived.todayCompletedCount,
                    todayTotal: derived.todayTotalCount
                )
                .adaptiveHorizontalPadding()

                // ── SLOT 2: Action Card (full width, conditional) ──
                if let actionCard = derived.actionCard {
                    HomeActionCard(data: actionCard) {
                        handleiPadActionCardTap(actionCard)
                    }
                    .adaptiveHorizontalPadding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Two-column grid
                HStack(alignment: .top, spacing: DS.Spacing.xl) {

                    // ── Left Column ───────────────────────────
                    VStack(spacing: DS.Spacing.xl) {
                        // SLOT 3: Focus Now
                        if !derived.focusTasks.isEmpty {
                            iPadFocusNowCard
                        } else {
                            addTaskCTA
                        }
                        
                        // SLOT 6: My Folders (NEW)
                        if !derived.myVisibleGroups.isEmpty {
                            HomeGroupsSection(
                                groups: derived.myVisibleGroups,
                                onSelectGroup: { group in
                                    if let id = group.id {
                                        router.push(HomeRoute.taskGroup(id: id))
                                    }
                                },
                                onAddTask: { group in
                                    router.present(.addTask(groupId: group.id))
                                },
                                onDropTask: { stableId, groupId in
                                    if let task = taskVM.allTasks.first(where: { $0.stableId == stableId }) {
                                        await familyVM.moveTaskToGroup(task, groupId: groupId)
                                    }
                                }
                            )
                        }
                        
                        // SLOT 7: Other Tasks (NEW)
                        if !derived.otherTasks.isEmpty {
                            HomeOtherTasksSection(
                                tasks: derived.otherTasks,
                                groups: familyMemberVM.taskGroups,
                                onSelectTask: { router.present(.taskDetail($0)) },
                                onMoveTask: { task, groupId in
                                    await familyVM.moveTaskToGroup(task, groupId: groupId)
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // ── Right Column ──────────────────────────
                    VStack(spacing: DS.Spacing.xl) {
                        // SLOT 4: Habits
                        if !habitVM.habits.isEmpty {
                            QuickHabitsWidget()
                                .hoverEffect()
                                .tourTarget("home.habitsWidget")
                        } else {
                            addHabitCTA
                        }

                        // SLOT 5: Events (today/tomorrow)
                        if !derived.todayTomorrowEvents.isEmpty {
                            iPadEventsCard
                        }
                        
                        // SLOT 8: Weekly Wins (ADHD)
                        HomeWeeklyWinsSection(
                            completedCount: derived.weeklyCompletedCount,
                            earnings: derived.weeklyEarningsAmount,
                            streakDays: derived.habitStreakDays
                        )
                    }
                    .frame(width: 360)
                }
                .adaptiveHorizontalPadding()

                Spacer().frame(height: 40)
            }
            .padding(.top, DS.Spacing.md)
            .animation(.spring(response: 0.3), value: derived.actionCard != nil)
        }
        .refreshable {
            await refreshData()
        }
    }

    // MARK: - Action Card Tap (iPad)

    private func handleiPadActionCardTap(_ card: ActionCardData) {
        switch card {
        case .reviewHomework(let task):
            router.present(.taskDetail(task))
        case .overdueTask(let task):
            router.present(.taskDetail(task))
        case .claimReward:
            break
        }
    }

    // MARK: - iPad Focus Now Card

    var iPadFocusNowCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "target")
                    .font(DS.Typography.label())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )

                Text("focus_now")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)

                Text("\(derived.focusTasks.count)")
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.accentPrimary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )

                Spacer()
            }

            // Tasks grid (adaptive: 2 columns on wide, 1 column when narrow)
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 260), spacing: DS.Spacing.md)
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
            router.present(.taskDetail(task))
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(task.priority.color)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        Text(relativeTaskDate(task))
                            .font(DS.Typography.micro())
                            .foregroundStyle(taskDateColor(task))

                        if let time = task.scheduledTime {
                            Text("·")
                                .foregroundStyle(.textTertiary)
                            Text(time.formatted(.dateTime.hour().minute()))
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }

                Spacer()

                if task.hasReward, let amount = task.rewardAmount {
                    Text(amount.currencyString)
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.accentGreen)
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(task.isOverdue ? Color.accentRed.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .draggable(task)
        .contextMenu {
            Button {
                router.present(.taskDetail(task))
            } label: {
                Label("view_details", systemImage: "eye")
            }
            
            if !familyMemberVM.taskGroups.isEmpty {
                MoveToFolderMenu(
                    task: task,
                    groups: familyMemberVM.taskGroups
                ) { task, groupId in
                    await familyVM.moveTaskToGroup(task, groupId: groupId)
                }
            }
        }
    }
    
    // MARK: - ADHD: Relative time helpers
    
    func relativeTaskDate(_ task: FamilyTask) -> String {
        if task.isOverdue {
            return AppStrings.localized("overdue")
        }
        if Calendar.current.isDateInToday(task.dueDate) {
            return AppStrings.localized("today")
        }
        if Calendar.current.isDateInTomorrow(task.dueDate) {
            return AppStrings.localized("tomorrow")
        }
        return task.dueDate.formatted(.dateTime.weekday(.abbreviated))
    }
    
    func taskDateColor(_ task: FamilyTask) -> Color {
        if task.isOverdue { return .accentRed }
        if Calendar.current.isDateInToday(task.dueDate) { return .accentOrange }
        return .textTertiary
    }

    // MARK: - iPad Events Card (Slot 5)

    var iPadEventsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )

                Text("today_tomorrow_events")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)

                Spacer()
            }

            VStack(spacing: DS.Spacing.xs) {
                ForEach(derived.todayTomorrowEvents) { event in
                    iPadEventRow(event: event)
                        .hoverEffect(scale: 1.01)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
    }

    func iPadEventRow(event: UpcomingEvent) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)

            Image(systemName: event.icon)
                .font(DS.Typography.bodySmall())
                .foregroundStyle(event.color)
                .frame(width: 20)

            Text(event.title)
                .font(DS.Typography.body())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)

            Spacer()

            Text(event.daysUntil == 0
                 ? AppStrings.localized("today")
                 : AppStrings.localized("tomorrow"))
                .font(DS.Typography.captionMedium())
                .foregroundStyle(event.daysUntil == 0 ? .textOnAccent : .accentPrimary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(event.daysUntil == 0
                              ? event.color
                              : Color.accentPrimary.opacity(0.1))
                )
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
