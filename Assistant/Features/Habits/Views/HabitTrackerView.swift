//
//  HabitTrackerView.swift
//  FamilyHub
//
//  Adaptive habit tracker with iPad grid layout.
//  - iPhone: Vertical list of habits
//  - iPad: Grid layout with larger habit cards
//  - Hover effects, context menus
//

import SwiftUI
import UIKit

struct HabitTrackerView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel

    @Environment(HabitViewModel.self) var habitVM
    
    // MARK: - Environment
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - State
    
    @State private var selectedScope: TimeScope = .month
    @State private var currentDate = Date()
    @State private var selectedDay = Date()
    @State private var habitToDelete: Habit? = nil
    @State private var showDeleteConfirm = false
    @State private var togglingHabits: Set<String> = []
    @State private var isDeleting = false
    
    @Binding var showAddHabit: Bool
    
    // Loading state
    @State private var lastLoadedPeriodKey: String?
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    enum TimeScope: String, CaseIterable {
        case week = "week"
        case month = "month"
        case year = "year"
        
        var displayName: String {
            switch self {
            case .week: return L10n.timeScopeWeek
            case .month: return L10n.timeScopeMonth
            case .year: return L10n.timeScopeYear
            }
        }
    }
    
    private let calendar = Calendar.current
    
    private var currentPeriodKey: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay]
        return "\(selectedScope.rawValue)-\(formatter.string(from: currentDate))"
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            scopeSelector
            dateNavigation
            
            if habitVM.habits.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "repeat.circle",
                    title: L10n.noHabitsYet,
                    message: L10n.noHabitsMessage,
                    buttonTitle: L10n.addHabit,
                    buttonAction: { showAddHabit = true }
                )
                Spacer()
            } else {
                habitTrackingContent
            }
        }
        .task {
            await loadLogsForCurrentPeriodIfNeeded()
        }
        .onChange(of: currentDate) { _, _ in
            Task { await loadLogsForCurrentPeriodIfNeeded() }
        }
        .onChange(of: selectedScope) { _, newScope in
            withAnimation(.spring(response: 0.3)) {
                adjustDateForScope(newScope)
            }
            Task { await loadLogsForCurrentPeriodIfNeeded() }
        }
        .alert(L10n.deleteHabit, isPresented: $showDeleteConfirm) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.delete, role: .destructive) {
                if let habit = habitToDelete {
                    Task { await habitVM.deleteHabit(habit) }
                }
            }
        } message: {
            Text(L10n.deleteHabitConfirmation)
        }
    }
    
    // MARK: - Scope Selector
    
    private var scopeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeScope.allCases, id: \.self) { scope in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedScope = scope
                    }
                }) {
                    Text(scope.rawValue)
                        .font(DS.Typography.label())
                        .foregroundStyle(selectedScope == scope ? Color.textPrimary : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Group {
                                if selectedScope == scope {
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
        .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(Color.backgroundSecondary))
        .adaptiveHorizontalPadding()
    }
    
    // MARK: - Date Navigation
    
    private var dateNavigation: some View {
        HStack {
            Button { navigatePrevious() } label: {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .hoverEffect(scale: 1.1, highlight: .clear)
            
            Spacer()
            
            Text(periodLabel)
                .font(.subheadline)
                .foregroundStyle(Color.textPrimary)
            
            Spacer()
            
            Button { navigateNext() } label: {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .hoverEffect(scale: 1.1, highlight: .clear)
        }
        .adaptiveHorizontalPadding()
    }
    
    // MARK: - Habit Tracking Content
    
    private var habitTrackingContent: some View {
        ScrollView(showsIndicators: false) {
            if isRegularWidth {
                iPadHabitLayout
            } else {
                iPhoneHabitLayout
            }
        }
    }
    
    // MARK: - iPhone Layout
    
    private var iPhoneHabitLayout: some View {
        Group {
            switch selectedScope {
            case .week:
                WeekHabitView(
                    habits: habitVM.habits,
                    weekDates: weekDates,
                    selectedDay: selectedDay,
                    isCompleted: { habit, date in
                        habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
                    },
                    onToggle: { habit, date in
                        guardedToggle(habit: habit, date: date)
                    },
                    onSelectDay: { date in
                        withAnimation(.spring(response: 0.3)) { selectedDay = date }
                    },
                    onDelete: { habit in
                        habitToDelete = habit; showDeleteConfirm = true
                    }
                )
            case .month:
                MonthHabitView(
                    habits: habitVM.habits,
                    currentDate: currentDate,
                    selectedDay: selectedDay,
                    isCompleted: { habit, date in
                        habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
                    },
                    onToggle: { habit, date in
                        guardedToggle(habit: habit, date: date)
                    },
                    onSelectDay: { date in
                        withAnimation(.spring(response: 0.3)) { selectedDay = date }
                    },
                    onDelete: { habit in
                        habitToDelete = habit; showDeleteConfirm = true
                    }
                )
            case .year:
                YearHabitView(
                    habits: habitVM.habits,
                    currentYear: currentDate,
                    isCompleted: { habit, date in
                        habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
                    },
                    onDelete: { habit in
                        habitToDelete = habit; showDeleteConfirm = true
                    }
                )
            }
        }
    }
    
    // MARK: - iPad Layout (Grid)
    
    private var iPadHabitLayout: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Summary Stats
            iPadHabitStats
            
            // Content based on scope - same as iPhone but with iPad styling
            Group {
                switch selectedScope {
                case .week:
                    WeekHabitView(
                        habits: habitVM.habits,
                        weekDates: weekDates,
                        selectedDay: selectedDay,
                        isCompleted: { habit, date in
                            habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
                        },
                        onToggle: { habit, date in
                            guardedToggle(habit: habit, date: date)
                        },
                        onSelectDay: { date in
                            withAnimation(.spring(response: 0.3)) { selectedDay = date }
                        },
                        onDelete: { habit in
                            habitToDelete = habit; showDeleteConfirm = true
                        }
                    )
                case .month:
                    MonthHabitView(
                        habits: habitVM.habits,
                        currentDate: currentDate,
                        selectedDay: selectedDay,
                        isCompleted: { habit, date in
                            habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
                        },
                        onToggle: { habit, date in
                            guardedToggle(habit: habit, date: date)
                        },
                        onSelectDay: { date in
                            withAnimation(.spring(response: 0.3)) { selectedDay = date }
                        },
                        onDelete: { habit in
                            habitToDelete = habit; showDeleteConfirm = true
                        }
                    )
                case .year:
                    YearHabitView(
                        habits: habitVM.habits,
                        currentYear: currentDate,
                        isCompleted: { habit, date in
                            habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
                        },
                        onDelete: { habit in
                            habitToDelete = habit; showDeleteConfirm = true
                        }
                    )
                }
            }
        }
    }
    
    private var iPadHabitStats: some View {
        let todayCompleted = habitVM.habits.filter { habit in
            habitVM.isHabitCompleted(habitId: habit.id ?? "", date: Date())
        }.count
        
        let weekStreak = calculateWeekStreak()
        
        return HStack(spacing: DS.Spacing.lg) {
            iPadStatCard(
                title: "Today",
                value: "\(todayCompleted)/\(habitVM.habits.count)",
                color: Color.accentPrimary,
                icon: "checkmark.circle"
            )
            
            iPadStatCard(
                title: "This Week",
                value: "\(weekStreak) days",
                color: .accentGreen,
                icon: "flame"
            )
            
            iPadStatCard(
                title: "Total Habits",
                value: "\(habitVM.habits.count)",
                color: .accentTertiary,
                icon: "repeat"
            )
        }
        .adaptiveHorizontalPadding()
    }
    
    private func iPadStatCard(title: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
        )
    }
    
    private func iPadHabitCard(habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: habit.colorHex).opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: habit.icon)
                        .font(.title3)
                        .foregroundStyle(Color(hex: habit.colorHex))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(DS.Typography.label())
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    
                    Text(L10n.daily)
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(Color.textSecondary)
                }
                
                Spacer()
                
                // Today's completion indicator
                let isCompletedToday = habitVM.isHabitCompleted(habitId: habit.id ?? "", date: Date())
                
                Button {
                    guardedToggle(habit: habit, date: Date())
                } label: {
                    Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isCompletedToday ? Color(hex: habit.colorHex) : Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Week progress
            HStack(spacing: DS.Spacing.sm) {
                ForEach(weekDates, id: \.self) { date in
                    let isCompleted = habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
                    let isToday = calendar.isDateInToday(date)
                    
                    VStack(spacing: 4) {
                        Text(dayLetter(for: date))
                            .font(.caption2)
                            .foregroundStyle(Color.textSecondary)
                        
                        Button {
                            guardedToggle(habit: habit, date: date)
                        } label: {
                            Circle()
                                .fill(isCompleted ? Color(hex: habit.colorHex) : Color.clear)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            isCompleted ? Color.clear : Color.textTertiary,
                                            lineWidth: isToday ? 2 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Stats
            HStack {
                let completedThisWeek = weekDates.filter { date in
                    habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
                }.count
                
                Text("\(completedThisWeek)/\(weekDates.count) this week")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                
                Spacer()
                
                if completedThisWeek == weekDates.count {
                    Label(L10n.perfect, systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.accentYellow)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
        )
    }
    
    @ViewBuilder
    private func habitContextMenu(habit: Habit) -> some View {
        Button {
            guardedToggle(habit: habit, date: Date())
        } label: {
            let isCompleted = habitVM.isHabitCompleted(habitId: habit.id ?? "", date: Date())
            Label(
                isCompleted ? "Mark Incomplete" : "Mark Complete",
                systemImage: isCompleted ? "xmark.circle" : "checkmark.circle"
            )
        }
        
        Divider()
        
        Button(role: .destructive) {
            habitToDelete = habit
            showDeleteConfirm = true
        } label: {
            Label(L10n.deleteHabit, systemImage: "trash")
        }
    }
    
    // MARK: - Helpers

    private func guardedToggle(habit: Habit, date: Date) {
        let key = "\(habit.id ?? "")_\(date.timeIntervalSince1970)"
        guard !togglingHabits.contains(key) else { return }
        togglingHabits.insert(key)
        Task {
            await familyViewModel.toggleHabitCompletion(habit: habit, date: date)
            togglingHabits.remove(key)
            DS.Haptics.light()
        }
    }
    
    private var periodLabel: String {
        let formatter = DateFormatter()
        switch selectedScope {
        case .week:
            let start = currentDate.startOfWeek
            let end = calendar.date(byAdding: .day, value: 6, to: start)!
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .month:
            formatter.dateFormat = "yyyy MMM"
            return formatter.string(from: currentDate)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: currentDate)
        }
    }
    
    private var weekDates: [Date] {
        let start = currentDate.startOfWeek
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    private func calculateWeekStreak() -> Int {
        var streak = 0
        let start = currentDate.startOfWeek
        
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: start) else { continue }
            
            let allCompleted = habitVM.habits.allSatisfy { habit in
                habitVM.isHabitCompleted(habitId: habit.id ?? "", date: date)
            }
            
            if allCompleted && !habitVM.habits.isEmpty {
                streak += 1
            }
        }
        
        return streak
    }
    
    private func adjustDateForScope(_ scope: TimeScope) {
        switch scope {
        case .week: currentDate = selectedDay.startOfWeek
        case .month: currentDate = selectedDay.startOfMonth
        case .year: currentDate = selectedDay.startOfYear
        }
    }
    
    private func navigatePrevious() {
        withAnimation(.spring(response: 0.3)) {
            switch selectedScope {
            case .week: currentDate = currentDate.adding(weeks: -1)
            case .month: currentDate = currentDate.adding(months: -1)
            case .year: currentDate = calendar.date(byAdding: .year, value: -1, to: currentDate) ?? currentDate
            }
        }
    }
    
    private func navigateNext() {
        withAnimation(.spring(response: 0.3)) {
            switch selectedScope {
            case .week: currentDate = currentDate.adding(weeks: 1)
            case .month: currentDate = currentDate.adding(months: 1)
            case .year: currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
            }
        }
    }
    
    private func loadLogsForCurrentPeriodIfNeeded() async {
        let key = currentPeriodKey
        guard lastLoadedPeriodKey != key else { return }
        lastLoadedPeriodKey = key
        
        let startDate: Date
        let endDate: Date
        
        switch selectedScope {
        case .week:
            startDate = currentDate.startOfWeek
            endDate = calendar.date(byAdding: .day, value: 6, to: startDate)!
        case .month:
            startDate = currentDate.startOfMonth
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
        case .year:
            startDate = currentDate.startOfYear
            endDate = calendar.date(byAdding: .year, value: 1, to: startDate)!
        }
        
        await familyViewModel.loadHabitLogs(from: startDate, to: endDate)
    }
}

#Preview("iPhone") {
    let vm = FamilyViewModel()
    HabitTrackerView(showAddHabit: .constant(false))
        .environment(AuthViewModel())
        .environment(vm)
        .environment(vm.familyMemberVM)
        .environment(vm.taskVM)
        .environment(vm.calendarVM)
        .environment(vm.habitVM)
        .environment(vm.notificationVM)
}

#Preview("iPad") {
    let vm = FamilyViewModel()
    HabitTrackerView(showAddHabit: .constant(false))
        .environment(AuthViewModel())
        .environment(vm)
        .environment(vm.familyMemberVM)
        .environment(vm.taskVM)
        .environment(vm.calendarVM)
        .environment(vm.habitVM)
        .environment(vm.notificationVM)
}
