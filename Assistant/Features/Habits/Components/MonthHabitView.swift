//
//  MonthHabitView.swift
//
//
//  Month view - Calendar grid cards for each habit
//  Each card has: habit name + icon, calendar grid with squares, completion count
//

import SwiftUI

struct MonthHabitView: View {
    let habits: [Habit]
    let currentDate: Date
    let selectedDay: Date
    let isCompleted: (Habit, Date) -> Bool
    let onToggle: (Habit, Date) -> Void
    let onSelectDay: (Date) -> Void
    let onDelete: (Habit) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(habits) { habit in
                MonthHabitCard(
                    habit: habit,
                    currentDate: currentDate,
                    selectedDay: selectedDay,
                    isCompleted: { date in isCompleted(habit, date) },
                    onToggle: { date in onToggle(habit, date) },
                    onSelectDay: onSelectDay
                )
                .swipeToDelete { onDelete(habit) }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Avatar.xl + DS.Spacing.xl)
    }
}

// MARK: - Month Habit Card
struct MonthHabitCard: View {
    let habit: Habit
    let currentDate: Date
    let selectedDay: Date
    let isCompleted: (Date) -> Bool
    let onToggle: (Date) -> Void
    let onSelectDay: (Date) -> Void
    
    private let calendar = Calendar.current
    private var habitColor: Color { Color(hex: habit.colorHex) }
    
    // Generate calendar grid data
    private var calendarGrid: [[Date?]] {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate)) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 30
        
        var grid: [[Date?]] = []
        var currentDay = 1
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var week: [Date?] = Array(repeating: nil, count: leadingEmpty)
        
        while currentDay <= daysInMonth {
            if week.count == 7 {
                grid.append(week)
                week = []
            }
            week.append(calendar.date(byAdding: .day, value: currentDay - 1, to: startOfMonth))
            currentDay += 1
        }
        
        while week.count < 7 { week.append(nil) }
        grid.append(week)
        
        return grid
    }
    
    // Count completed days
    private var completedCount: Int {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate)) else {
            return 0
        }
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 30
        
        var count = 0
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: startOfMonth),
               date <= Date(),
               isCompleted(date) {
                count += 1
            }
        }
        return count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header: Icon + Name
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: habit.icon)
                    .font(.system(size: DS.IconSize.sm)) // DT-exempt: icon sizing
                    .foregroundStyle(habitColor)
                
                Text(habit.name)
                    .font(DS.Typography.labelSmall())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Calendar Grid
            VStack(spacing: 2) {
                // Day labels
                HStack(spacing: 2) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar weeks
                ForEach(Array(calendarGrid.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 2) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                            if let date = date {
                                CalendarSquare(
                                    date: date,
                                    isCompleted: isCompleted(date),
                                    isToday: calendar.isDateInToday(date),
                                    isFuture: date > Date(),
                                    color: habitColor
                                )
                                .onTapGesture {
                                    onSelectDay(date)
                                    if date <= Date() { onToggle(date) }
                                }
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            
            // Footer: Completion count
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.micro())
                    .foregroundStyle(habitColor)
                
                Text("\(completedCount) \(String(localized: "completed"))")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textSecondary)
                
                Spacer()
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
    }
}

// MARK: - Calendar Square
struct CalendarSquare: View {
    let date: Date
    let isCompleted: Bool
    let isToday: Bool
    let isFuture: Bool
    let color: Color
    
    var body: some View {
        ZStack {
            // Square background
            RoundedRectangle(cornerRadius: 3)
                .fill(fillColor)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            
            // Today indicator (black border)
            if isToday {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.primary, lineWidth: 1.5)
            }
            
            // Checkmark for completed
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textOnAccent)
            }
        }
    }
    
    private var fillColor: Color {
        if isCompleted {
            return color
        } else if isFuture {
            return color.opacity(0.05)
        } else {
            return color.opacity(0.1)
        }
    }
}
