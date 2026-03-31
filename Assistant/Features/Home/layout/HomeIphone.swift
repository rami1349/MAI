// HomeIphone.swift
//
// v3: 8-Slot Layout + ADHD upgrades
//
// │ SLOT 1: Greeting + Progress Ring (ADHD)
// │ SLOT 2: Action Card
// │ SLOT 3: My Tasks (Focus Now)
// │ SLOT 4: My Habits (Today)
// │ SLOT 6: My Folders (NEW)
// │ SLOT 7: Other Tasks (NEW)
// │ SLOT 5: My Events (Today/Tomorrow)
// │ SLOT 8: Weekly Wins (ADHD)

import SwiftUI

extension HomeView {

    // MARK: - iPhone Layout (8-Slot Linear Scroll)

    var iPhoneLayout: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DS.Spacing.xl) {

                // ── SLOT 1: Greeting + Progress Ring ──────────
                HomeGreetingSection(
                    userName: authVM.currentUser?.displayName ?? "",
                    stat: derived.personalStat,
                    unreadNotificationCount: notificationVM.unreadCount,
                    onNotificationsTapped: { router.present(.notifications) },
                    todayCompleted: derived.todayCompletedCount,
                    todayTotal: derived.todayTotalCount
                )

                // ── SLOT 2: Action Card (conditional) ────────
                if let actionCard = derived.actionCard {
                    HomeActionCard(data: actionCard) {
                        handleActionCardTap(actionCard)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // ── SLOT 3: My Tasks (Focus Now) ──────────────
                if !derived.focusTasks.isEmpty {
                    HomeFocusNowSection(
                        tasks: derived.focusTasks,
                        groupLookup: { familyMemberVM.getTaskGroup(by: $0) },
                        onSelectTask: { router.present(.taskDetail($0)) },
                        onCompleteTask: { task in
                            await familyVM.updateTaskStatus(task, to: .completed)
                        }
                    )
                    .tourTarget("home.focusNow")
                } else {
                    addTaskCTA
                        .padding(.horizontal, DS.Spacing.screenH)
                }

                // ── SLOT 4: My Habits (Today) ─────────────────
                if !habitVM.habits.isEmpty {
                    QuickHabitsWidget()
                        .tourTarget("home.habitsWidget")
                        .padding(.horizontal, DS.Spacing.screenH)
                } else {
                    addHabitCTA
                        .padding(.horizontal, DS.Spacing.screenH)
                }
                
                // ── SLOT 6: My Folders (NEW) ──────────────────
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
                    .padding(.horizontal, DS.Spacing.screenH)
                }
                
                // ── SLOT 7: Other Tasks (NEW) ─────────────────
                if !derived.otherTasks.isEmpty {
                    HomeOtherTasksSection(
                        tasks: derived.otherTasks,
                        groups: familyMemberVM.taskGroups,
                        onSelectTask: { router.present(.taskDetail($0)) },
                        onMoveTask: { task, groupId in
                            await familyVM.moveTaskToGroup(task, groupId: groupId)
                        }
                    )
                    .padding(.horizontal, DS.Spacing.screenH)
                }

                // ── SLOT 5: My Events (Today/Tomorrow) ────────
                if !derived.todayTomorrowEvents.isEmpty {
                    HomeEventsSection(
                        events: derived.todayTomorrowEvents,
                        onSeeAll: { router.selectedTab = .calendar },
                        onDeleteEvent: deleteUpcomingEvent
                    )
                }
                
                // ── SLOT 8: Weekly Wins (ADHD) ────────────────
                HomeWeeklyWinsSection(
                    completedCount: derived.weeklyCompletedCount,
                    earnings: derived.weeklyEarningsAmount,
                    streakDays: derived.habitStreakDays
                )
                .padding(.horizontal, DS.Spacing.screenH)

                Spacer().frame(height: 120)
            }
            .padding(.top, DS.Spacing.md)
            .animation(.spring(response: 0.3), value: derived.actionCard != nil)
        }
        .refreshable {
            await refreshData()
        }
    }

    // MARK: - Action Card Tap Handler

    private func handleActionCardTap(_ card: ActionCardData) {
        switch card {
        case .reviewHomework(let task):
            router.present(.taskDetail(task))
        case .overdueTask(let task):
            router.present(.taskDetail(task))
        case .claimReward:
            break
        }
    }
}

// MARK: - Inline CTA (Empty State Action Card)

struct HomeInlineCTA: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let buttonLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(DS.Typography.heading())
                        .foregroundStyle(iconColor)
                }
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
