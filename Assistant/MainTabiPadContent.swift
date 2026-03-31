// ============================================================================
// MainTabiPadContent.swift
//
// v3 IPAD NAVIGATION — Centralized via NavigationRouter
//
// WHAT CHANGED (v2 → v3):
//   - Binding<selectedTab> → router.selectedTab
//   - 3 × Binding<showAdd*> → router.present(.addTask) etc
//   - showAIChat, showCreateGroup @State → router handles via activeSheet
//   - Single NavigationStack → NavigationStack(path: router.*Path) per tab
//   - .navigationDestination(for:) registered per route type
//   - resetTrigger removed
//
// ============================================================================

import SwiftUI

struct MainTabiPadContent: View {

    // ── Router (owned by AssistantApp, injected via .environment) ──
    @Environment(NavigationRouter.self) private var router

    // ── Environment ──
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(FamilyViewModel.self) private var familyViewModel
    @Environment(FamilyMemberViewModel.self) private var familyMemberVM
    @Environment(TaskViewModel.self) private var taskVM
    @Environment(NotificationViewModel.self) private var notificationVM

    // ── iPad-only state ──
    @State private var sidebarExpanded = false
    @State private var showAIChat = false

    // MARK: - Constants

    private let collapsedWidth: CGFloat = 64
    private let expandedWidth: CGFloat = 240

    private var sidebarWidth: CGFloat {
        sidebarExpanded ? expandedWidth : collapsedWidth
    }

    // MARK: - Body

    var body: some View {
        @Bindable var router = router
        
        ZStack(alignment: .leading) {
            // Detail content area — uses per-tab NavigationStack
            detailNavigationContent
                .padding(.leading, collapsedWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Scrim when sidebar expanded
            if sidebarExpanded {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .padding(.leading, collapsedWidth)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            sidebarExpanded = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Sidebar panel
            sidebarPanel
                .zIndex(2)

            // MAI floating button (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    iPadMAIButton
                }
            }
            .padding(.trailing, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxl)
            .zIndex(3)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: sidebarExpanded)
        .tint(Color.accentPrimary)
        // MAI sheet (iPad-specific: full sheet instead of tab overlay)
        .sheet(isPresented: $showAIChat) {
            NavigationStack {
                AIChatView(isSheet: true)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .presentationBackground(Color.themeSurfacePrimary)
        }
    }

    // MARK: - Detail Navigation Content (per-tab NavigationStack)

    @ViewBuilder
    private var detailNavigationContent: some View {
        @Bindable var router = router
        
        switch router.selectedTab {
        case .home:
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
        case .calendar:
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
        case .tasks:
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
        case .mai:
            NavigationStack {
                AIChatView()
            }
        case .me:
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
        }
    }

    // MARK: - MAI Floating Button

    private var iPadMAIButton: some View {
        Button(action: { showAIChat = true }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentPrimary, Color.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DS.Control.fab, height: DS.Control.fab)
                    .shadow(color: Color.accentPrimary.opacity(0.35), radius: DS.Spacing.sm, y: DS.Spacing.xs)

                Image("samy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: DS.IconSize.xl, height: DS.IconSize.xl)
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .help(AppStrings.localized("mai"))
        .accessibilityLabel("mai")
    }

    // MARK: - Sidebar Panel

    private var sidebarPanel: some View {
        ZStack(alignment: .top) {
            Color.themeSurfacePrimary
                .shadow(
                    color: .black.opacity(sidebarExpanded ? 0.14 : 0.06),
                    radius: sidebarExpanded ? 20 : 6,
                    x: 3, y: 0
                )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                sidebarToggleButton
                sidebarDivider
                sidebarNavigation
                sidebarDivider
                Spacer()
                sidebarDivider
                sidebarMeButton
                    .padding(.bottom, DS.Spacing.lg)
            }
        }
        .frame(width: sidebarWidth, alignment: .leading)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Sidebar Toggle

    private var sidebarToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                sidebarExpanded.toggle()
            }
        }) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: sidebarExpanded ? "sidebar.left" : "line.3.horizontal")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textSecondary)
                    .frame(width: 28, height: 28)
                    .frame(width: 32)

                if sidebarExpanded {
                    Text("menu")
                        .font(DS.Typography.label())
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(.horizontal, sidebarExpanded ? DS.Spacing.md : 0)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: sidebarExpanded ? .leading : .center)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xs)
    }

    // MARK: - Sidebar Navigation (3 items)

    private var sidebarNavigation: some View {
        VStack(spacing: DS.Spacing.xxs) {
            ForEach(NavigationItem.sidebarTabs) { item in
                sidebarNavItem(item)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func sidebarNavItem(_ item: NavigationItem) -> some View {
        let isSelected = router.selectedTab == item
        let badge = badgeCount(for: item)

        return Button(action: {
            if router.selectedTab == item {
                router.popToRoot(tab: item)
            } else {
                withAnimation(.easeInOut(duration: 0.15)) {
                    router.selectedTab = item
                }
            }
        }) {
            HStack(spacing: DS.Spacing.sm) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? item.selectedIcon : item.icon)
                        .font(DS.Typography.body())
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .accentPrimary : .textSecondary)
                        .frame(width: 28, height: 28)

                    if badge > 0 && !sidebarExpanded {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: -2)
                    }
                }
                .frame(width: 32)

                if sidebarExpanded {
                    Text(LocalizedStringKey(item.localizationKey))
                        .font(DS.Typography.label())
                        .foregroundStyle(isSelected ? .textPrimary : .textSecondary)
                        .lineLimit(1)

                    Spacer()

                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textOnAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }
            }
            .padding(.horizontal, sidebarExpanded ? DS.Spacing.md : 0)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: sidebarExpanded ? .leading : .center)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color.accentPrimary.opacity(0.12) : .clear)
                    .padding(.horizontal, sidebarExpanded ? DS.Spacing.sm : DS.Spacing.xs)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .help(item.title)
    }

    // MARK: - Sidebar Me Button (bottom)

    private var sidebarMeButton: some View {
        let isSelected = router.selectedTab == .me

        return Button(action: {
            if router.selectedTab == .me {
                router.popToRoot(tab: .me)
            } else {
                withAnimation(.easeInOut(duration: 0.15)) {
                    router.selectedTab = .me
                }
            }
        }) {
            HStack(spacing: DS.Spacing.sm) {
                if let user = authViewModel.currentUser {
                    AvatarView(user: user, size: 28)
                        .frame(width: 32)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(isSelected ? .accentPrimary : .textSecondary)
                        .frame(width: 28, height: 28)
                        .frame(width: 32)
                }

                if sidebarExpanded {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(authViewModel.currentUser?.displayName ?? "me_tab")
                            .font(DS.Typography.label())
                            .foregroundStyle(isSelected ? .textPrimary : .textSecondary)
                            .lineLimit(1)

                        if let preset = authViewModel.currentUser?.resolvedPreset {
                            Text(LocalizedStringKey(preset.localizationKey))
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textTertiary)
                        }
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, sidebarExpanded ? DS.Spacing.md : 0)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: sidebarExpanded ? .leading : .center)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color.accentPrimary.opacity(0.12) : .clear)
                    .padding(.horizontal, sidebarExpanded ? DS.Spacing.sm : DS.Spacing.xs)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .help(AppStrings.localized("me_tab"))
    }

    // MARK: - Sidebar Divider

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.textTertiary.opacity(0.2))
            .frame(height: 0.5)
            .padding(.horizontal, sidebarExpanded ? DS.Spacing.lg : DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Home "+" Menu

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

    // MARK: - Helpers

    private func badgeCount(for item: NavigationItem) -> Int {
        switch item {
        case .home:  notificationVM.unreadCount
        case .tasks: taskVM.pendingVerificationTasks.count
        case .mai, .calendar, .me: 0
        }
    }
}
