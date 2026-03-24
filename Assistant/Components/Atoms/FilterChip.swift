//
//  FilterChip.swift
//  
//
//  Selectable filter chip component
//  Filter chip with refined elevation
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
                .font(DS.Typography.labelSmall())
                .foregroundStyle(isSelected ? .textOnAccent : .textSecondary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentPrimary : Color.themeCardBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color.themeCardBorder,
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
        .animation(DS.Animation.micro, value: isSelected)
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
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.captionMedium())
                Text(title)
                    .font(DS.Typography.labelSmall())
            }
            .foregroundStyle(isSelected ? .textOnAccent : .textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentPrimary : Color.themeCardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.themeCardBorder,
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
        .animation(DS.Animation.micro, value: isSelected)
    }
}

// MARK: - Compact Chip (for tags, smaller UI)

struct CompactChip: View {
    let title: String
    var color: Color = Color.accentPrimary
    var isOutlined: Bool = false
    
    var body: some View {
        Text(title)
            .font(DS.Typography.caption())
            .foregroundStyle(isOutlined ? color : .textOnAccent)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule()
                    .fill(isOutlined ? color.opacity(0.10) : color)
            )
    }
}

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        // Standard filter chips
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                FilterChip(title: "All", isSelected: true, action: {})
                FilterChip(title: "To Do", isSelected: false, action: {})
                FilterChip(title: "In Progress", isSelected: false, action: {})
                FilterChip(title: "Completed", isSelected: false, action: {})
            }
            .padding(.horizontal, DS.Spacing.screenH)
        }
        
        ThemeDivider()
        
        // Icon filter chips
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                IconFilterChip(title: "Today", icon: "sun.max.fill", isSelected: true, action: {})
                IconFilterChip(title: "Week", icon: "calendar", isSelected: false, action: {})
                IconFilterChip(title: "Month", icon: "calendar.badge.clock", isSelected: false, action: {})
            }
            .padding(.horizontal, DS.Spacing.screenH)
        }
        
        ThemeDivider()
        
        // Compact chips
        HStack(spacing: DS.Spacing.sm) {
            CompactChip(title: "Work", color: Color.accentPrimary)
            CompactChip(title: "Personal", color: Color.accentOrange)
            CompactChip(title: "Health", color: Color.accentGreen, isOutlined: true)
        }
    }
    .padding(.vertical, DS.Spacing.lg)
    .background(Color.themeSurfacePrimary)
}
