//
//  InfoRow.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
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
        HStack(spacing: Luxury.Spacing.md) {
            // Luxury icon box with soft background
            LuxuryIconBox(
                icon: icon,
                color: iconColor,
                size: 36,
                iconSize: 16
            )
            
            VStack(alignment: .leading, spacing: Luxury.Spacing.xxs) {
                Text(title)
                    .font(Luxury.Typography.caption())
                    .foregroundColor(.textTertiary)
                Text(value)
                    .font(Luxury.Typography.bodyMedium())
                    .foregroundColor(.textPrimary)
            }
            
            Spacer()
        }
        .luxuryCard()
    }
}

// MARK: - Compact Info Row (No card background)

struct CompactInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: Luxury.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(title)
                .font(Luxury.Typography.bodySmall())
                .foregroundColor(.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(Luxury.Typography.bodyMedium())
                .foregroundColor(.textPrimary)
        }
        .padding(.vertical, Luxury.Spacing.xs)
    }
}

#Preview {
    VStack(spacing: Luxury.Spacing.md) {
        InfoRow(icon: "calendar", iconColor: .accentPrimary, title: "Due Date", value: "Jan 15, 2026")
        InfoRow(icon: "clock", iconColor: .accentOrange, title: "Time", value: "3:00 PM")
        InfoRow(icon: "camera.fill", iconColor: .accentBlue, title: "Proof Required", value: "Photo")
        
        LuxuryDivider()
            .padding(.vertical, Luxury.Spacing.sm)
        
        VStack(spacing: 0) {
            CompactInfoRow(icon: "calendar", iconColor: .accentPrimary, title: "Due Date", value: "Jan 15")
            LuxuryDivider()
            CompactInfoRow(icon: "clock", iconColor: .accentOrange, title: "Time", value: "3:00 PM")
            LuxuryDivider()
            CompactInfoRow(icon: "person.fill", iconColor: .accentBlue, title: "Assigned", value: "Mom")
        }
        .padding(Luxury.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Luxury.Radius.md)
                .fill(Color.themeCardBackground)
        )
        .luxuryLevel2()
    }
    .padding(Luxury.Spacing.screenH)
    .background(Color.themeSurfacePrimary)
}
