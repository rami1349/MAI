//
//  EmptyStateView.swift
//
//  PURPOSE:
//    Context-aware empty state component. Shows a single clean icon,
//    title, message, and optional action button when a list has no data.
//
//  ARCHITECTURE ROLE:
//    Reusable leaf component — used by TasksView, CalendarView,
//    HabitTrackerView, NotificationsView, RewardWalletView, etc.
//    No ViewModel dependencies; purely presentational.
//
//  DESIGN:
//    Minimal — one icon, no background shapes, no decorative elements.
//    Subtle fade-in entrance animation only.
//

import SwiftUI

// MARK: - Empty State Context

enum EmptyStateContext {
    case tasks
    case todayTasks
    case habits
    case notifications
    case calendar
    case search
    case me
    case rewards
    case taskGroup
    case generic(icon: String)
    
    /// SF Symbol for the context.
    var icon: String {
        switch self {
        case .tasks, .todayTasks: return "checklist"
        case .habits:             return "flame"
        case .notifications:      return "bell"
        case .calendar:           return "calendar"
        case .search:             return "magnifyingglass"
        case .me:                 return "person.2"
        case .rewards:            return "gift"
        case .taskGroup:          return "folder"
        case .generic(let icon):  return icon
        }
    }
    
    /// Accent color for icon and button.
    var accentColor: Color {
        switch self {
        case .tasks, .todayTasks, .taskGroup: return Color.accentPrimary
        case .habits:                         return Color.accentGreen
        case .notifications:                  return Color.accentOrange
        case .calendar:                       return Color.accentRed
        case .search:                         return Color.accentSecondary
        case .me:                             return Color.accentTertiary
        case .rewards:                        return Color.accentGreen
        case .generic:                        return Color.accentPrimary
        }
    }
    
    /// Button icon for the CTA.
    var buttonIcon: String {
        switch self {
        case .tasks, .todayTasks, .taskGroup: return "plus"
        case .habits:                         return "plus"
        case .notifications:                  return "bell"
        case .calendar:                       return "plus"
        case .search:                         return "magnifyingglass"
        case .me:                             return "person.badge.plus"
        case .rewards:                        return "gift"
        case .generic:                        return "plus"
        }
    }
}

// Retained for type compatibility — no longer drives illustration logic
enum EmptyStateIllustration {
    case tasks, habits, notifications, calendar, search, me, rewards, taskGroup
    case custom(icon: String)
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let context: EmptyStateContext
    let title: String
    let message: String
    var buttonTitle: String?
    var buttonAction: (() -> Void)?
    
    @State private var isVisible = false
    
    // Legacy initializer
    init(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.context = .generic(icon: icon)
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }
    
    // Context-aware initializer
    init(
        context: EmptyStateContext,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.context = context
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Icon — just the symbol, nothing else
            Image(systemName: context.icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(context.accentColor.opacity(0.55))
                .padding(.bottom, DS.Spacing.xs)
            
            // Text
            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.heading())
                    .foregroundStyle(.textPrimary)
                
                Text(message)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Action button
            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: context.buttonIcon)
                            .font(DS.Typography.label())
                        Text(buttonTitle)
                            .font(DS.Typography.label())
                    }
                    .foregroundStyle(.textOnAccent)
                    .padding(.horizontal, DS.Spacing.xxl)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Capsule().fill(context.accentColor))
                }
            }
        }
        .padding(DS.Spacing.jumbo)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Previews

#Preview("All Contexts") {
    ScrollView {
        VStack(spacing: 40) {
            EmptyStateView(
                context: .tasks,
                title: "No Tasks Yet",
                message: "Create your first task to get started with your family's productivity journey.",
                buttonTitle: "Add Task",
                buttonAction: {}
            )
            
            Divider()
            
            EmptyStateView(
                context: .habits,
                title: "Build Better Habits",
                message: "Start tracking habits to build consistency and achieve your goals.",
                buttonTitle: "Create Habit",
                buttonAction: {}
            )
            
            Divider()
            
            EmptyStateView(
                context: .notifications,
                title: "All Caught Up!",
                message: "You don't have any notifications right now."
            )
            
            Divider()
            
            EmptyStateView(
                context: .calendar,
                title: "No Events",
                message: "Your calendar is clear. Add events to keep your family organized.",
                buttonTitle: "Add Event",
                buttonAction: {}
            )
            
            Divider()
            
            EmptyStateView(
                context: .rewards,
                title: "No Rewards Yet",
                message: "Complete tasks to earn rewards and reach your goals!"
            )
        }
        .padding()
    }
}

#Preview("Legacy Compatibility") {
    EmptyStateView(
        icon: "checklist",
        title: "No Tasks",
        message: "You don't have any tasks yet.\nCreate one to get started!",
        buttonTitle: "Add Task",
        buttonAction: {}
    )
}
