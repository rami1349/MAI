//
//  InfoRow.swift
//  
//
//  Information row with icon, title and value
//  Info row with card styling and refined typography
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
            // Icon box with soft background
            IconBox(
                icon: icon,
                color: iconColor,
                size: 36,
                iconSize: 16
            )
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
                Text(value)
                    .font(DS.Typography.bodyMedium())
                    .foregroundStyle(.textPrimary)
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
                .foregroundStyle(.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(DS.Typography.bodyMedium())
                .foregroundStyle(.textPrimary)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.md) {
        InfoRow(icon: "calendar", iconColor: Color.accentPrimary, title: "Due Date", value: "Jan 15, 2026")
        InfoRow(icon: "clock", iconColor: Color.accentOrange, title: "Time", value: "3:00 PM")
        InfoRow(icon: "camera.fill", iconColor: Color.accentBlue, title: "Proof Required", value: "Photo")
        
        ThemeDivider()
            .padding(.vertical, DS.Spacing.sm)
        
        VStack(spacing: 0) {
            CompactInfoRow(icon: "calendar", iconColor: Color.accentPrimary, title: "Due Date", value: "Jan 15")
            ThemeDivider()
            CompactInfoRow(icon: "clock", iconColor: Color.accentOrange, title: "Time", value: "3:00 PM")
            ThemeDivider()
            CompactInfoRow(icon: "person.fill", iconColor: Color.accentBlue, title: "Assigned", value: "Mom")
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
