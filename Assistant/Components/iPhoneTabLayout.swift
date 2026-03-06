//
//  iPhoneTabLayout.swift
//
//  iPhone-specific layout with TabView and custom tab bar


import SwiftUI

struct iPhoneTabLayout: View {
    @Binding var selectedTab: NavigationItem
    @Binding var tasksViewMode: TasksViewMode
    @Binding var showAddHabit: Bool
    @Binding var showAddTask: Bool
    @Binding var showAddEvent: Bool
    
    let resetTrigger: UUID
    
    @State private var showFABMenu = false
    
    // MARK: - Environment Objects
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(TaskViewModel.self) var taskVM
    @Environment(HabitViewModel.self) var habitVM
    @Environment(NotificationViewModel.self) var notificationVM
    
    // MARK: - Chat Active State
    private var isChatActive: Bool {
        selectedTab == .chat
    }
    
    var body: some View {
        ZStack {
            // LAYER 1: Main TabView with tab bar (always rendered but hidden when chat active)
            mainTabContent
                .opacity(isChatActive ? 0 : 1)
            
            // LAYER 2: Full-screen chat overlay (only when chat active)
            if isChatActive {
                chatOverlay
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
    
    // MARK: - Main Tab Content (Home, Calendar, Tasks, Family + Tab Bar + FAB)
    
    private var mainTabContent: some View {
        ZStack(alignment: .bottom) {
            // TabView for non-chat tabs
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(
                        resetTrigger: resetTrigger,
                        authVM: authViewModel,
                        familyVM: familyViewModel,
                        taskVM: taskVM,
                        habitVM: habitVM,
                        notificationVM: notificationVM
                    )
                }
                .tag(NavigationItem.home)
                
                NavigationStack {
                    CalendarView()
                }
                .tag(NavigationItem.calendar)
                
                // Placeholder for chat tab - actual chat is in overlay
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
            .padding(.bottom, 70) // Space for custom tab bar
            
            // Custom Tab Bar
            iPhoneTabBar(
                selectedTab: $selectedTab,
                badgeProvider: { badgeCount(for: $0) }
            )
            
            // FAB Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FABMenu(
                        showFABMenu: $showFABMenu,
                        onAddTask: { showAddTask = true },
                        onAddEvent: { showAddEvent = true },
                        onAddHabit: { showAddHabit = true }
                    )
                }
            }
            .ignoresSafeArea(.keyboard)
        }
    }
    
    // MARK: - Chat Overlay (Full Screen - No Tab Bar or FAB)
    
    private var chatOverlay: some View {
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
    
    // MARK: - Badge Count
    
    private func badgeCount(for item: NavigationItem) -> Int {
        switch item {
        case .home:
            return notificationVM.unreadCount
        case .tasks:
            return taskVM.pendingVerificationTasks.count
        case .chat, .calendar, .family:
            return 0
        }
    }
}

// MARK: - iPhone Tab Bar

struct iPhoneTabBar: View {
    @Binding var selectedTab: NavigationItem
    let badgeProvider: (NavigationItem) -> Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(NavigationItem.phoneTabs) { item in
                if item == .chat {
                    ChatTabButton(isSelected: selectedTab == .chat) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = .chat
                        }
                    }
                    .tourTarget("tabbar.chat")
                } else {
                    TabBarButton(
                        item: item,
                        isSelected: selectedTab == item,
                        badge: badgeProvider(item)
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
}

// MARK: - Chat Tab Button

struct ChatTabButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xxs) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                    ? [Color.accentPrimary, .purple]
                                    : [Color.accentPrimary.opacity(0.7), Color.purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(
                            color: Color.accentPrimary.opacity(isSelected ? 0.30 : 0.12),
                            radius: isSelected ? 10 : 6,
                            x: 0,
                            y: isSelected ? 4 : 2
                        )
                    
                    Image("samy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: DS.IconSize.xl, height: DS.IconSize.xl)
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
                        .font(.system(size: DS.IconSize.md, weight: isSelected ? .semibold : .regular)) // DT-exempt: icon sizing
                        .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)
                    
                    if badge > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -2)
                    }
                }
                
                Text(item.title)
                    .font(DS.Typography.micro())
                    .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}
