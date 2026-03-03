//
//  YearHabitView.swift
//  FamilyHub
//
//  Year view - Horizontal bar chart showing 12 monthly completion rates
//  Each habit card shows name and 12 monthly bars with intensity
//

import SwiftUI

struct YearHabitView: View {
    let habits: [Habit]
    let currentYear: Date
    let isCompleted: (Habit, Date) -> Bool
    let onDelete: (Habit) -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(habits) { habit in
                YearHabitBarCard(
                    habit: habit,
                    currentYear: currentYear,
                    isCompleted: { date in isCompleted(habit, date) }
                )
                .swipeToDelete { onDelete(habit) }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Avatar.xl + DS.Spacing.xl)
    }
}

// MARK: - Year Habit Bar Card
struct YearHabitBarCard: View {
    let habit: Habit
    let currentYear: Date
    let isCompleted: (Date) -> Bool
    
    private let calendar = Calendar.current
    private var habitColor: Color { Color(hex: habit.colorHex) }
    
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    
    @State private var monthlyRates: [Double] = Array(repeating: 0, count: 12)
    @State private var yearAverage: Double = 0
    @State private var lastComputedYear: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header: Icon + Name + Year Average
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: habit.icon)
                    .font(.system(size: DS.IconSize.sm)) // DT-exempt: icon sizing
                    .foregroundStyle(habitColor)
                
                Text(habit.name)
                    .font(DS.Typography.label())
                    .foregroundStyle(Color.textPrimary)
                
                Spacer()
                
                Text("\(Int(yearAverage * 100))%")
                    .font(DS.Typography.bodySmall()) // was .rounded
                    .foregroundStyle(habitColor)
            }
            
            // Bar Chart
            VStack(spacing: DS.Spacing.xs) {
                // Bars row
                HStack(spacing: 3) {
                    ForEach(0..<12, id: \.self) { month in
                        MonthBar(
                            rate: monthlyRates[month],
                            isCurrentMonth: isCurrentMonth(month),
                            color: habitColor
                        )
                    }
                }
                .frame(height: 48)
                
                // Month labels
                HStack(spacing: 3) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)")
                            .font(DS.Typography.micro())
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
        .onAppear { recomputeIfNeeded() }
        .onChange(of: currentYear) { _, _ in recomputeIfNeeded() }
    }
    
    private func isCurrentMonth(_ monthIndex: Int) -> Bool {
        let currentMonth = calendar.component(.month, from: Date()) - 1
        let currentYearNum = calendar.component(.year, from: Date())
        let displayYear = calendar.component(.year, from: currentYear)
        return displayYear == currentYearNum && monthIndex == currentMonth
    }
    
    private func recomputeIfNeeded() {
        let yearComponent = calendar.component(.year, from: currentYear)
        let lastYearComponent = lastComputedYear.map { calendar.component(.year, from: $0) }
        
        guard lastYearComponent != yearComponent else { return }
        lastComputedYear = currentYear
        
        monthlyRates = computeMonthlyRates()
        
        let nonZero = monthlyRates.filter { $0 > 0 }
        yearAverage = nonZero.isEmpty ? 0 : nonZero.reduce(0, +) / Double(nonZero.count)
    }
    
    private func computeMonthlyRates() -> [Double] {
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: currentYear))!
        
        return (0..<12).map { monthOffset in
            let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: yearStart)!
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)!.count
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
            
            var completedDays = 0
            var countableDays = 0
            
            for day in 0..<daysInMonth {
                if let date = calendar.date(byAdding: .day, value: day, to: startOfMonth),
                   date <= Date() {
                    countableDays += 1
                    if isCompleted(date) { completedDays += 1 }
                }
            }
            
            return countableDays > 0 ? Double(completedDays) / Double(countableDays) : 0
        }
    }
}

// MARK: - Month Bar
struct MonthBar: View {
    let rate: Double
    let isCurrentMonth: Bool
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                
                // Bar fill (from bottom up)
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(height: max(2, geo.size.height * rate))
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                // Current month indicator
                isCurrentMonth ?
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(color, lineWidth: 1.5)
                    : nil
            )
        }
    }
    
    private var barColor: Color {
        if rate >= 0.8 {
            return color
        } else if rate >= 0.5 {
            return color.opacity(0.7)
        } else if rate > 0 {
            return color.opacity(0.4)
        } else {
            return Color.clear
        }
    }
}
