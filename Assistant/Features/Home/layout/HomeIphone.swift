// HomeIphone.swift
//

// REMOVED FROM HOME (v1 → v2):
//   - Timeline section → absorbed into Slots 3 + 5
//   - Week Events → Calendar tab
//   - Calendar Permission prompt → Settings (Me tab)
//   - Task Groups grid → Tasks tab
//   - Full task search → Tasks tab
//   - Pending Verification section → becomes Action Card (Slot 2)
//

import SwiftUI

extension HomeView {

    // MARK: - iPhone Layout (5-Slot Linear Scroll)

    var iPhoneLayout: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DS.Spacing.xl) {

                // ── SLOT 1: Greeting + Personal Stat ─────────────
                HomeGreetingSection(
                    userName: authVM.currentUser?.displayName ?? "",
                    stat: derived.personalStat,
                    unreadNotificationCount: notificationVM.unreadCount,
                    onNotificationsTapped: { showNotifications = true }
                )

                // ── SLOT 2: Action Card (conditional) ────────────
                if let actionCard = derived.actionCard {
                    HomeActionCard(data: actionCard) {
                        handleActionCardTap(actionCard)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // ── SLOT 3: My Tasks (Focus Now) ─────────────────
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
                } else {
                    addTaskCTA
                        .padding(.horizontal, DS.Spacing.screenH)
                }

                // ── SLOT 4: My Habits (Today) ────────────────────
                if !habitVM.habits.isEmpty {
                    QuickHabitsWidget()
                        .tourTarget("home.habitsWidget")
                        .padding(.horizontal, DS.Spacing.screenH)
                } else {
                    addHabitCTA
                        .padding(.horizontal, DS.Spacing.screenH)
                }

                // ── SLOT 5: My Events (Today/Tomorrow) ───────────
                if !derived.todayTomorrowEvents.isEmpty {
                    HomeEventsSection(
                        events: derived.todayTomorrowEvents,
                        onSeeAll: {
                            // Navigate to Calendar tab
                            // Parent view handles this via tab selection binding
                        },
                        onDeleteEvent: deleteUpcomingEvent
                    )
                }

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
            selectedTask = task
        case .overdueTask(let task):
            selectedTask = task
        case .claimReward:
            break
        }
    }
}

// MARK: - Inline CTA (Empty State Action Card)

/// Compact inline card shown when a home section is empty.
/// Doubles as a tour target for first-time onboarding.
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
