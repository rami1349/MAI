// ============================================================================
// MainTabiPhoneContent.swift
//
// v3 IPHONE NAVIGATION — Centralized via NavigationRouter
//
// WHAT CHANGED (v2 → v3):
//   - Binding<selectedTab> → router.selectedTab
//   - 3 × Binding<showAdd*> → router.present(.addTask) etc
//   - showCreateGroup @State → router.present(.createGroup)
//   - Per-tab NavigationStack() → NavigationStack(path: router.*Path)
//   - resetTrigger → router.handleTabReselection() (standard iOS UX)
//   - .navigationDestination(for:) registered per route type
//
// ============================================================================

import SwiftUI

struct MainTabiPhoneContent: View {

    // ── Router (owned by AssistantApp, injected via .environment) ──
    @Environment(NavigationRouter.self) private var router

    // ── Environment ──
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(FamilyViewModel.self) private var familyViewModel
    @Environment(FamilyMemberViewModel.self) private var familyMemberVM
    @Environment(TaskViewModel.self) private var taskVM
    @Environment(NotificationViewModel.self) private var notificationVM

    // MARK: - Derived

    private var isMAIActive: Bool { router.selectedTab == .mai }

    // MARK: - Body

    var body: some View {
        @Bindable var router = router
        
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
        @Bindable var router = router
        
        return TabView(selection: $router.selectedTab) {
            // ── Home ─────────────────────────────────────────
            NavigationStack(path: $router.homePath) {
                HomeView(
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
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .todayTasks:
                        TodayTasksView()
                    case .taskGroup(let id):
                        if let group = familyMemberVM.getTaskGroup(by: id) {
                            TaskGroupDetailView(taskGroup: group)
                        }
                    }
                }
            }
            .tag(NavigationItem.home)

            // ── Calendar ─────────────────────────────────────
            NavigationStack(path: $router.calendarPath) {
                CalendarView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            contextPlusButton { router.present(.addEvent) }
                        }
                    }
                    .navigationDestination(for: CalendarRoute.self) { route in
                        switch route {
                        case .eventDetail(let id):
                            if let event = familyViewModel.calendarVM.events.first(where: { $0.id == id }) {
                                EventDetailView(event: event)
                            }
                        }
                    }
            }
            .tag(NavigationItem.calendar)

            // ── MAI (placeholder — actual UI is overlay) ─────
            Color.clear
                .tag(NavigationItem.mai)

            // ── Tasks (pure execution) ────────────────────────
            NavigationStack(path: $router.tasksPath) {
                TasksView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            contextPlusButton { router.present(.addTask()) }
                        }
                    }
                    .navigationDestination(for: TasksRoute.self) { route in
                        switch route {
                        case .taskGroupDetail(let id):
                            if let group = familyMemberVM.getTaskGroup(by: id) {
                                TaskGroupDetailView(taskGroup: group)
                            }
                        }
                    }
            }
            .tag(NavigationItem.tasks)

            // ── Me (personal hub) ─────────────────────────────
            NavigationStack(path: $router.mePath) {
                MeView()
                    .navigationDestination(for: MeRoute.self) { route in
                        switch route {
                        case .settings:
                            SettingsView()
                        case .memberDetail(let id):
                            if let member = familyMemberVM.getMember(by: id) {
                                MemberDetailView(member: member)
                            }
                        }
                    }
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
                    router.selectedTab = .home
                }
            })
            .toolbar(.hidden, for: .navigationBar)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Home "+" Menu (all creation options)

    private var homeCreateMenu: some View {
        Menu {
            Button(action: { router.present(.addTask()) }) {
                Label("add_task", systemImage: "checkmark.circle")
            }
            Button(action: { router.present(.addEvent) }) {
                Label("add_event", systemImage: "calendar.badge.plus")
            }
            Button(action: { router.present(.addHabit) }) {
                Label("add_habit", systemImage: "flame")
            }
            Divider()
            Button(action: { router.present(.createGroup) }) {
                Label("new_group", systemImage: "folder.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
                .font(DS.Typography.body())
                .foregroundStyle(.accentPrimary)
        }
    }

    // MARK: - Context "+" Button

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
                        isSelected: router.selectedTab == item,
                        badge: badgeCount(for: item)
                    ) {
                        if router.selectedTab == item {
                            // Tap already-selected tab → pop to root (standard iOS)
                            router.popToRoot(tab: item)
                        } else {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                router.selectedTab = item
                            }
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
        let isSelected = router.selectedTab == .mai

        return Button(action: {
            DS.Haptics.selection()
            withAnimation(.easeInOut(duration: 0.15)) {
                router.selectedTab = .mai
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
