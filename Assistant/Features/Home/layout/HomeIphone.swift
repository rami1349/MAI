// ============================================================================
// HomeIphone.swift
//
// iPhone Home Layout (6 slots, streamlined)
//
// │ SLOT 1: Greeting + Progress + Weekly Wins (merged)
// │ SLOT 2: Action Card (conditional)
// │ SLOT 3: Focus Now tasks
// │ SLOT 4: Habits + Events (side-by-side)
// │ SLOT 5: Folders (Finder cards)
// │ SLOT 6: Other Tasks
//
// ============================================================================

import SwiftUI

extension HomeView {
    
    // MARK: - iPhone Layout
    
    var iPhoneLayout: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DS.Spacing.xl) {
                
                // ── SLOT 1: Greeting + Weekly Wins ────────────
                HomeGreetingSection(
                    userName: authVM.currentUser?.displayName ?? "",
                    stat: derived.personalStat,
                    unreadNotificationCount: notificationVM.unreadCount,
                    onNotificationsTapped: { router.present(.notifications) },
                    todayCompleted: derived.todayCompletedCount,
                    todayTotal: derived.todayTotalCount,
                    weeklyCompletedCount: derived.weeklyCompletedCount,
                    weeklyEarnings: derived.weeklyEarningsAmount,
                    habitStreakDays: derived.habitStreakDays
                )
                
                // ── SLOT 2: Action Card (conditional) ────────
                if let actionCard = derived.actionCard {
                    HomeActionCard(data: actionCard) {
                        handleActionCardTap(actionCard)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // ── SLOT 3: Focus Now ────────────────────────
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
                
                // ── SLOT 4: Habits + Events (side-by-side) ───
                habitsAndEventsRow
                    .padding(.horizontal, DS.Spacing.screenH)
                
                // ── SLOT 5: Folders (Finder cards) ───────────
                if !derived.myVisibleGroups.isEmpty {
                    HomeGroupsSection(
                        groups: derived.myVisibleGroups,
                        onSelectGroup: { group in
                            if let id = group.id {
                                router.push(HomeRoute.taskGroup(id: id))
                            }
                        },
                        onDropTask: { stableId, groupId in
                            if let task = taskVM.allTasks.first(where: { $0.stableId == stableId }) {
                                await familyVM.moveTaskToGroup(task, groupId: groupId)
                            }
                        }
                    )
                }
                
                // ── SLOT 6: Other Tasks ──────────────────────
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
                
                Spacer().frame(height: 120)
            }
            .padding(.top, DS.Spacing.md)
            .animation(.spring(response: 0.3), value: derived.actionCard != nil)
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - Habits + Events Side-by-Side
    
    @ViewBuilder
    private var habitsAndEventsRow: some View {
        let hasHabits = !habitVM.habits.isEmpty
        let hasEvents = !derived.todayTomorrowEvents.isEmpty
        
        if hasHabits || hasEvents {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                // Left: Habits
                if hasHabits {
                    compactHabitsCard
                } else {
                    addHabitCTA
                }
                
                // Right: Events
                if hasEvents {
                    compactEventsCard
                } else {
                    addEventCTA
                }
            }
        } else {
            // Both empty — show CTAs
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                addHabitCTA
                addEventCTA
            }
        }
    }
    
    // MARK: - Compact Habits Card
    
    private var compactHabitsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.accentOrange)
                
                Text("habits")
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                let done = habitVM.todayCompletedHabitCount(habits: habitVM.habits)
                let total = habitVM.habits.count
                Text("\(done)/\(total)")
                    .font(DS.Typography.micro())
                    .foregroundStyle(done == total ? .accentGreen : .textTertiary)
            }
            
            // Habit rows (max 3)
            VStack(spacing: DS.Spacing.xs) {
                ForEach(Array(habitVM.habits.prefix(3))) { habit in
                    compactHabitRow(habit)
                }
            }
            
            // "More" if > 3
            if habitVM.habits.count > 3 {
                Text("+\(habitVM.habits.count - 3) \(String(localized: "more"))")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
        .tourTarget("home.habitsWidget")
    }
    
    private func compactHabitRow(_ habit: Habit) -> some View {
        let isCompleted = habitVM.isHabitCompleted(habitId: habit.id ?? "", date: .now)
        let habitColor = Color(hex: habit.colorHex)
        
        return Button {
            Task {
                await familyVM.toggleHabitCompletion(habit: habit, date: .now)
                DS.Haptics.light()
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                // Color dot / check
                ZStack {
                    Circle()
                        .stroke(habitColor, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if isCompleted {
                        Circle()
                            .fill(habitColor)
                            .frame(width: 18, height: 18)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                Text(habit.name)
                    .font(DS.Typography.caption())
                    .foregroundStyle(isCompleted ? .textTertiary : .textPrimary)
                    .lineLimit(1)
                    .strikethrough(isCompleted)
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Compact Events Card
    
    private var compactEventsCard: some View {
        let events = Array(derived.todayTomorrowEvents.prefix(3))
        
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(.accentPrimary)
                
                Text("events")
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                Button(action: { router.selectedTab = .calendar }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.textTertiary)
                }
            }
            
            // Event rows
            VStack(spacing: DS.Spacing.xs) {
                ForEach(events) { event in
                    compactEventRow(event)
                }
            }
            
            // "More" if > 3
            if derived.todayTomorrowEvents.count > 3 {
                Text("+\(derived.todayTomorrowEvents.count - 3) \(String(localized: "more"))")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
    }
    
    private func compactEventRow(_ event: UpcomingEvent) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 3, height: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                
                Text(event.date.formatted(date: .omitted, time: .shortened))
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Action Card Tap
    
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
                Image(systemName: icon)
                    .font(DS.Typography.heading())
                    .foregroundStyle(iconColor)
                
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
