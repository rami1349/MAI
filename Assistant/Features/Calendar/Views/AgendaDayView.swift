//
//  AgendaDayView.swift
//
//  LUXURY CALM REDESIGN
//  - Clean section headers
//  - Refined empty state
//  - Elegant expand/collapse
//  - Premium spacing throughout
//

import SwiftUI

struct AgendaDayView: View {
    let selectedDay: Date
    let agenda: DayAgenda
    let familyMembers: [FamilyUser]
    let onSelectTask: (FamilyTask) -> Void
    let onDeleteEvent: (CalendarEvent) -> Void
    
    @State private var showAllTasks = false
    @State private var showAllEvents = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            // Day header
            dayHeader
            
            if agenda.isEmpty {
                emptyState
            } else {
                if !agenda.tasks.isEmpty { tasksSection }
                if !agenda.events.isEmpty { eventsSection }
            }
        }
    }
    
    // MARK: - Day Header
    
    private var dayHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(selectedDay.isToday ? L10n.today : selectedDay.formattedDate)
                    .font(DS.Typography.heading())
                    .foregroundStyle(.textPrimary)
                
                if selectedDay.isToday {
                    Text(selectedDay.formattedShortDate)
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textSecondary)
                }
            }
            
            Spacer()
            
            if !agenda.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    Text("\(agenda.totalCount)")
                        .font(DS.Typography.labelSmall())
                        .foregroundStyle(.accentPrimary)
                    
                    Text(agenda.totalCount == 1 ? "item" : "items")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(Color.accentPrimary.opacity(0.08))
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
                .frame(height: DS.Spacing.xl)
            
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.06))
                    .frame(width: 72, height: 72)
                
                Image(systemName: "leaf")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.accentPrimary.opacity(0.4))
            }
            
            VStack(spacing: DS.Spacing.xs) {
                Text(L10n.noEvents)
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)
                
                Text("thisDayIsClear")
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textTertiary)
            }
            
            Spacer()
                .frame(height: DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tasks Section
    
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section header
            sectionHeader(
                icon: "checklist",
                title: L10n.tasks,
                count: agenda.tasks.count
            )
            
            // Task rows
            let visible = showAllTasks ? agenda.tasks : Array(agenda.tasks.prefix(3))
            ForEach(visible,id: \.stableId) { task in
                AgendaTaskRow(task: task, familyMembers: familyMembers)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectTask(task) }
            }
            
            // Expand button
            if agenda.tasks.count > 3 {
                expandButton(
                    isExpanded: showAllTasks,
                    remaining: agenda.tasks.count - 3
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllTasks.toggle()
                    }
                }
            }
        }
    }
    
    // MARK: - Events Section
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section header
            sectionHeader(
                icon: "calendar",
                title: L10n.calendar,
                count: agenda.events.count
            )
            
            // Event rows
            let visible = showAllEvents ? agenda.events : Array(agenda.events.prefix(3))
            ForEach(visible) { event in
                AgendaEventRow(event: event)
                    .swipeToDelete { onDeleteEvent(event) }
            }
            
            // Expand button
            if agenda.events.count > 3 {
                expandButton(
                    isExpanded: showAllEvents,
                    remaining: agenda.events.count - 3
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllEvents.toggle()
                    }
                }
            }
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(icon: String, title: String, count: Int) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.body())
                .foregroundStyle(.accentPrimary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.1))
                )
            
            Text(title)
                .font(DS.Typography.labelSmall())
                .foregroundStyle(.textPrimary)
            
            Text("(\(count))")
                .font(DS.Typography.caption())
                .foregroundStyle(.textTertiary)
            
            Spacer()
        }
        .padding(.bottom, DS.Spacing.xxs)
    }
    
    // MARK: - Expand Button
    
    private func expandButton(isExpanded: Bool, remaining: Int, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: DS.Spacing.xs) {
                Text(isExpanded ? L10n.showLess : "+ \(remaining) more")
                    .font(DS.Typography.captionMedium())
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(DS.Typography.micro())
            }
            .foregroundStyle(.accentPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(Color.accentPrimary.opacity(0.05))
            )
        }
        .padding(.top, DS.Spacing.xxs)
    }
}
