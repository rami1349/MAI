// ============================================================================
// HomeIpad.swift
// REMOVED FROM iPad HOME (v1 → v2):
//   - Timeline section → absorbed into Slots 3 + 5
//   - Week Events → Calendar tab
//   - Calendar Permission prompt → Settings (Me tab)
//   - Task Groups grid → Tasks tab
//   - Full task search + list → Tasks tab
//   - Pending Verification section → becomes Action Card (Slot 2)
//
// ============================================================================

import SwiftUI

extension HomeView {

    // MARK: - iPad Layout (Two Column)

    var iPadLayout: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: layout.sectionSpacing) {

                // ── SLOT 1: Greeting + Personal Stat (full width) ──
                HomeGreetingSection(
                    userName: authVM.currentUser?.displayName ?? "",
                    stat: derived.personalStat,
                    unreadNotificationCount: notificationVM.unreadCount,
                    onNotificationsTapped: { showNotifications = true }
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

                // Two-column grid: Main content + Sidebar
                HStack(alignment: .top, spacing: DS.Spacing.xl) {

                    // ── Left Column: SLOT 3 (Focus Now) ──────────
                    VStack(spacing: DS.Spacing.xl) {
                        if !derived.focusTasks.isEmpty {
                            iPadFocusNowCard
                        } else {
                            addTaskCTA
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // ── Right Column: SLOT 4 + SLOT 5 ────────────
                    VStack(spacing: DS.Spacing.xl) {
                        // Slot 4: Habits
                        if !habitVM.habits.isEmpty {
                            QuickHabitsWidget()
                                .hoverEffect()
                                .tourTarget("home.habitsWidget")
                        } else {
                            addHabitCTA
                        }

                        // Slot 5: Events (today/tomorrow)
                        if !derived.todayTomorrowEvents.isEmpty {
                            iPadEventsCard
                        }
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
            selectedTask = task
        case .overdueTask(let task):
            selectedTask = task
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
                Circle()
                    .fill(task.priority.color)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        if task.isOverdue {
                            Text("overdue")
                                .font(DS.Typography.micro())
                                .foregroundStyle(.accentRed)
                        } else if Calendar.current.isDateInToday(task.dueDate) {
                            Text("today")
                                .font(DS.Typography.micro())
                                .foregroundStyle(.accentOrange)
                        } else {
                            Text(task.dueDate.formatted(.dateTime.weekday(.abbreviated)))
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textTertiary)
                        }

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
    }

    // MARK: - iPad Events Card (Slot 5)

    var iPadEventsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
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

            // Event rows
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

    // MARK: - iPad Event Row

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

            // Day label
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
