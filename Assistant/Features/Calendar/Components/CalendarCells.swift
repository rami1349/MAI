
//  CalendarCells.swift
//  FamilyHub
//
//  Core calendar cell components for day and year views
//

import SwiftUI

// MARK: - Year Month Cell (for Year View Grid)

struct YearMonthCell: View {
    let month: Date
    let currentDate: Date
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: currentDate, toGranularity: .month)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(monthName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(isCurrentMonth ? .accentRed : .textPrimary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                    ForEach(Array(generateDaysInMonth().enumerated()), id: \.offset) { index, day in
                        if day > 0 {
                            Text("\(day)")
                                .font(DS.Typography.micro())
                                .foregroundStyle(getDayColor(day: day))
                                .frame(width: 14, height: 14)
                                .background(
                                    Circle()
                                        .fill(isToday(day: day) ? Color.accentRed : Color.clear)
                                )
                        } else {
                            Text("")
                                .font(DS.Typography.micro())
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            .padding(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func generateDaysInMonth() -> [Int] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        
        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        
        var days: [Int] = []
        
        // Add empty days for padding (0 represents empty)
        for _ in 1..<firstWeekday {
            days.append(0)
        }
        
        // Add actual days
        for day in 1...daysInMonth {
            days.append(day)
        }
        
        return days
    }
    
    private func isToday(day: Int) -> Bool {
        let year = calendar.component(.year, from: month)
        let monthNum = calendar.component(.month, from: month)
        let todayYear = calendar.component(.year, from: currentDate)
        let todayMonth = calendar.component(.month, from: currentDate)
        let todayDay = calendar.component(.day, from: currentDate)
        
        return year == todayYear && monthNum == todayMonth && day == todayDay
    }
    
    private func getDayColor(day: Int) -> Color {
        if isToday(day: day) {
            return .white
        }
        
        // Check if it's a weekend
        let year = calendar.component(.year, from: month)
        let monthNum = calendar.component(.month, from: month)
        var components = DateComponents()
        components.year = year
        components.month = monthNum
        components.day = day
        
        if let date = calendar.date(from: components) {
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 {
                return Color.textSecondary.opacity(0.6)
            }
        }
        
        return Color.textSecondary
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let hasTasks: Bool
    var hasSpecialEvents: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(DS.Typography.body()).fontWeight(isSelected || isToday ? .bold : .regular)
                    .foregroundStyle(
                        isSelected ? .white :
                            isToday ? Color.accentRed :
                                Color.textPrimary
                    )
                
                HStack(spacing: 2) {
                    if hasSpecialEvents {
                        Circle()
                            .fill(isSelected ? Color.white : Color.accentSecondary)
                            .frame(width: 4, height: 4)
                    }
                    if hasEvents {
                        Circle()
                            .fill(isSelected ? Color.white : Color.primary)
                            .frame(width: 4, height: 4)
                    }
                    if hasTasks {
                        Circle()
                            .fill(isSelected ? Color.white : Color.accentTertiary)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Circle()
                    .fill(isSelected ? Color.accentRed : (isToday ? Color.accentRed : Color.clear))
                    .frame(width: 36, height: 36)
                    .opacity(isSelected ? 1 : (isToday ? 0.15 : 0))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
