//
//  PrimaryButton.swift
//  FamilyHub
//
//  Primary and secondary button components
//  Primary button with accent glow elevation
//  NO LOGIC CHANGES - Presentation layer only
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(DS.Typography.label())
            }
            .foregroundStyle(.textOnAccent)
            .frame(maxWidth: .infinity, minHeight: DS.Control.large)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isDisabled ? Color.textTertiary : Color.accentPrimary)
            )
            // Accent elevation with colored glow
            .shadow(
                color: isDisabled ? Color.clear : Color.accentPrimary.opacity(0.25),
                radius: 12,
                x: 0,
                y: 4
            )
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(Color.accentPrimary)
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(DS.Typography.label())
            }
            .foregroundStyle(isDisabled ? .textTertiary : .accentPrimary)
            .frame(maxWidth: .infinity, minHeight: DS.Control.large)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isDisabled ? Color.fill : Color.accentPrimary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isDisabled ? Color.themeDivider : Color.accentPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Tertiary Button (Text-only)

struct TertiaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading = false
    var isDisabled = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(Color.accentPrimary)
                        .scaleEffect(0.7)
                }
                if let icon {
                    Image(systemName: icon)
                        .font(DS.Typography.label())
                }
                Text(title)
                    .font(DS.Typography.labelSmall())
            }
            .foregroundStyle(isDisabled ? .textTertiary : .accentPrimary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .disabled(isDisabled || isLoading)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.md) {
        PrimaryButton(title: "Primary Button", action: {})
        PrimaryButton(title: "Loading...", isLoading: true, action: {})
        PrimaryButton(title: "Disabled", isDisabled: true, action: {})
        
        Divider()
            .padding(.vertical, DS.Spacing.sm)
        
        SecondaryButton(title: "Secondary Button", action: {})
        SecondaryButton(title: "Loading...", isLoading: true, action: {})
        SecondaryButton(title: "Disabled", isDisabled: true, action: {})
        
        Divider()
            .padding(.vertical, DS.Spacing.sm)
        
        TertiaryButton(title: "Tertiary Button", icon: "arrow.right", action: {})
        TertiaryButton(title: "Disabled", isDisabled: true, action: {})
    }
    .padding(DS.Spacing.lg)
    .background(Color.themeSurfacePrimary)
}
