//
//  FABMenu.swift
//  FamilyHub
//
//  Floating Action Button with expandable menu
//  Floating action button with Level 3 elevation
//  NO LOGIC CHANGES - Presentation layer only
//

import SwiftUI

struct FABMenu: View {
    @Binding var showFABMenu: Bool
    let onAddTask: () -> Void
    let onAddEvent: () -> Void
    let onAddHabit: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Scrim when menu is open - Softer, less harsh
            if showFABMenu {
                Color.themeScrim
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(DS.Animation.smooth) {
                            showFABMenu = false
                        }
                    }
                    .transition(.opacity)
            }
            
            VStack(alignment: .trailing, spacing: DS.Spacing.sm) {
                // Menu items (visible when expanded)
                if showFABMenu {
                    FABMenuItem(
                        icon: "checkmark.circle.fill",
                        label: "New Task",
                        color: Color.accentPrimary,
                        delay: 0.0
                    ) {
                        showFABMenu = false
                        onAddTask()
                    }
                    
                    FABMenuItem(
                        icon: "calendar.badge.plus",
                        label: "New Event",
                        color: Color.accentOrange,
                        delay: 0.04
                    ) {
                        showFABMenu = false
                        onAddEvent()
                    }
                    
                    FABMenuItem(
                        icon: "flame.fill",
                        label: "New Habit",
                        color: Color.accentGreen,
                        delay: 0.08
                    ) {
                        showFABMenu = false
                        onAddHabit()
                    }
                }
                
                // Main FAB button
                FABButton(isExpanded: showFABMenu) {
                    withAnimation(DS.Animation.smooth) {
                        showFABMenu.toggle()
                    }
                }
            }
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Avatar.xl) // clear the tab bar
        }
        .animation(DS.Animation.smooth, value: showFABMenu)
    }
}

// MARK: - FAB Button

struct FABButton: View {
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isExpanded ? "xmark" : "plus")
                .font(.system(size: DS.IconSize.lg, weight: .semibold)) // DT-exempt: icon sizing
                .foregroundStyle(.textOnAccent)
                .frame(width: DS.Control.fab, height: DS.Control.fab)
                .background(
                    Circle()
                        .fill(isExpanded ? Color.textSecondary : Color.accentPrimary)
                )
                // Level 3 elevation for floating element
                .shadow(
                    color: isExpanded ? Color.clear : Color.accentPrimary.opacity(0.30),
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fab_add_button")
        .accessibilityLabel(L10n.addNewItem)
    }
}

// MARK: - FAB Menu Item

struct FABMenuItem: View {
    let icon: String
    let label: String
    let color: Color
    let delay: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                // Label pill with Level 2 elevation
                Text(label)
                    .font(DS.Typography.labelSmall())
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.themeCardBackground)
                    )
                    .elevation2()
                
                // Icon circle with colored glow
                Image(systemName: icon)
                    .font(DS.Typography.heading())
                    .foregroundStyle(.textOnAccent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(color)
                    )
                    .shadow(
                        color: color.opacity(0.30),
                        radius: 8,
                        x: 0,
                        y: 3
                    )
            }
        }
        .buttonStyle(.plain)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity).animation(
                    DS.Animation.bouncy.delay(delay)
                ),
                removal: .scale(scale: 0.5).combined(with: .opacity).animation(
                    DS.Animation.micro
                )
            )
        )
    }
}
