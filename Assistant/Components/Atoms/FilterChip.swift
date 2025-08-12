//
//  FilterChip.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//  Selectable filter chip component
//  UPDATED: Luxury styling with refined elevation
//  NO LOGIC CHANGES - Presentation layer only
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Luxury.Typography.labelSmall())
                .foregroundColor(isSelected ? .white : .textSecondary)
                .padding(.horizontal, Luxury.Spacing.md)
                .padding(.vertical, Luxury.Spacing.xs)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentPrimary : Color.themeCardBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color.luxuryCardBorder,
                            lineWidth: 0.5
                        )
                )
                // Subtle elevation for selected state
                .shadow(
                    color: isSelected ? Color.accentPrimary.opacity(0.20) : Color.clear,
                    radius: 6,
                    x: 0,
                    y: 2
                )
        }
        .buttonStyle(.plain)
        .animation(Luxury.Animation.micro, value: isSelected)
    }
}

// MARK: - Icon Filter Chip

struct IconFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Luxury.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(Luxury.Typography.labelSmall())
            }
            .foregroundColor(isSelected ? .white : .textSecondary)
            .padding(.horizontal, Luxury.Spacing.md)
            .padding(.vertical, Luxury.Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentPrimary : Color.themeCardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.luxuryCardBorder,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? Color.accentPrimary.opacity(0.20) : Color.clear,
                radius: 6,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .animation(Luxury.Animation.micro, value: isSelected)
    }
}

// MARK: - Compact Chip (for tags, smaller UI)

struct CompactChip: View {
    let title: String
    var color: Color = .accentPrimary
    var isOutlined: Bool = false
    
    var body: some View {
        Text(title)
            .font(Luxury.Typography.caption())
            .foregroundColor(isOutlined ? color : .white)
            .padding(.horizontal, Luxury.Spacing.sm)
            .padding(.vertical, Luxury.Spacing.xxs)
            .background(
                Capsule()
                    .fill(isOutlined ? color.opacity(0.10) : color)
            )
    }
}

#Preview {
    VStack(spacing: Luxury.Spacing.lg) {
        // Standard filter chips
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Luxury.Spacing.sm) {
                FilterChip(title: "All", isSelected: true, action: {})
                FilterChip(title: "To Do", isSelected: false, action: {})
                FilterChip(title: "In Progress", isSelected: false, action: {})
                FilterChip(title: "Completed", isSelected: false, action: {})
            }
            .padding(.horizontal, Luxury.Spacing.screenH)
        }
        
        LuxuryDivider()
        
        // Icon filter chips
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Luxury.Spacing.sm) {
                IconFilterChip(title: "Today", icon: "sun.max.fill", isSelected: true, action: {})
                IconFilterChip(title: "Week", icon: "calendar", isSelected: false, action: {})
                IconFilterChip(title: "Month", icon: "calendar.badge.clock", isSelected: false, action: {})
            }
            .padding(.horizontal, Luxury.Spacing.screenH)
        }
        
        LuxuryDivider()
        
        // Compact chips
        HStack(spacing: Luxury.Spacing.sm) {
            CompactChip(title: "Work", color: .accentPrimary)
            CompactChip(title: "Personal", color: .accentOrange)
            CompactChip(title: "Health", color: .accentGreen, isOutlined: true)
        }
    }
    .padding(.vertical, Luxury.Spacing.lg)
    .background(Color.themeSurfacePrimary)
}
