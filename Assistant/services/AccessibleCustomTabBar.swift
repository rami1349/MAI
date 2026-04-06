// ============================================================================
// AccessibleCustomTabBar.swift
//
// v2: Accessible Tab Bar — Home · Calendar · MAI · Tasks · Me
//
// Uses TabBarAccessibility from AccessibilityAnnouncer.swift for
// VoiceOver labels and hints. MAI center button is raised with gradient.
//
// NOTE: MainTabiPhoneContent uses its own inline TabBarButton.
// This component is kept for accessibility compliance and reuse.
//
// ============================================================================

import SwiftUI

struct AccessibleCustomTabBar: View {
    @Binding var selectedTab: NavigationItem
    var onTabSelected: (NavigationItem) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack {
            ForEach(NavigationItem.phoneTabs) { item in
                if item == .mai {
                    maiCenterButton
                        .tourTarget("tabbar.mai")
                } else {
                    AccessibleTabBarButton(
                        icon: selectedTab == item ? item.selectedIcon : item.icon,
                        isSelected: selectedTab == item,
                        accessibility: tabAccessibility(for: item)
                    ) {
                        onTabSelected(item)
                    }
                    .tourTarget("tabbar.\(item.rawValue)")
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.xxxl)
                .fill(.ultraThinMaterial)
                .elevation2()
        )
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("tab_bar")
    }

    // MARK: - MAI Center Button

    private var maiCenterButton: some View {
        let isSelected = selectedTab == .mai
        let size: CGFloat = dynamicTypeSize.isAccessibilitySize ? 60 : 48

        return Button(action: {
            onTabSelected(.mai)
            AccessibilityAnnouncer.shared.announce(String(localized: "mai_assistant"), haptic: .medium)
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.accentPrimary, .purple]
                                : [Color.accentPrimary.opacity(0.8), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(
                        color: Color.accentPrimary.opacity(isSelected ? 0.35 : 0.15),
                        radius: isSelected ? 8 : 4,
                        y: isSelected ? 3 : 2
                    )

                Image("samy")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 32 : DS.IconSize.xl,
                        height: dynamicTypeSize.isAccessibilitySize ? 32 : DS.IconSize.xl
                    )
            }
        }
        .offset(y: -16)
        .accessibilityLabel(String(localized: "mai_assistant_label"))
        .accessibilityHint(String(localized: "double_tap_open_mai"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Accessibility Mapping

    private func tabAccessibility(for item: NavigationItem) -> TabBarAccessibility {
        let total = 5
        switch item {
        case .home:     return .home(index: 1, total: total)
        case .calendar: return .calendar(index: 2, total: total)
        case .mai:      return .mai(index: 3, total: total)
        case .tasks:    return .tasks(index: 4, total: total)
        case .me:       return .me(index: 5, total: total)
        }
    }
}

// MARK: - Previews

#Preview("Accessible Tab Bar") {
    VStack {
        Spacer()
        AccessibleCustomTabBar(
            selectedTab: .constant(.home),
            onTabSelected: { _ in }
        )
    }
    .background(Color.gray.opacity(0.1))
}
