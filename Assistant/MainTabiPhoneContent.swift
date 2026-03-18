//  MainTabiPhoneContent.swift
//  Assistant
//
//  Created by Ramiro  on 3/17/26.//
// OWNS:
//   @State showFABMenu — iPhone-only. Changes here do NOT re-evaluate
//   the iPad sidebar, folder management, or any iPad-only state.
//
// RECEIVES (as Binding):
//   selectedTab, tasksViewMode, showAddTask, showAddHabit, showAddEvent
//   — shared state owned by MainTabView.
//
// PERFORMANCE:
//   Toggling showFABMenu now only diffs this view's body (~250 lines),
//   not the full 1,005-line MainTabView that included the entire iPad sidebar.
//
// ============================================================================

import SwiftUI

struct MainTabiPhoneContent: View {
    
    // ── Shared state (owned by MainTabView, passed as bindings) ──
    @Binding var selectedTab: NavigationItem
    let resetTrigger: UUID
    @Binding var tasksViewMode: TasksViewMode
    @Binding var showAddTask: Bool
    @Binding var showAddHabit: Bool
    @Binding var showAddEvent: Bool
    
    // ── Environment (read from @Observable injection) ──
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(FamilyViewModel.self) private var familyViewModel
    @Environment(FamilyMemberViewModel.self) private var familyMemberVM
    @Environment(TaskViewModel.self) private var taskVM
    @Environment(NotificationViewModel.self) private var notificationVM
    
    // ── iPhone-only state (isolated — changes don't propagate to iPad) ──
    @State private var showFABMenu = false
    
    // MARK: - Derived
    
    private var isChatActive: Bool {
        selectedTab == .chat
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // LAYER 1: Main content with tab bar and FAB
            mainTabContent
                .opacity(isChatActive ? 0 : 1)
            
            // LAYER 2: Full-screen chat (overlays everything when active)
            if isChatActive {
                chatFullScreen
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isChatActive)
        .onChange(of: selectedTab) { _, _ in
            if showFABMenu {
                withAnimation(.easeOut(duration: 0.15)) {
                    showFABMenu = false
                }
            }
        }
    }
    
    // MARK: - Main Tab Content
    
    private var mainTabContent: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(
                        resetTrigger: resetTrigger,
                        authVM: authViewModel,
                        familyVM: familyViewModel,
                        taskVM: taskVM,
                        habitVM: familyViewModel.habitVM,
                        notificationVM: notificationVM
                    )
                }
                .tag(NavigationItem.home)
                
                NavigationStack {
                    CalendarView()
                }
                .tag(NavigationItem.calendar)
                
                // Placeholder — actual chat is in overlay
                Color.clear
                    .tag(NavigationItem.chat)
                
                NavigationStack {
                    TasksView(selectedMode: $tasksViewMode, showAddHabit: $showAddHabit)
                }
                .tag(NavigationItem.tasks)
                
                NavigationStack {
                    FamilyView()
                }
                .tag(NavigationItem.family)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                customTabBar
            }
            
            // FAB overlay
            fabOverlay
        }
    }
    
    // MARK: - Chat Full Screen
    
    private var chatFullScreen: some View {
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
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(NavigationItem.phoneTabs) { item in
                if item == .chat {
                    chatTabButton
                        .tourTarget("tabbar.chat")
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
    
    // MARK: - Chat Tab Button (Raised Center)
    
    private var chatTabButton: some View {
        let isSelected = selectedTab == .chat
        
        return Button(action: {
            DS.Haptics.selection()
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = .chat
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
                        .foregroundStyle(.textOnAccent)
                }
                .offset(y: -8)
                
                Text(L10n.chat)
                    .font(DS.Typography.micro())
                    .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)
                    .offset(y: -8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - FAB Overlay
    
    private var fabOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            // Scrim
            if showFABMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showFABMenu = false
                        }
                    }
                    .transition(.opacity)
            }
            
            VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                if showFABMenu {
                    fabMenuItem(
                        icon: "checkmark.circle.fill",
                        label: L10n.newTask,
                        color: Color.accentYellow,
                        delay: 0.0
                    ) {
                        showFABMenu = false
                        showAddTask = true
                    }
                    
                    fabMenuItem(
                        icon: "calendar.badge.plus",
                        label: L10n.newEvent,
                        color: Color.accentOrange,
                        delay: 0.04
                    ) {
                        showFABMenu = false
                        showAddEvent = true
                    }
                    
                    fabMenuItem(
                        icon: "flame.fill",
                        label: L10n.newHabit,
                        color: Color.accentGreen,
                        delay: 0.08
                    ) {
                        showFABMenu = false
                        showAddHabit = true
                    }
                }
                
                // Main FAB button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showFABMenu.toggle()
                    }
                }) {
                    Image(systemName: showFABMenu ? "xmark" : "plus")
                        .font(.system(size: DS.IconSize.lg, weight: .semibold)) // DT-exempt: icon sizing
                        .foregroundStyle(.textOnAccent)
                        .frame(width: DS.Control.fab, height: DS.Control.fab)
                        .background(
                            Circle()
                                .fill(
                                    showFABMenu
                                    ? Color.textSecondary
                                    : Color.accentPrimary
                                )
                                .shadow(color: Color.accentPrimary.opacity(showFABMenu ? 0 : 0.35), radius: DS.Spacing.sm, y: DS.Spacing.xs)
                        )
                        .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fab_add_button")
                .accessibilityLabel(L10n.addNewItem)
            }
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Avatar.xl) // clear the tab bar
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: showFABMenu)
    }
    
    // MARK: - FAB Menu Item
    
    private func fabMenuItem(
        icon: String,
        label: String,
        color: Color,
        delay: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Text(label)
                    .font(DS.Typography.label())
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.themeCardBackground)
                            .elevation2()
                    )
                
                Image(systemName: icon)
                    .font(DS.Typography.heading())
                    .foregroundStyle(.textOnAccent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(color)
                            .shadow(color: color.opacity(0.3), radius: 4, y: 2)
                    )
            }
        }
        .buttonStyle(.plain)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity).animation(
                    .spring(response: 0.3, dampingFraction: 0.7).delay(delay)
                ),
                removal: .scale(scale: 0.5).combined(with: .opacity).animation(
                    .spring(response: 0.2, dampingFraction: 0.9)
                )
            )
        )
    }
    
    // MARK: - Helpers
    
    private func badgeCount(for item: NavigationItem) -> Int {
        switch item {
        case .home: return notificationVM.unreadCount
        case .tasks: return taskVM.pendingVerificationTasks.count
        case .chat, .calendar, .family: return 0
        }
    }
}
