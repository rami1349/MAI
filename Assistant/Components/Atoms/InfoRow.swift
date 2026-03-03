//
//  InfoRow.swift
//  FamilyHub
//
//  Information row with icon, title and value
//  UPDATED: Luxury card styling with refined typography
//  NO LOGIC CHANGES - Presentation layer only
//

import SwiftUI

struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Luxury icon box with soft background
            IconBox(
                icon: icon,
                color: iconColor,
                size: 36,
                iconSize: 16
            )
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.caption())
                    .foregroundStyle(Color.textTertiary)
                Text(value)
                    .font(DS.Typography.bodyMedium())
                    .foregroundStyle(Color.textPrimary)
            }
            
            Spacer()
        }
        .standardCard()
    }
}

// MARK: - Compact Info Row (No card background)

struct CompactInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.label())
                .foregroundStyle(iconColor)
                .frame(width: 20)
            
            Text(title)
                .font(DS.Typography.bodySmall())
                .foregroundStyle(Color.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(DS.Typography.bodyMedium())
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.md) {
        InfoRow(icon: "calendar", iconColor: Color.accentPrimary, title: "Due Date", value: "Jan 15, 2026")
        InfoRow(icon: "clock", iconColor: .accentOrange, title: "Time", value: "3:00 PM")
        InfoRow(icon: "camera.fill", iconColor: .accentBlue, title: "Proof Required", value: "Photo")
        
        ThemeDivider()
            .padding(.vertical, DS.Spacing.sm)
        
        VStack(spacing: 0) {
            CompactInfoRow(icon: "calendar", iconColor: Color.accentPrimary, title: "Due Date", value: "Jan 15")
            ThemeDivider()
            CompactInfoRow(icon: "clock", iconColor: .accentOrange, title: "Time", value: "3:00 PM")
            ThemeDivider()
            CompactInfoRow(icon: "person.fill", iconColor: .accentBlue, title: "Assigned", value: "Mom")
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .elevation2()
    }
    .padding(DS.Spacing.screenH)
    .background(Color.themeSurfacePrimary)
}
