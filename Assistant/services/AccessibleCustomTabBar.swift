//
//  AccessibleCustomTabBar.swift
//
//  Accessible Custom Tab Bar with full VoiceOver, Dynamic Type, and haptic support.
//  Includes tour targets for feature onboarding.
//

import SwiftUI

// MARK: - Accessible Custom Tab Bar

struct AccessibleCustomTabBar: View {
    @Binding var selectedTab: Int
    var currentContext: TabContext
    var onAddTapped: () -> Void
    var onTabSelected: (Int) -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum TabContext: String {
        case home = "item"
        case calendar = "event"
        case tasks = "task"
        case habits = "habit"
        case family = "member"
    }
    
    private var fabSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large:
            return 56
        case .xLarge, .xxLarge:
            return 64
        default:
            return 72
        }
    }
    
    var body: some View {
        HStack {
            // Home Tab
            AccessibleTabBarButton(
                icon: "house.fill",
                isSelected: selectedTab == 0,
                accessibility: .home(index: 1, total: 4)
            ) {
                onTabSelected(0)
            }
            .tourTarget("tabbar.home")
            
            // Calendar Tab
            AccessibleTabBarButton(
                icon: "calendar",
                isSelected: selectedTab == 1,
                accessibility: .calendar(index: 2, total: 4)
            ) {
                onTabSelected(1)
            }
            .tourTarget("tabbar.calendar")
            
            // Center FAB - Context-aware accessibility
            fabButton
                .tourTarget("tabbar.addButton")
                .offset(y: -20)
            
            // Tasks Tab
            AccessibleTabBarButton(
                icon: "checkmark.circle.fill",
                isSelected: selectedTab == 2,
                accessibility: .tasks(index: 3, total: 4)
            ) {
                onTabSelected(2)
            }
            .tourTarget("tabbar.tasks")
            
            // Family Tab
            AccessibleTabBarButton(
                icon: "person.2.fill",
                isSelected: selectedTab == 3,
                accessibility: .family(index: 4, total: 4)
            ) {
                onTabSelected(3)
            }
            .tourTarget("tabbar.family")
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.xxxl)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: -3)
        )
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }
    
    // MARK: - FAB Button
    
    private var fabButton: some View {
        Button(action: {
            onAddTapped()
            AccessibilityAnnouncer.shared.announce(
                "Creating new \(currentContext.rawValue)",
                haptic: .medium
            )
        }) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary)
                    .frame(width: fabSize, height: fabSize)
                    .shadow(color: Color.accentPrimary.opacity(0.4), radius: 10, x: 0, y: 4)
                
                Image(systemName: "plus")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel("Add new \(currentContext.rawValue)")
        .accessibilityHint("Double tap to create a new \(currentContext.rawValue)")
        .accessibilityIdentifier("fab_add_button")
    }
}

// MARK: - Preview

#Preview("Accessible Tab Bar") {
    VStack {
        Spacer()
        AccessibleCustomTabBar(
            selectedTab: .constant(0),
            currentContext: .home,
            onAddTapped: {},
            onTabSelected: { _ in }
        )
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Dynamic Type Sizes") {
    VStack(spacing: 40) {
        AccessibleCustomTabBar(
            selectedTab: .constant(2),
            currentContext: .tasks,
            onAddTapped: {},
            onTabSelected: { _ in }
        )
        .environment(\.dynamicTypeSize, .large)
        
        AccessibleCustomTabBar(
            selectedTab: .constant(2),
            currentContext: .tasks,
            onAddTapped: {},
            onTabSelected: { _ in }
        )
        .environment(\.dynamicTypeSize, .accessibility3)
    }
}
