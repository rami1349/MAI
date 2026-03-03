//
//  EmptyStateView.swift
//  FamilyHub
//
//  Context-aware empty state component with illustrations and animations
//
//  Features:
//  - Predefined contexts (tasks, habits, notifications, calendar, etc.)
//  - Animated illustrations using SF Symbol compositions
//  - Subtle entrance animations
//  - Theme-aware styling
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
    case family
    case rewards
    case taskGroup
    case generic(icon: String)
    
    var illustration: EmptyStateIllustration {
        switch self {
        case .tasks, .todayTasks:
            return .tasks
        case .habits:
            return .habits
        case .notifications:
            return .notifications
        case .calendar:
            return .calendar
        case .search:
            return .search
        case .family:
            return .family
        case .rewards:
            return .rewards
        case .taskGroup:
            return .taskGroup
        case .generic(let icon):
            return .custom(icon: icon)
        }
    }
    
    var accentColor: Color {
        switch self {
        case .tasks, .todayTasks, .taskGroup:
            return .accentPrimary
        case .habits:
            return .accentGreen
        case .notifications:
            return .accentOrange
        case .calendar:
            return .accentRed
        case .search:
            return .accentSecondary
        case .family:
            return .accentTertiary
        case .rewards:
            return .accentGreen
        case .generic:
            return .accentPrimary
        }
    }
}

// MARK: - Empty State Illustration

enum EmptyStateIllustration {
    case tasks
    case habits
    case notifications
    case calendar
    case search
    case family
    case rewards
    case taskGroup
    case custom(icon: String)
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let context: EmptyStateContext
    let title: String
    let message: String
    var buttonTitle: String?
    var buttonAction: (() -> Void)?
    
    @State private var isAnimating = false
    
    // Legacy initializer for backward compatibility
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
    
    // New context-aware initializer
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
            // Illustration
            illustrationView
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0)
            
            // Text content
            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.heading())
                    .foregroundStyle(.textPrimary)
                    .opacity(isAnimating ? 1.0 : 0)
                    .offset(y: isAnimating ? 0 : 10)
                
                Text(message)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isAnimating ? 1.0 : 0)
                    .offset(y: isAnimating ? 0 : 10)
            }
            
            // Action button
            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: buttonIcon)
                            .font(DS.Typography.label())
                        Text(buttonTitle)
                            .font(DS.Typography.label())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.xxl)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Capsule().fill(context.accentColor))
                }
                .opacity(isAnimating ? 1.0 : 0)
                .offset(y: isAnimating ? 0 : 15)
            }
        }
        .padding(DS.Spacing.jumbo)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Illustration View
    
    @ViewBuilder
    private var illustrationView: some View {
        switch context.illustration {
        case .tasks:
            TasksIllustration(accentColor: context.accentColor, isAnimating: isAnimating)
        case .habits:
            HabitsIllustration(accentColor: context.accentColor, isAnimating: isAnimating)
        case .notifications:
            NotificationsIllustration(accentColor: context.accentColor, isAnimating: isAnimating)
        case .calendar:
            CalendarIllustration(accentColor: context.accentColor, isAnimating: isAnimating)
        case .search:
            SearchIllustration(accentColor: context.accentColor, isAnimating: isAnimating)
        case .family:
            FamilyIllustration(accentColor: context.accentColor, isAnimating: isAnimating)
        case .rewards:
            RewardsIllustration(accentColor: context.accentColor, isAnimating: isAnimating)
        case .taskGroup:
            TaskGroupIllustration(accentColor: context.accentColor, isAnimating: isAnimating)
        case .custom(let icon):
            GenericIllustration(icon: icon, accentColor: context.accentColor, isAnimating: isAnimating)
        }
    }
    
    private var buttonIcon: String {
        switch context {
        case .tasks, .todayTasks, .taskGroup: return "plus"
        case .habits: return "plus"
        case .notifications: return "bell"
        case .calendar: return "plus"
        case .search: return "magnifyingglass"
        case .family: return "person.badge.plus"
        case .rewards: return "gift"
        case .generic: return "plus"
        }
    }
}

// MARK: - Illustration Components

private struct TasksIllustration: View {
    let accentColor: Color
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Decorative circles
            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: 2)
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isAnimating)
            
            // Stacked task cards
            VStack(spacing: 6) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.themeCardBackground)
                        .frame(width: 60 - CGFloat(index * 8), height: 16)
                        .overlay(
                            HStack(spacing: 4) {
                                Circle()
                                    .stroke(accentColor.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 8, height: 8)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.textTertiary.opacity(0.3))
                                    .frame(width: 30 - CGFloat(index * 6), height: 4)
                                Spacer()
                            }
                            .padding(.horizontal, 6)
                        )
                        .elevation1()
                        .offset(y: isAnimating ? 0 : CGFloat(index * 5))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1), value: isAnimating)
                }
            }
            
            // Floating checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.displayMedium())
                .foregroundStyle(accentColor)
                .offset(x: 35, y: -35)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3), value: isAnimating)
        }
        .frame(width: 120, height: 120)
    }
}

private struct HabitsIllustration: View {
    let accentColor: Color
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Habit streak dots
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index < 3 ? accentColor : accentColor.opacity(0.2))
                        .frame(width: 16, height: 16)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.08), value: isAnimating)
                }
            }
            
            // Flame icon
            Image(systemName: "flame.fill")
                .font(DS.Typography.displayMedium())
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, accentColor],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .offset(y: -45)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: isAnimating)
        }
        .frame(width: 120, height: 120)
    }
}

private struct NotificationsIllustration: View {
    let accentColor: Color
    let isAnimating: Bool
    
    @State private var bellRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Sound waves
            ForEach(0..<3) { index in
                Circle()
                    .stroke(accentColor.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                    .frame(width: CGFloat(60 + index * 20), height: CGFloat(60 + index * 20))
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0)
                    .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.1), value: isAnimating)
            }
            
            // Bell icon
            Image(systemName: "bell.fill")
                .font(DS.Typography.displayLarge())
                .foregroundStyle(accentColor)
                .rotationEffect(.degrees(bellRotation))
                .onAppear {
                    if isAnimating {
                        withAnimation(.easeInOut(duration: 0.15).repeatCount(4, autoreverses: true).delay(0.5)) {
                            bellRotation = 15
                        }
                    }
                }
            
            // "Z" sleep indicators
            Text("z z z")
                .font(DS.Typography.label()) // was .rounded
                .foregroundStyle(.textTertiary)
                .offset(x: 30, y: -30)
                .opacity(isAnimating ? 0.6 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: isAnimating)
        }
        .frame(width: 120, height: 120)
    }
}

private struct CalendarIllustration: View {
    let accentColor: Color
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Calendar base
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.themeCardBackground)
                .frame(width: 70, height: 70)
                .elevation1()
            
            // Calendar header
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 70, height: 18)
                
                // Grid dots
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(10), spacing: 4), count: 5), spacing: 4) {
                    ForEach(0..<10) { index in
                        Circle()
                            .fill(index == 4 ? accentColor : Color.textTertiary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(8)
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            
            // Floating star
            Image(systemName: "star.fill")
                .font(DS.Typography.heading())
                .foregroundStyle(.yellow)
                .offset(x: 35, y: -35)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .rotationEffect(.degrees(isAnimating ? 0 : -30))
                .opacity(isAnimating ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3), value: isAnimating)
        }
        .frame(width: 120, height: 120)
    }
}

private struct SearchIllustration: View {
    let accentColor: Color
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Magnifying glass
            Image(systemName: "magnifyingglass")
                .font(DS.Typography.displayLarge())
                .foregroundStyle(accentColor)
                .offset(x: isAnimating ? 0 : -10, y: isAnimating ? 0 : -10)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)
            
            // Search particles
            ForEach(0..<4) { index in
                Circle()
                    .fill(accentColor.opacity(0.4))
                    .frame(width: 6, height: 6)
                    .offset(
                        x: CGFloat([-25, 30, -20, 35][index]),
                        y: CGFloat([-30, -25, 25, 20][index])
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.1), value: isAnimating)
            }
        }
        .frame(width: 120, height: 120)
    }
}

private struct FamilyIllustration: View {
    let accentColor: Color
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Family members
            HStack(spacing: -15) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.themeCardBackground)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(DS.Typography.heading())
                                .foregroundStyle([accentColor, .accentSecondary, .accentTertiary][index])
                        )
                        .elevation2()
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(index) * 0.1), value: isAnimating)
                }
            }
            
            // Heart
            Image(systemName: "heart.fill")
                .font(DS.Typography.heading())
                .foregroundStyle(.pink)
                .offset(y: -45)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: isAnimating)
        }
        .frame(width: 120, height: 120)
    }
}

private struct RewardsIllustration: View {
    let accentColor: Color
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Coin stack
            VStack(spacing: -8) {
                ForEach(0..<3) { index in
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 50, height: 20)
                        .overlay(
                            Ellipse()
                                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                        .elevation2()
                        .offset(y: isAnimating ? 0 : CGFloat(index * 10))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(2 - index) * 0.1), value: isAnimating)
                }
            }
            
            // Sparkles
            ForEach(0..<4) { index in
                Image(systemName: "sparkle")
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.yellow)
                    .offset(
                        x: CGFloat([35, -35, 30, -30][index]),
                        y: CGFloat([-20, -15, 25, 20][index])
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0)
                    .opacity(isAnimating ? 0.8 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.3 + Double(index) * 0.05), value: isAnimating)
            }
        }
        .frame(width: 120, height: 120)
    }
}

private struct TaskGroupIllustration: View {
    let accentColor: Color
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Folder
            Image(systemName: "folder.fill")
                .font(DS.Typography.displayLarge())
                .foregroundStyle(accentColor)
            
            // Small tasks inside
            VStack(spacing: 4) {
                ForEach(0..<2) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 20, height: 4)
                }
            }
            .offset(y: 5)
            .opacity(isAnimating ? 1.0 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.3), value: isAnimating)
        }
        .frame(width: 120, height: 120)
    }
}

private struct GenericIllustration: View {
    let icon: String
    let accentColor: Color
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 120, height: 120)
            
            // Decorative ring
            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: 2)
                .frame(width: 90, height: 90)
            
            // Icon
            Image(systemName: icon)
                .font(DS.Typography.displayLarge())
                .foregroundStyle(accentColor.opacity(0.8))
        }
        .frame(width: 120, height: 120)
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
