//
//  WeekHabitView.swift
//  FamilyHub
//
//  Week view - Clean horizontal rows with circular dots
//  Each habit shows icon + name, then 7 day dots
//

import SwiftUI

struct WeekHabitView: View {
    let habits: [Habit]
    let weekDates: [Date]
    let selectedDay: Date
    let isCompleted: (Habit, Date) -> Bool
    let onToggle: (Habit, Date) -> Void
    let onSelectDay: (Date) -> Void
    let onDelete: (Habit) -> Void
    
    private let calendar = Calendar.current
    
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Day header row
            dayHeaderRow
            
            // Habit rows
            ForEach(habits) { habit in
                WeekHabitRow(
                    habit: habit,
                    dates: weekDates,
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
    
    private var dayHeaderRow: some View {
        HStack(spacing: 0) {
            // Spacer for habit name column
            Color.clear.frame(width: 100)
            
            // Day labels
            ForEach(weekDates, id: \.self) { date in
                VStack(spacing: DS.Spacing.xxs) {
                    Text(Self.dayFormatter.string(from: date).prefix(3).uppercased())
                        .font(DS.Typography.micro())
                        .foregroundStyle(.textTertiary)
                    
                    Text("\(calendar.component(.day, from: date))")
                        .font(DS.Typography.bodySmall()).fontWeight(calendar.isDateInToday(date) ? .bold : .medium)
                        .foregroundStyle(calendar.isDateInToday(date) ? .accentPrimary : .textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Week Habit Row
struct WeekHabitRow: View {
    let habit: Habit
    let dates: [Date]
    let selectedDay: Date
    let isCompleted: (Date) -> Bool
    let onToggle: (Date) -> Void
    let onSelectDay: (Date) -> Void
    
    private var habitColor: Color { Color(hex: habit.colorHex) }
    private let calendar = Calendar.current
    
    var body: some View {
        HStack(spacing: 0) {
            // Habit info (left side)
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: habit.icon)
                    .font(.system(size: DS.IconSize.sm)) // DT-exempt: icon sizing
                    .foregroundStyle(habitColor)
                
                Text(habit.name)
                    .font(DS.Typography.labelSmall())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)
            
            // Day dots
            ForEach(dates, id: \.self) { date in
                let completed = isCompleted(date)
                let isToday = calendar.isDateInToday(date)
                let isFuture = date > Date()
                
                Button {
                    onSelectDay(date)
                    if !isFuture { onToggle(date) }
                } label: {
                    WeekDayDot(
                        isCompleted: completed,
                        isToday: isToday,
                        isFuture: isFuture,
                        color: habitColor
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
    }
}

// MARK: - Week Day Dot
struct WeekDayDot: View {
    let isCompleted: Bool
    let isToday: Bool
    let isFuture: Bool
    let color: Color
    
    private let dotSize: CGFloat = 28
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(fillColor)
                .frame(width: dotSize, height: dotSize)
            
            // Today border (black ring)
            if isToday {
                Circle()
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: dotSize, height: dotSize)
            }
            
            // Checkmark for completed
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.white)
            }
        }
    }
    
    private var fillColor: Color {
        if isCompleted {
            return color
        } else if isFuture {
            return color.opacity(0.08)
        } else {
            return color.opacity(0.15)
        }
    }
}
