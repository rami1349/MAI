//
//  FeatureTour.swift
//  FamilyHub
//
//  Lightweight first-time feature tour.
//  Replaces: FeatureTourManager, CoachMarkOverlay, OnboardingChecklist, FirstSuccessTour
//
//  Flow:
//  1. Home is empty on first launch → inline CTA buttons visible
//  2. Tour highlights each inline CTA: Add Task, Add Habit, Add Event
//  3. Tour moves to tab bar, explaining each tab in 1-2 sentences
//  4. Done → persisted, never shown again
//

import SwiftUI

// MARK: - Tour Step

enum TourStep: Int, CaseIterable, Identifiable {
    // Home inline CTAs
    case addTask = 0
    case addHabit
    case addEvent
    // Tab bar
    case tabHome
    case tabCalendar
    case tabChat
    case tabTasks
    case tabFamily
    
    var id: Int { rawValue }
    
    /// The tourTarget ID this step points to
    var targetId: String {
        switch self {
        case .addTask:    return "home.addTask"
        case .addHabit:   return "home.addHabit"
        case .addEvent:   return "home.addEvent"
        case .tabHome:    return "tabbar.home"
        case .tabCalendar: return "tabbar.calendar"
        case .tabChat:    return "tabbar.chat"
        case .tabTasks:   return "tabbar.tasks"
        case .tabFamily:  return "tabbar.family"
        }
    }
    
    var title: String {
        switch self {
        case .addTask:    return "Create Tasks"
        case .addHabit:   return "Track Habits"
        case .addEvent:   return "Add Events"
        case .tabHome:    return "Home"
        case .tabCalendar: return "Calendar"
        case .tabChat:    return "Samy"
        case .tabTasks:   return "Tasks & Habits"
        case .tabFamily:  return "Family"
        }
    }
    
    var message: String {
        switch self {
        case .addTask:
            return "Create your first task to organize your family's to-dos and chores."
        case .addHabit:
            return "Build daily habits like reading or exercise and track your streaks."
        case .addEvent:
            return "Add birthdays, appointments, and family events to your schedule."
        case .tabHome:
            return "Your dashboard — see tasks, habits, and upcoming events at a glance."
        case .tabCalendar:
            return "View your family's schedule in a monthly or weekly calendar."
        case .tabChat:
            return "Ask Samy for help with tasks, homework, or family planning."
        case .tabTasks:
            return "Manage all your tasks and track daily habits in one place."
        case .tabFamily:
            return "See family members, invite others, and manage your household."
        }
    }
    
    /// Tooltip goes above for tab bar items, below for home CTAs
    var tooltipPosition: TooltipPlacement {
        switch self {
        case .addTask, .addHabit, .addEvent:
            return .below
        case .tabHome, .tabCalendar, .tabChat, .tabTasks, .tabFamily:
            return .above
        }
    }
    
    enum TooltipPlacement {
        case above, below
    }
}

// MARK: - Tour Manager

@MainActor
@Observable
final class TourManager {
    static let shared = TourManager()
    
    // MARK: - Published State
    
    var isActive = false
    var currentStep: TourStep?
    
    // MARK: - Persistence
    
    @ObservationIgnored private let hasCompletedKey = "featureTour_completed_v3"
    
    var hasCompletedTour: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedKey)
    }
    
    private init() {}
    
    // MARK: - Tour Control
    
    /// Start the tour if it hasn't been completed yet
    func startIfNeeded() {
        guard !hasCompletedTour else { return }
        // Small delay so the home view has rendered its tour targets
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.8))
            guard let self, !self.hasCompletedTour else { return }
            self.currentStep = .addTask
            withAnimation(.easeOut(duration: 0.3)) {
                self.isActive = true
            }
        }
    }
    
    func next() {
        guard let current = currentStep else { return }
        let all = TourStep.allCases
        if let idx = all.firstIndex(of: current), idx + 1 < all.count {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep = all[idx + 1]
            }
        } else {
            finish()
        }
    }
    
    func skip() {
        finish()
    }
    
    func finish() {
        withAnimation(.easeOut(duration: 0.25)) {
            isActive = false
        }
        UserDefaults.standard.set(true, forKey: hasCompletedKey)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.3))
            self?.currentStep = nil
        }
    }
    
    // MARK: - Convenience
    
    var stepIndex: Int {
        guard let step = currentStep else { return 0 }
        return TourStep.allCases.firstIndex(of: step) ?? 0
    }
    
    var totalSteps: Int { TourStep.allCases.count }
    
    var isLastStep: Bool {
        currentStep == TourStep.allCases.last
    }
    
    /// Reset tour (for Settings → "Replay Tour")
    func reset() {
        UserDefaults.standard.removeObject(forKey: hasCompletedKey)
        currentStep = nil
        isActive = false
    }
    
}

// MARK: - Tour Target Preference Key

struct TourTargetKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Tour Target Modifier

struct TourTargetModifier: ViewModifier {
    let targetId: String
    
    /// After tour is complete, skip anchorPreference entirely.
    /// Avoids 24 preference key reductions on every render cycle for the lifetime of the app.
    private var tourComplete: Bool {
        TourManager.shared.hasCompletedTour
    }
    
    func body(content: Content) -> some View {
        if tourComplete {
            content
        } else {
            content
                .anchorPreference(key: TourTargetKey.self, value: .bounds) { anchor in
                    [targetId: anchor]
                }
        }
    }
}

extension View {
    /// Marks this view as a tour target that can be highlighted during the feature tour
    func tourTarget(_ id: String) -> some View {
        modifier(TourTargetModifier(targetId: id))
    }
}

// MARK: - Tour Overlay

struct TourOverlay: View {
    let targets: [String: Anchor<CGRect>]
    @Environment(TourManager.self) var tourManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geo in
            if tourManager.isActive, let step = tourManager.currentStep {
                let targetRect = resolveTarget(step: step, in: geo)
                
                ZStack {
                    // Dimmed backdrop with spotlight cutout
                    SpotlightCutout(targetRect: targetRect, cornerRadius: 12)
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.7 : 0.55))
                        .ignoresSafeArea()
                        .onTapGesture { tourManager.next() }
                    
                    // Highlight border around target
                    if let rect = targetRect {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.accentPrimary, lineWidth: 2.5)
                            .frame(width: rect.width + 12, height: rect.height + 12)
                            .position(x: rect.midX, y: rect.midY)
                    }
                    
                    // Tooltip card
                    TourTooltip(
                        step: step,
                        targetRect: targetRect,
                        containerSize: geo.size,
                        safeArea: geo.safeAreaInsets
                    )
                    .environment(tourManager)
                }
                .transition(.opacity)
            }
        }
    }
    
    private func resolveTarget(step: TourStep, in geo: GeometryProxy) -> CGRect? {
        guard let anchor = targets[step.targetId] else { return nil }
        return geo[anchor]
    }
}

// MARK: - Spotlight Cutout Shape

struct SpotlightCutout: Shape {
    let targetRect: CGRect?
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        if let target = targetRect {
            let spotlight = target.insetBy(dx: -6, dy: -6)
            let rounded = Path(roundedRect: spotlight, cornerRadius: cornerRadius)
            path = path.subtracting(rounded)
        }
        return path
    }
}

// MARK: - Tooltip Arrow

struct TooltipArrow: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX - 8, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX + 8, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Tour Tooltip

struct TourTooltip: View {
    let step: TourStep
    let targetRect: CGRect?
    let containerSize: CGSize
    let safeArea: EdgeInsets
    
    @Environment(TourManager.self) var tourManager
    @Environment(\.colorScheme) var colorScheme
    
    private let cardWidth: CGFloat = 300
    
    var body: some View {
        VStack(spacing: 0) {
            if placement == .below {
                TooltipArrow()
                    .fill(cardBackground)
                    .frame(width: 16, height: 8)
            }
            
            // Card content
            VStack(spacing: DS.Spacing.md) {
                // Title + message
                VStack(spacing: DS.Spacing.xs) {
                    Text(step.title)
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                    
                    Text(step.message)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Progress + buttons
                HStack {
                    // Step counter
                    Text("\(tourManager.stepIndex + 1) of \(tourManager.totalSteps)")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.textTertiary)
                    
                    Spacer()
                    
                    // Skip
                    Button(action: tourManager.skip) {
                        Text("Skip")
                            .font(DS.Typography.label())
                            .foregroundStyle(.textTertiary)
                    }
                    .padding(.trailing, DS.Spacing.sm)
                    
                    // Next / Done
                    Button(action: tourManager.next) {
                        Text(tourManager.isLastStep ? "Done" : "Next")
                            .font(DS.Typography.label())
                            .foregroundStyle(.textOnAccent)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(Capsule().fill(Color.accentPrimary))
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .elevation3()
            )
            .frame(width: cardWidth)
            
            if placement == .above {
                TooltipArrow()
                    .fill(cardBackground)
                    .frame(width: 16, height: 8)
                    .rotationEffect(.degrees(180))
            }
        }
        .position(tooltipPosition)
    }
    
    // MARK: - Layout Calculation
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.12) : .white
    }
    
    private var placement: TourStep.TooltipPlacement {
        step.tooltipPosition
    }
    
    private var tooltipPosition: CGPoint {
        guard let rect = targetRect else {
            return CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        }
        
        let estimatedHeight: CGFloat = 140
        let gap: CGFloat = 16
        
        var x = rect.midX
        var y: CGFloat
        
        switch placement {
        case .below:
            y = rect.maxY + gap + estimatedHeight / 2 + 8 // +8 for arrow
        case .above:
            y = rect.minY - gap - estimatedHeight / 2 - 8
        }
        
        // Clamp X within screen bounds
        let halfCard = cardWidth / 2
        x = max(halfCard + 12, min(containerSize.width - halfCard - 12, x))
        
        // Clamp Y within safe area
        let minY = safeArea.top + estimatedHeight / 2 + 12
        let maxY = containerSize.height - safeArea.bottom - estimatedHeight / 2 - 12
        y = max(minY, min(maxY, y))
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Tour Container Modifier

struct TourContainerModifier: ViewModifier {
    @Environment(TourManager.self) var tourManager
    
    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(TourTargetKey.self) { targets in
                if tourManager.isActive {
                    TourOverlay(targets: targets)
                        .environment(tourManager)
                }
            }
    }
}

extension View {
    /// Enables feature tour overlay on this view hierarchy
    func withFeatureTour() -> some View {
        modifier(TourContainerModifier())
    }
}
