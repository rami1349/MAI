//
//  WeekStripView.swift
//
//  LUXURY CALM REDESIGN
//  - Elegant day cells with soft selection
//  - Refined typography and spacing
//  - Subtle shadows and interactions
//  - Clean indicator dots
//

import SwiftUI

struct WeekStripView: View {
    let weekDays: [Date]
    let selectedDay: Date
    let todayDate: Date
    let itemCounts: [String: Int]
    let onSelectDay: (Date) -> Void
    let onSwipeBack: () -> Void
    let onSwipeForward: () -> Void
    
    @GestureState private var dragOffset: CGFloat = 0
    
    private let calendar = Calendar.current
    private static let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDay)
                let isToday = calendar.isDate(date, inSameDayAs: todayDate)
                let count = itemCounts[AgendaDataCache.dayKey(for: date)] ?? 0
                
                LuxuryDayCell(
                    dayLetter: Self.dayLetters[index % 7],
                    dayNumber: date.dayNumber,
                    isSelected: isSelected,
                    isToday: isToday,
                    itemCount: count
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onSelectDay(date) }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.themeCardBackground)
                .elevation2()
        )
        .offset(x: dragOffset)
        .gesture(swipeGesture)
        .animation(.easeOut(duration: 0.2), value: dragOffset)
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                state = max(-80, min(80, value.translation.width * 0.4))
            }
            .onEnded { value in
                if value.translation.width < -50 {
                    onSwipeForward()
                } else if value.translation.width > 50 {
                    onSwipeBack()
                }
            }
    }
}

// MARK: - Luxury Day Cell

private struct LuxuryDayCell: View {
    let dayLetter: String
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
    let itemCount: Int
    
    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            // Day letter
            Text(dayLetter)
                .font(DS.Typography.micro())
                .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)
            
            // Day number
            Text(dayNumber)
                .font(DS.Typography.body()).fontWeight(isSelected || isToday ? .semibold : .regular)
                .foregroundStyle(dayNumberColor)
            
            // Item indicator
            itemIndicator
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(borderColor, lineWidth: isToday && !isSelected ? 1 : 0)
        )
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
    
    private var dayNumberColor: Color {
        if isSelected { return .accentPrimary }
        if isToday { return .accentPrimary }
        return .textPrimary
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentPrimary.opacity(0.12)
        }
        return Color.clear
    }
    
    private var borderColor: Color {
        if isToday && !isSelected {
            return Color.accentPrimary.opacity(0.3)
        }
        return Color.clear
    }
    
    @ViewBuilder
    private var itemIndicator: some View {
        if itemCount > 0 {
            if itemCount <= 3 {
                HStack(spacing: 2) {
                    ForEach(0..<min(itemCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Color.accentPrimary : Color.textTertiary)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            } else {
                Text("\(itemCount)")
                    .font(DS.Typography.micro())
                    .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)
                    .frame(height: 6)
            }
        } else {
            Spacer().frame(height: 6)
        }
    }
}

#Preview {
    let today = Date()
    let week = (0..<7).map { today.startOfWeek.addingDays($0) }
    
    WeekStripView(
        weekDays: week,
        selectedDay: today,
        todayDate: today,
        itemCounts: [AgendaDataCache.dayKey(for: today): 5],
        onSelectDay: { _ in },
        onSwipeBack: {},
        onSwipeForward: {}
    )
    .padding()
    .background(Color.themeSurfacePrimary)
}
