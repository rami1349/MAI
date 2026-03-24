//
//  MonthGridOverlay.swift
//
//  LUXURY CALM REDESIGN
//  - Clean month grid with soft selection
//  - Elegant navigation buttons
//  - Refined collapse handle
//  - Premium shadows and spacing
//

import SwiftUI

struct MonthGridOverlay: View {
    let currentMonth: Date
    let selectedDay: Date
    let todayDate: Date
    let itemCounts: [String: Int]
    let onSelectDay: (Date) -> Void
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onCollapse: () -> Void
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private static let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Month navigation header
            monthHeader
            
            // Day-of-week headers
            dayOfWeekHeaders
            
            // Day grid
            dayGrid
            
            // Collapse handle
            collapseHandle
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .fill(Color.themeCardBackground)
                .elevation3()
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Button(action: onPreviousMonth) {
                Image(systemName: "chevron.left")
                    .font(DS.Typography.label())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
            }
            
            Spacer()
            
            Text(SharedFormatters.monthYear.string(from: currentMonth))
                .font(DS.Typography.subheading())
                .foregroundStyle(.textPrimary)
            
            Spacer()
            
            Button(action: onNextMonth) {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.label())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
            }
        }
    }
    
    // MARK: - Day-of-Week Headers
    
    private var dayOfWeekHeaders: some View {
        HStack(spacing: 4) {
            ForEach(Array(Self.dayHeaders.enumerated()), id: \.offset) { _, letter in
                Text(letter)
                    .font(DS.Typography.micro())
                    .fontWeight(.medium)
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, DS.Spacing.xs)
    }
    
    // MARK: - Day Grid
    
    private var dayGrid: some View {
        let days = generateDaysInMonth()
        
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDay)
                    let isToday = calendar.isDate(date, inSameDayAs: todayDate)
                    let count = itemCounts[AgendaDataCache.dayKey(for: date)] ?? 0
                    
                    MonthDayCell(
                        dayNumber: date.dayNumber,
                        isSelected: isSelected,
                        isToday: isToday,
                        hasItems: count > 0
                    )
                    .onTapGesture {
                        onSelectDay(date)
                        withAnimation(.easeOut(duration: 0.25)) {
                            onCollapse()
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
    }
    
    // MARK: - Collapse Handle
    
    private var collapseHandle: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.25)) { onCollapse() }
        }) {
            VStack(spacing: DS.Spacing.xxs) {
                Capsule()
                    .fill(Color.textTertiary.opacity(0.3))
                    .frame(width: 40, height: 4)
                
                Text("tap_to_close")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.sm)
        }
    }
    
    // MARK: - Generate Month Days
    
    private func generateDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }
        
        var days: [Date?] = []
        var date = firstWeek.start
        
        while date < monthInterval.end || days.count % 7 != 0 {
            if date < monthInterval.start || date >= monthInterval.end {
                days.append(nil)
            } else {
                days.append(date)
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        return days
    }
}

// MARK: - Month Day Cell

private struct MonthDayCell: View {
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
    let hasItems: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(DS.Typography.bodySmall())
                .fontWeight(isToday || isSelected ? .semibold : .regular)
                .foregroundStyle(foregroundColor)
            
            Circle()
                .fill(hasItems ? dotColor : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            Circle()
                .fill(backgroundColor)
                .frame(width: 36, height: 36)
        )
    }
    
    private var foregroundColor: Color {
        if isSelected { return .white }
        if isToday { return Color.accentPrimary }
        return Color.textPrimary
    }
    
    private var backgroundColor: Color {
        if isSelected { return Color.accentPrimary }
        if isToday { return Color.accentPrimary.opacity(0.1) }
        return .clear
    }
    
    private var dotColor: Color {
        if isSelected { return .white.opacity(0.7) }
        return Color.accentPrimary
    }
}
