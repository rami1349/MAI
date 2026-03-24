// ============================================================================
// MainTabiPhoneContent.swift
//
// v2 IPHONE NAVIGATION
//
// Tab bar: Home · Calendar · ✨ MAI ✨ · Tasks · Me
//
// WHAT CHANGED (v1 → v2):
//   - FAB (floating action button + radial menu): REMOVED entirely
//   - Context "+" in nav bar: Home→AddTask, Calendar→AddEvent, Tasks→AddTask
//   - Chat tab → MAI tab (center, raised button with sparkles icon)
//   - Family tab → Me tab (personal hub)
//   - TasksViewMode binding: REMOVED (Tasks tab is pure tasks)
//
// ARCHITECTURE:
//   MAI uses full-screen overlay (same as v1 chat), triggered by center tab.
//   Other 4 tabs are standard NavigationStack content.
//
// ============================================================================

import SwiftUI

struct MainTabiPhoneContent: View {

    // ── Shared state (owned by MainTabView) ──
    @Binding var selectedTab: NavigationItem
    let resetTrigger: UUID
    @Binding var showAddTask: Bool
    @Binding var showAddEvent: Bool
    @Binding var showAddHabit: Bool

    // ── Environment ──
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(FamilyViewModel.self) private var familyViewModel
    @Environment(FamilyMemberViewModel.self) private var familyMemberVM
    @Environment(TaskViewModel.self) private var taskVM
    @Environment(NotificationViewModel.self) private var notificationVM

    // MARK: - Derived

    private var isMAIActive: Bool { selectedTab == .mai }

    // MARK: - Body

    var body: some View {
        ZStack {
            // LAYER 1: Main content with tab bar
            mainTabContent
                .opacity(isMAIActive ? 0 : 1)

            // LAYER 2: Full-screen MAI (overlays when active)
            if isMAIActive {
                maiFullScreen
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isMAIActive)
    }

    // MARK: - Main Tab Content

    private var mainTabContent: some View {
        TabView(selection: $selectedTab) {
            // ── Home ─────────────────────────────────────────
            NavigationStack {
                HomeView(
                    resetTrigger: resetTrigger,
                    authVM: authViewModel,
                    familyVM: familyViewModel,
                    taskVM: taskVM,
                    habitVM: familyViewModel.habitVM,
                    notificationVM: notificationVM
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        homeCreateMenu
                    }
                }
            }
            .tag(NavigationItem.home)

            // ── Calendar ─────────────────────────────────────
            NavigationStack {
                CalendarView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            contextPlusButton { showAddEvent = true }
                        }
                    }
            }
            .tag(NavigationItem.calendar)

            // ── MAI (placeholder — actual UI is overlay) ─────
            Color.clear
                .tag(NavigationItem.mai)

            // ── Tasks (pure execution — no habits toggle) ────
            NavigationStack {
                TasksView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            contextPlusButton { showAddTask = true }
                        }
                    }
            }
            .tag(NavigationItem.tasks)

            // ── Me (personal hub — replaces Family) ──────────
            NavigationStack {
                MeView()
            }
            .tag(NavigationItem.me)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            customTabBar
        }
    }

    // MARK: - MAI Full Screen

    private var maiFullScreen: some View {
        NavigationStack {
            AIChatView(onBack: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .home
                }
            })
            .toolbar(.hidden, for: .navigationBar)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Home "+" Menu (all 3 creation options)

    private var homeCreateMenu: some View {
        Menu {
            Button(action: { showAddTask = true }) {
                Label("add_task", systemImage: "checkmark.circle")
            }
            Button(action: { showAddEvent = true }) {
                Label("add_event", systemImage: "calendar.badge.plus")
            }
            Button(action: { showAddHabit = true }) {
                Label("add_habit", systemImage: "flame")
            }
        } label: {
            Image(systemName: "plus")
                .font(DS.Typography.body())
                .foregroundStyle(.accentPrimary)
        }
    }

    // MARK: - Context "+" Button

    /// Nav bar "+" that opens the context-appropriate creation sheet.
    /// Home + Tasks → AddTask, Calendar → AddEvent.
    private func contextPlusButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            DS.Haptics.light()
            action()
        }) {
            Image(systemName: "plus")
                .font(DS.Typography.body())
                .foregroundStyle(.accentPrimary)
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(NavigationItem.phoneTabs) { item in
                if item == .mai {
                    maiTabButton
                        .tourTarget("tabbar.mai")
                } else {
                    TabBarButton(
                        item: item,
                        isSelected: selectedTab == item,
                        badge: badgeCount(for: item)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = item
                        }
                    }
                    .tourTarget("tabbar.\(item.rawValue)")
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.xs)
        .background(
            Color.themeCardBackground
                .elevation2()
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - MAI Tab Button (Raised Center)

    private var maiTabButton: some View {
        let isSelected = selectedTab == .mai

        return Button(action: {
            DS.Haptics.selection()
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = .mai
            }
        }) {
            VStack(spacing: DS.Spacing.xxs) {
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
                        .frame(width: 44, height: 44)
                        .shadow(
                            color: Color.accentPrimary.opacity(isSelected ? 0.35 : 0.15),
                            radius: isSelected ? 8 : 4,
                            y: isSelected ? 3 : 2
                        )

                    Image("samy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: DS.IconSize.xl, height: DS.IconSize.xl)
                }
                .offset(y: -8)

                Text("mai")
                    .font(DS.Typography.micro())
                    .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)
                    .offset(y: -8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func badgeCount(for item: NavigationItem) -> Int {
        switch item {
        case .home:  notificationVM.unreadCount
        case .tasks: taskVM.pendingVerificationTasks.count
        case .mai, .calendar, .me: 0
        }
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let item: NavigationItem
    let isSelected: Bool
    let badge: Int
    let action: () -> Void

    var body: some View {
        Button(action: {
            DS.Haptics.selection()
            action()
        }) {
            VStack(spacing: DS.Spacing.xxs) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? item.selectedIcon : item.icon)
                        .font(DS.Typography.body())
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)

                    if badge > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: -2)
                    }
                }

                Text(LocalizedStringKey(item.localizationKey))
                    .font(DS.Typography.micro())
                    .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}
