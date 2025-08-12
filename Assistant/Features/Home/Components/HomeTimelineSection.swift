//
//  HomeTimelineSection.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//


//  Unified timeline showing today/tomorrow tasks and events merged chronologically.
//  Clean, scannable design with time-based grouping.
//

import SwiftUI

struct HomeTimelineSection: View {
    let items: [TimelineItem]
    let groupLookup: (String) -> TaskGroup?
    let memberLookup: (String) -> FamilyUser?
    let onSelectTask: (FamilyTask) -> Void
    let onDeleteEvent: (UpcomingEvent) -> Void
    
    @State private var isExpanded: Bool = true
    
    private var todayItems: [TimelineItem] {
        items.filter { $0.isToday }
    }
    
    private var tomorrowItems: [TimelineItem] {
        items.filter { $0.isTomorrow }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Luxury.Spacing.md) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: Luxury.Spacing.sm) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                    
                    Text("Today & Tomorrow")
                        .font(Luxury.Typography.subheading())
                        .foregroundColor(.textPrimary)
                    
                    if !items.isEmpty {
                        Text("\(items.count)")
                            .font(Luxury.Typography.captionMedium())
                            .foregroundColor(.accentPrimary)
                            .padding(.horizontal, Luxury.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.accentPrimary.opacity(0.1))
                            )
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Luxury.Spacing.screenH)
            
            if isExpanded {
                if items.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: Luxury.Spacing.lg) {
                        // Today section
                        if !todayItems.isEmpty {
                            timelineGroup(title: "Today", items: todayItems)
                        }
                        
                        // Tomorrow section
                        if !tomorrowItems.isEmpty {
                            timelineGroup(title: "Tomorrow", items: tomorrowItems)
                        }
                    }
                    .padding(.horizontal, Luxury.Spacing.screenH)
                }
            }
        }
    }
    
    // MARK: - Timeline Group
    
    private func timelineGroup(title: String, items: [TimelineItem]) -> some View {
        VStack(alignment: .leading, spacing: Luxury.Spacing.sm) {
            // Group header
            Text(title)
                .font(Luxury.Typography.captionMedium())
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
            
            // Items
            VStack(spacing: Luxury.Spacing.xs) {
                ForEach(items) { item in
                    timelineRow(for: item)
                }
            }
        }
    }
    
    // MARK: - Timeline Row
    
    @ViewBuilder
    private func timelineRow(for item: TimelineItem) -> some View {
        switch item {
        case .task(let task):
            TimelineTaskRow(
                task: task,
                groupName: task.groupId.flatMap { groupLookup($0)?.name },
                onTap: { onSelectTask(task) }
            )
            
        case .event(let event):
            TimelineEventRow(
                event: event,
                canDelete: event.canDelete,
                onDelete: { onDeleteEvent(event) }
            )
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        HStack(spacing: Luxury.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.08))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "sun.max")
                    .font(.system(size: 16))
                    .foregroundColor(.accentPrimary.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Clear schedule")
                    .font(Luxury.Typography.body())
                    .foregroundColor(.textSecondary)
                
                Text("Nothing scheduled for today or tomorrow")
                    .font(Luxury.Typography.caption())
                    .foregroundColor(.textTertiary)
            }
            
            Spacer()
        }
        .padding(Luxury.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Luxury.Radius.md)
                .fill(Color.themeCardBackground)
        )
        .padding(.horizontal, Luxury.Spacing.screenH)
    }
}

// MARK: - Timeline Task Row

struct TimelineTaskRow: View {
    let task: FamilyTask
    let groupName: String?
    let onTap: () -> Void
    
    private var timeText: String? {
        if let time = task.scheduledTime {
            return time.formatted(.dateTime.hour().minute())
        }
        return nil
    }
    
    private var statusColor: Color {
        switch task.status {
        case .todo: return .statusTodo
        case .inProgress: return .statusInProgress
        case .pendingVerification: return .statusPending
        case .completed: return .statusCompleted
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Luxury.Spacing.md) {
                // Time column (fixed width for alignment)
                Text(timeText ?? "--:--")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(timeText != nil ? .textSecondary : .textTertiary)
                    .frame(width: 50, alignment: .leading)
                
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Luxury.Typography.label())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    if let groupName = groupName {
                        Text(groupName)
                            .font(Luxury.Typography.micro())
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Task type icon
                Image(systemName: "checklist")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }
            .padding(.vertical, Luxury.Spacing.sm)
            .padding(.horizontal, Luxury.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Luxury.Radius.sm)
                    .fill(Color.themeCardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timeline Event Row

struct TimelineEventRow: View {
    let event: UpcomingEvent
    let canDelete: Bool
    let onDelete: () -> Void
    
    private var timeText: String {
        event.date.formatted(.dateTime.hour().minute())
    }
    
    var body: some View {
        HStack(spacing: Luxury.Spacing.md) {
            // Time column
            Text(timeText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.textSecondary)
                .frame(width: 50, alignment: .leading)
            
            // Color indicator
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(Luxury.Typography.label())
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(Luxury.Typography.micro())
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Event type icon
            Image(systemName: event.icon)
                .font(.system(size: 12))
                .foregroundColor(event.color)
        }
        .padding(.vertical, Luxury.Spacing.sm)
        .padding(.horizontal, Luxury.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Luxury.Radius.sm)
                .fill(Color.themeCardBackground)
        )
        .if(canDelete) { view in
            view.swipeToDelete(action: onDelete)
        }
    }
}

// MARK: - Conditional Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        HomeTimelineSection(
            items: [],
            groupLookup: { _ in nil },
            memberLookup: { _ in nil },
            onSelectTask: { _ in },
            onDeleteEvent: { _ in }
        )
    }
    .background(Color.themeSurfacePrimary)
}