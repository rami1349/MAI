//
//  FamilyView.swift
//
//  PURPOSE:
//    Shared family UI components used across multiple views.
//    MonthlyActivityHeatmap is used by MeView and MemberDetailView.
//    ActionButton is a reusable row-style navigation button.
//
//  NOTE:
//    The former FamilyView tab content has been merged into MeView.
//    This file retains only the shared components to avoid breaking
//    existing references.
//

import SwiftUI

// MARK: - Monthly Activity Heatmap

struct MonthlyActivityHeatmap: View {
    let tasks: [FamilyTask]
    let habitLogs: [String: Set<String>]
    @Binding var displayMonth: Date
    var onMonthChange: ((Date) -> Void)?

    private let calendar = Calendar.current

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Computed

    private var displayYear: Int { calendar.component(.year, from: displayMonth) }
    private var displayMonthNum: Int { calendar.component(.month, from: displayMonth) }
    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var currentMonth: Int { calendar.component(.month, from: .now) }

    private var currentMonthName: String {
        displayMonth.formatted(.dateTime.month(.wide))
    }

    private var canGoBack: Bool { displayMonthNum > 1 }

    private var canGoForward: Bool {
        if displayYear < currentYear { return displayMonthNum < 12 }
        if displayYear == currentYear { return displayMonthNum < currentMonth }
        return false
    }

    private var completedTasks: [FamilyTask] {
        tasks.filter { $0.status == .completed && $0.completedAt != nil }
    }

    private var yearToDateCompleted: Int {
        let yearStart = calendar.date(from: DateComponents(year: displayYear, month: 1, day: 1))!
        let yearEnd = calendar.date(from: DateComponents(year: displayYear, month: 12, day: 31))!
        let taskCount = completedTasks.filter { task in
            guard let at = task.completedAt else { return false }
            return at >= yearStart && at <= yearEnd
        }.count
        let yearPrefix = "\(displayYear)-"
        let habitCount = habitLogs.values.reduce(0) { total, dates in
            total + dates.filter { $0.hasPrefix(yearPrefix) }.count
        }
        return taskCount + habitCount
    }

    private var monthCompleted: Int {
        monthData.flatMap { $0 }.compactMap { $0 }.reduce(0) { $0 + completedCount(for: $1) }
    }

    private var monthData: [[Date?]] {
        let range = calendar.range(of: .day, in: .month, for: displayMonth)!
        let components = calendar.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1

        var weeks: [[Date?]] = []
        var week: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: day, to: firstOfMonth) {
                week.append(date)
                if week.count == 7 { weeks.append(week); week = [] }
            }
        }
        if !week.isEmpty {
            while week.count < 7 { week.append(nil) }
            weeks.append(week)
        }
        return weeks
    }

    private func completedCount(for date: Date) -> Int {
        let taskCount = completedTasks.filter { task in
            guard let at = task.completedAt else { return false }
            return calendar.isDate(at, inSameDayAs: date)
        }.count
        let dateString = Self.dateFormatter.string(from: date)
        let habitCount = habitLogs.values.reduce(0) { $0 + ($1.contains(dateString) ? 1 : 0) }
        return taskCount + habitCount
    }

    private func intensityColor(count: Int) -> Color {
        switch count {
        case 0:  Color.surfaceColor
        case 1:  Color.accentGreen.opacity(0.25)
        case 2:  Color.accentGreen.opacity(0.40)
        case 3:  Color.accentGreen.opacity(0.55)
        case 4:  Color.accentGreen.opacity(0.70)
        case 5:  Color.accentGreen.opacity(0.85)
        default: Color.accentGreen
        }
    }

    private func textColor(count: Int) -> Color {
        count >= 4 ? .white : .textSecondary
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Header
            VStack(spacing: DS.Spacing.md) {
                HStack {
                    Text(verbatim: "\(displayYear)")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(DS.Typography.bodySmall())
                            .foregroundStyle(.accentOrange)
                        Text(AppStrings.thisYearCount(yearToDateCompleted))
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textSecondary)
                    }
                }

                // Month nav
                HStack {
                    Button(action: goToPreviousMonth) {
                        Image(systemName: "chevron.left")
                            .font(DS.Typography.label())
                            .foregroundStyle(canGoBack ? .accentPrimary : .textTertiary)
                            .frame(width: DS.Avatar.sm, height: DS.Avatar.sm)
                            .background(Circle().fill(canGoBack ? Color.accentPrimary.opacity(0.1) : .clear))
                    }
                    .disabled(!canGoBack)

                    Spacer()
                    Text(currentMonthName)
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                    Spacer()

                    Button(action: goToNextMonth) {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.label())
                            .foregroundStyle(canGoForward ? .accentPrimary : .textTertiary)
                            .frame(width: DS.Avatar.sm, height: DS.Avatar.sm)
                            .background(Circle().fill(canGoForward ? Color.accentPrimary.opacity(0.1) : .clear))
                    }
                    .disabled(!canGoForward)
                }
            }

            // Grid
            VStack(spacing: DS.Spacing.sm) {
                // Day headers
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(AppStrings.dayNames.dropFirst(), id: \.self) { name in
                        Text(name)
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Weeks
                ForEach(Array(monthData.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(0..<7, id: \.self) { i in
                            if let date = week[i] {
                                let count = completedCount(for: date)
                                let day = calendar.component(.day, from: date)
                                let isToday = calendar.isDateInToday(date)
                                let isFuture = date > .now

                                ZStack {
                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                        .fill(isFuture ? Color.surfaceColor : intensityColor(count: count))
                                    Text("\(day)")
                                        .font(DS.Typography.micro())
                                        .fontWeight(isToday ? .bold : .regular)
                                        .foregroundStyle(isFuture ? .textTertiary : textColor(count: count))
                                }
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                        .stroke(isToday ? Color.accentPrimary : .clear, lineWidth: DS.Border.emphasized)
                                )
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }

            // Footer legend
            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Text("less").font(DS.Typography.micro()).foregroundStyle(.textTertiary)
                    ForEach([0, 1, 3, 5, 6], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(intensityColor(count: level))
                            .frame(width: DS.IconSize.xs, height: DS.IconSize.xs)
                    }
                    Text("more").font(DS.Typography.micro()).foregroundStyle(.textTertiary)
                }
                Spacer()
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.micro()).foregroundStyle(.accentGreen)
                    Text(AppStrings.thisMonthCount(monthCompleted))
                        .font(DS.Typography.micro()).foregroundStyle(.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.themeCardBackground))
    }

    // MARK: - Navigation

    private func goToPreviousMonth() {
        guard canGoBack, let m = calendar.date(byAdding: .month, value: -1, to: displayMonth) else { return }
        displayMonth = m
        onMonthChange?(m)
    }

    private func goToNextMonth() {
        guard canGoForward, let m = calendar.date(byAdding: .month, value: 1, to: displayMonth) else { return }
        displayMonth = m
        onMonthChange?(m)
    }
}

// MARK: - Action Button (reusable)

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: DS.Avatar.md, height: DS.Avatar.md)
                    .background(Circle().fill(color.opacity(0.1)))

                Text(title)
                    .font(DS.Typography.label())
                    .foregroundStyle(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.themeCardBackground))
            .elevation1()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header (reusable)

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(.accentPrimary)
            Text(title).font(DS.Typography.heading()).foregroundStyle(.textPrimary)
        }
    }
}
