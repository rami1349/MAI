//
//  MainTabView.swift
//
//  UPDATED: Hide tab bar and FAB when chat is active on iPhone
//



import SwiftUI

// MARK: - Navigation Item Model

enum NavigationItem: String, CaseIterable, Identifiable {
    case home
    case calendar
    case chat
    case tasks
    case family
    
    var id: String { rawValue }
    
    /// All 5 tabs for iPhone tab bar
    static var phoneTabs: [NavigationItem] { allCases }
    
    /// 4 tabs for iPad sidebar (chat uses floating button instead)
    static var sidebarTabs: [NavigationItem] { allCases.filter { $0 != .chat } }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .calendar: return "Calendar"
        case .chat: return "Chat"
        case .tasks: return "Tasks"
        case .family: return "Family"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .calendar: return "calendar"
        case .chat: return "samy"
        case .tasks: return "checkmark.circle.fill"
        case .family: return "person.2.fill"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .calendar: return "calendar"
        case .chat: return "samy"
        case .tasks: return "checkmark.circle.fill"
        case .family: return "person.2.fill"
        }
    }
}

// MARK: - Tasks View Mode
enum TasksViewMode {
    case tasks
    case habits
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @Environment(NotificationViewModel.self) var notificationVM
    @Environment(LocalizationManager.self) var localization
    @Environment(ThemeManager.self) var themeManager
    @Environment(TourManager.self) var tourManager
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Navigation state
    @State private var selectedTab: NavigationItem = .home
    
    // Reset trigger for views
    @State private var resetTrigger = UUID()
    
    // Folder management
    @State private var folderOrder: [String] = []
    @State private var editingFolder: TaskGroup? = nil
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    // MARK: - Tasks/Habits Mode (required by TasksView)
    @State private var tasksViewMode: TasksViewMode = .tasks
    @State private var showAddHabit = false
    @State private var showAddTask = false
    @State private var showAddEvent = false
    
    // iPad AI Chat sheet
    @State private var showAIChat = false
    
    // iPad Settings sheet
    @State private var showSettings = false
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    // MARK: - Chat Active State (for hiding tab bar and FAB)
    private var isChatActive: Bool {
        selectedTab == .chat
    }
    
    var body: some View {
        @Bindable var familyViewModel = familyViewModel
        Group {
            if isRegularWidth {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            await loadInitialData()
        }
        .onChange(of: familyMemberVM.taskGroups) { _, _ in
            initializeFolderOrder(myVisibleGroups)
            // Auto-clear if selected group was deleted or no longer visible
            if let selected = selectedGroup,
               !myVisibleGroups.contains(where: { $0.id == selected.id }) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedGroup = nil
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAIChat) {
            NavigationStack {
                AIChatView(isSheet: true)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .globalErrorBanner(errorMessage: $familyViewModel.errorMessage)
        .offlineBanner()
        .withFeatureTour()
        .onAppear {
            tourManager.startIfNeeded()
        }
    }
    
    
    // MARK: - Sidebar State
    
    @State private var sidebarExpanded = false
    @State private var showQuickAddMenu = false
    @State private var selectedGroup: TaskGroup? = nil
    
    private let collapsedWidth: CGFloat = 64
    private let expandedWidth: CGFloat = 240
    
    private var sidebarWidth: CGFloat {
        sidebarExpanded ? expandedWidth : collapsedWidth
    }
    
    // MARK: - iPad Layout (Floating Overlay Sidebar)
    
    private var iPadLayout: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                detailContent
            }
            .padding(.leading, collapsedWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            
            sidebarPanel
                .zIndex(2)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    iPadChatFAB
                }
            }
            .padding(.trailing, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxl)
            .zIndex(3)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: sidebarExpanded)
        .tint(.accentPrimary)
    }
    
    // MARK: - iPad Floating Chat Button
    
    private var iPadChatFAB: some View {
        Button(action: { showAIChat = true }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentPrimary, .accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DS.Control.fab, height: DS.Control.fab)
                    .shadow(color: Color.accentPrimary.opacity(0.35), radius: DS.Spacing.sm, y: DS.Spacing.xs)
                
                Image("samy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: DS.IconSize.lg, height: DS.IconSize.lg)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .help("AI Assistant")
        .accessibilityLabel(L10n.chat)
    }
    
    // MARK: - Sidebar Panel (Single Panel)
    //
    // Section order:
    //   TOP:    System actions (toggle, quick-add)
    //   MIDDLE: Navigation (Home, Calendar, Tasks, Family)
    //   BOTTOM: Dynamic content (task folders scrollable, settings)
    
    private var sidebarPanel: some View {
        ZStack(alignment: .top) {
            Color.themeSurfacePrimary
                .shadow(
                    color: .black.opacity(sidebarExpanded ? 0.14 : 0.06),
                    radius: sidebarExpanded ? 20 : 6,
                    x: 3, y: 0
                )
                .ignoresSafeArea()
            
            // Content respects safe area
            VStack(spacing: 0) {
                sidebarSystemActions
                sidebarDivider
                sidebarNavigation
                sidebarDivider
                sidebarDynamicSection
            }
        }
        .frame(width: sidebarWidth, alignment: .leading)
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Sidebar Divider
    
    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.textTertiary.opacity(0.2))
            .frame(height: 0.5)
            .padding(.horizontal, sidebarExpanded ? DS.Spacing.lg : DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
    }
    
    // MARK: - TOP: System Actions (Toggle + Quick Add)
    
    private var sidebarSystemActions: some View {
        VStack(spacing: DS.Spacing.xxs) {
            // Sidebar toggle
            sidebarButton(
                icon: sidebarExpanded ? "sidebar.left" : "line.3.horizontal",
                label: sidebarExpanded ? "menu" : "Menu",
                isAccented: false
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    sidebarExpanded.toggle()
                }
            }
            
            // Quick add
            sidebarButton(
                icon: "plus.circle.fill",
                label: "New.",
                isAccented: true
            ) {
                showQuickAddMenu = true
            }
            .confirmationDialog("Create", isPresented: $showQuickAddMenu) {
                Button("New Task") { showAddTask = true }
                Button("New Event") { showAddEvent = true }
                Button("New Habit") { showAddHabit = true }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xs)
    }
    
    // MARK: - MIDDLE: Navigation (iPad sidebar – excludes chat)
    
    private var sidebarNavigation: some View {
        VStack(spacing: DS.Spacing.xxs) {
            ForEach(NavigationItem.sidebarTabs) { item in
                sidebarNavItem(item)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
    
    private func sidebarNavItem(_ item: NavigationItem) -> some View {
        let isSelected = selectedTab == item && selectedGroup == nil
        let badge = badgeCount(for: item)
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedGroup = nil
                selectedTab = item
            }
        }) {
            HStack(spacing: DS.Spacing.sm) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? item.selectedIcon : item.icon)
                        .font(DS.Typography.body()).fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Color.accentPrimary : Color.textSecondary)
                        .frame(width: 28, height: 28)
                    
                    // Badge dot (collapsed) / count is shown as trailing text (expanded)
                    if badge > 0 && !sidebarExpanded {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: -2)
                    }
                }
                .frame(width: 32)
                
                if sidebarExpanded {
                    Text(item.title)
                        .font(DS.Typography.label())
                        .foregroundStyle(isSelected ? .textPrimary : .textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.white)
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
                    .fill(isSelected ? Color.accentPrimary.opacity(0.12) : Color.clear)
                    .padding(.horizontal, sidebarExpanded ? DS.Spacing.sm : DS.Spacing.xs)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .help(item.title)
    }
    
    // MARK: - BOTTOM: Dynamic Section (Folders + Settings)
    
    private var sidebarDynamicSection: some View {
        VStack(spacing: 0) {
            // Scrollable folder list
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xxs) {
                    if sidebarExpanded {
                        // Section header
                        HStack {
                            Text(L10n.folders.uppercased())
                                .font(DS.Typography.micro())
                                .foregroundStyle(Color.textTertiary)
                                .tracking(0.8)
                            
                            Spacer()
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.xs)
                        .padding(.bottom, DS.Spacing.xxs)
                    }
                    
                    if orderedTaskGroups.isEmpty {
                        if sidebarExpanded {
                            Text(L10n.noFoldersYet)
                                .font(DS.Typography.bodySmall())
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, DS.Spacing.md)
                        }
                    } else {
                        ForEach(orderedTaskGroups, id: \.id) { group in
                            sidebarFolderItem(group)
                        }
                    }
                }
                .padding(.top, DS.Spacing.xs)
            }
            
            sidebarDivider
            
            // Settings – pinned at bottom
            sidebarButton(
                icon: "gearshape.fill",
                label: "Settings",
                isAccented: false
            ) {
                showSettings = true
            }
            .padding(.bottom, DS.Spacing.lg)
        }
    }
    
    // MARK: - Folder Item
    
    private func sidebarFolderItem(_ group: TaskGroup) -> some View {
        let count = taskVM.tasksFor(groupId: group.id ?? "").count
        let isSelected = selectedGroup?.id == group.id
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedGroup = group
            }
            // Auto-collapse after selection
            if sidebarExpanded {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    sidebarExpanded = false
                }
            }
        }) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: group.icon)
                    .font(DS.Typography.body())
                    .foregroundStyle(Color(hex: group.color))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: group.color).opacity(isSelected ? 0.25 : 0.12))
                    )
                    .frame(width: 32)
                
                if sidebarExpanded {
                    Text(group.name)
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            .padding(.horizontal, sidebarExpanded ? DS.Spacing.md : 0)
            .padding(.vertical, DS.Spacing.xs + 2)
            .frame(maxWidth: .infinity, alignment: sidebarExpanded ? .leading : .center)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color(hex: group.color).opacity(0.08) : Color.clear)
                    .padding(.horizontal, sidebarExpanded ? DS.Spacing.sm : DS.Spacing.xs)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .help(group.name)
        .contextMenu {
            folderContextMenu(for: group)
        }
    }
    
    // MARK: - Reusable Sidebar Button
    
    private func sidebarButton(
        icon: String,
        label: String,
        isAccented: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.body()).fontWeight(isAccented ? .semibold : .regular)
                    .foregroundStyle(isAccented ? Color.accentPrimary : Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .frame(width: 32)
                
                if sidebarExpanded {
                    Text(label)
                        .font(DS.Typography.label())
                        .foregroundStyle(isAccented ? .accentPrimary : .textSecondary)
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
        .help(label)
    }
    
    // MARK: - iPhone Layout
    //
    // UPDATED: Hides tab bar and FAB when chat is active
    // Uses ZStack layers:
    //   Layer 1: TabView with non-chat content + tab bar + FAB (hidden when chat active)
    //   Layer 2: Full-screen chat overlay (visible when chat active)
    
    @State private var showFABMenu = false
    
    private var iPhoneLayout: some View {
        ZStack {
            // LAYER 1: Main content with tab bar and FAB
            // Fades out when chat is active
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
            // Close FAB menu when switching tabs
            if showFABMenu {
                withAnimation(.easeOut(duration: 0.15)) {
                    showFABMenu = false
                }
            }
        }
    }
    
    // MARK: - Main Tab Content (with tab bar and FAB)
    
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
                
                // Placeholder for chat - actual chat is in overlay
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
            
            // FAB: Floating Add Button
            fabOverlay
        }
    }
    
    // MARK: - Chat Full Screen (No tab bar, no FAB)
    
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
    
    // MARK: - FAB (Floating Action Button)
    //
    // Bottom-right floating "+" that expands into a radial menu
    // with New Task, New Event, New Habit options.
    // Scrim behind menu dismisses on tap.
    
    private var fabOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            // Scrim when menu is open
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
                // Menu items (visible when expanded)
                if showFABMenu {
                    fabMenuItem(
                        icon: "checkmark.circle.fill",
                        label: L10n.newTask,
                        color: .accentYellow,
                        delay: 0.0
                    ) {
                        showFABMenu = false
                        showAddTask = true
                    }
                    
                    fabMenuItem(
                        icon: "calendar.badge.plus",
                        label: L10n.newEvent,
                        color: .accentOrange,
                        delay: 0.04
                    ) {
                        showFABMenu = false
                        showAddEvent = true
                    }
                    
                    fabMenuItem(
                        icon: "flame.fill",
                        label: L10n.newHabit,
                        color: .accentGreen,
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
                        .foregroundStyle(.white)
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
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.themeCardBackground)
                            .elevation2()
                    )
                
                Image(systemName: icon)
                    .font(DS.Typography.heading())
                    .foregroundStyle(.white)
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
    
    // MARK: - Sidebar Folders Data
    
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
    
    
    /// Only show groups the user created or has tasks in.
    private var myVisibleGroups: [TaskGroup] {
        guard let userId = authViewModel.currentUser?.id else { return [] }
        return familyMemberVM.visibleTaskGroups(userId: userId, allTasks: taskVM.activeTasks)
    }
    
    private var orderedTaskGroups: [TaskGroup] {
        let groups = myVisibleGroups
        if folderOrder.isEmpty {
            return groups
        }
        return groups.sorted { a, b in
            let aIndex = folderOrder.firstIndex(of: a.id ?? "") ?? Int.max
            let bIndex = folderOrder.firstIndex(of: b.id ?? "") ?? Int.max
            return aIndex < bIndex
        }
    }
    
    @ViewBuilder
    private func folderContextMenu(for group: TaskGroup) -> some View {
        Button(action: {
            editingFolder = group
            renameText = group.name
            showRenameAlert = true
        }) {
            Label(L10n.rename, systemImage: "pencil")
        }
        
        Button(role: .destructive, action: {
            Task {
                await familyViewModel.deleteTaskGroup(group)
            }
        }) {
            Label(L10n.delete, systemImage: "trash")
        }
    }
    
    private func folderDragPreview(_ group: TaskGroup) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: group.icon)
                .foregroundStyle(Color(hex: group.color))
            Text(group.name)
                .font(DS.Typography.label())
        }
        .padding(DS.Spacing.sm)
        .background(Color.themeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private func moveFolders(from source: IndexSet, to destination: Int) {
        var ids = orderedTaskGroups.compactMap { $0.id }
        ids.move(fromOffsets: source, toOffset: destination)
        folderOrder = ids
        saveFolderOrder()
    }
    
    private func initializeFolderOrder(_ groups: [TaskGroup]) {
        if folderOrder.isEmpty {
            folderOrder = groups.compactMap { $0.id }
        }
    }
    
    private func saveFolderOrder() {
        UserDefaults.standard.set(folderOrder, forKey: "folderOrder")
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        if let group = selectedGroup {
            TaskGroupDetailView(taskGroup: group)
        } else {
            switch selectedTab {
            case .home:
                HomeView(
                    resetTrigger: resetTrigger,
                    authVM: authViewModel,
                    familyVM: familyViewModel,
                    taskVM: taskVM,
                    habitVM: familyViewModel.habitVM,
                    notificationVM: notificationVM
                )
            case .calendar:
                CalendarView()
            case .chat:
                AIChatView()
            case .tasks:
                TasksView(selectedMode: $tasksViewMode, showAddHabit: $showAddHabit)
            case .family:
                FamilyView()
            }
        }
    }
    
    // MARK: - Custom Tab Bar (iPhone) – 5 tabs with raised center chat
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(NavigationItem.phoneTabs) { item in
                if item == .chat {
                    // Raised center chat button (FAB style)
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
    
    // MARK: - Chat Tab Button (Raised Center – FAB Style)
    
    private var chatTabButton: some View {
        let isSelected = selectedTab == .chat
        
        return Button(action: {
            DS.Haptics.selection() // Haptic on tab switch
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
                                ? [.accentPrimary, .purple]
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
                        .foregroundStyle(.white)
                }
                .offset(y: -8) // Raise above other tabs
                
                Text(L10n.chat)
                    .font(DS.Typography.micro())
                    .foregroundStyle(isSelected ? Color.accentPrimary : Color.textTertiary)
                    .offset(y: -8) // Match raise
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() async {
        guard let user = authViewModel.currentUser,
              let familyId = user.familyId,
              let userId = user.id else { return }
        
        await familyViewModel.loadFamilyData(familyId: familyId, userId: userId)
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        await familyViewModel.loadCalendarEvents(from: startOfMonth, to: endOfMonth)
        await familyViewModel.loadHabitLogs(from: startOfMonth, to: endOfMonth)
        
        // Load folder order
        if let saved = UserDefaults.standard.array(forKey: "folderOrder") as? [String] {
            folderOrder = saved
        }
    }
}


// MARK: - Previews

#Preview("iPad") {
    MainTabView()
        .environment(AuthViewModel())
        .environment({ let vm = FamilyViewModel(); return vm }())
        .environment({ let vm = FamilyViewModel(); return vm.familyMemberVM }())
        .environment({ let vm = FamilyViewModel(); return vm.taskVM }())
        .environment({ let vm = FamilyViewModel(); return vm.calendarVM }())
        .environment({ let vm = FamilyViewModel(); return vm.habitVM }())
        .environment({ let vm = FamilyViewModel(); return vm.notificationVM }())
        .environment(ThemeManager.shared)
        .environment(LocalizationManager.shared)
        .environment(TourManager.shared)
    
}

#Preview("iPhone") {
    MainTabView()
        .environment(AuthViewModel())
        .environment({ let vm = FamilyViewModel(); return vm }())
        .environment({ let vm = FamilyViewModel(); return vm.familyMemberVM }())
        .environment({ let vm = FamilyViewModel(); return vm.taskVM }())
        .environment({ let vm = FamilyViewModel(); return vm.calendarVM }())
        .environment({ let vm = FamilyViewModel(); return vm.habitVM }())
        .environment({ let vm = FamilyViewModel(); return vm.notificationVM }())
        .environment(ThemeManager.shared)
        .environment(LocalizationManager.shared)
        .environment(TourManager.shared)
}
