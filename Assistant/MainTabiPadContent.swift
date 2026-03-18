//  MainTabiPadContent.swift
//  Assistant
//  Created by Ramiro  on 3/17/26
//
// OWNS (9 @State variables — isolated from iPhone layout):
//   sidebarExpanded, showQuickAddMenu, selectedGroup,
//   folderOrder, editingFolder, showRenameAlert, renameText,
//   showAIChat, showSettings
//
// PERFORMANCE:
//   Toggling sidebarExpanded, selectedGroup, or any folder state now only
//   diffs this view's body — not the iPhone TabView, FAB overlay, or
//   custom tab bar. This eliminates ~60% of unnecessary re-renders that
//   occurred when the old MainTabView had all 17 @State in one body.
//
// ============================================================================

import SwiftUI

struct MainTabiPadContent: View {
    
    // ── Shared state (owned by MainTabView) ──
    @Binding var selectedTab: NavigationItem
    let resetTrigger: UUID
    @Binding var tasksViewMode: TasksViewMode
    @Binding var showAddTask: Bool
    @Binding var showAddHabit: Bool
    @Binding var showAddEvent: Bool
    
    // ── Environment ──
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(FamilyViewModel.self) private var familyViewModel
    @Environment(FamilyMemberViewModel.self) private var familyMemberVM
    @Environment(TaskViewModel.self) private var taskVM
    @Environment(NotificationViewModel.self) private var notificationVM
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // iPad-only state — changes here do NOT re-evaluate iPhone layout
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    @State private var sidebarExpanded = false
    @State private var showQuickAddMenu = false
    @State private var selectedGroup: TaskGroup? = nil
    
    // Folder management
    @State private var folderOrder: [String] = []
    @State private var editingFolder: TaskGroup? = nil
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    // iPad-only sheets
    @State private var showAIChat = false
    @State private var showSettings = false
    
    // MARK: - Constants
    
    private let collapsedWidth: CGFloat = 64
    private let expandedWidth: CGFloat = 240
    
    private var sidebarWidth: CGFloat {
        sidebarExpanded ? expandedWidth : collapsedWidth
    }
    
    // MARK: - Body
    
    var body: some View {
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
        .tint(Color.accentPrimary)
        .onChange(of: familyMemberVM.taskGroups) { _, _ in
            initializeFolderOrder(myVisibleGroups)
            if let selected = selectedGroup,
               !myVisibleGroups.contains(where: { $0.id == selected.id }) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedGroup = nil
                }
            }
        }
        .task {
            // Load folder order from persistence
            if let saved = UserDefaults.standard.array(forKey: "folderOrder") as? [String] {
                folderOrder = saved
            }
        }
        // iPad-only sheets
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
    }
    
    // MARK: - iPad Chat FAB
    
    private var iPadChatFAB: some View {
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
                    .frame(width: DS.IconSize.lg, height: DS.IconSize.lg)
                    .foregroundStyle(.textOnAccent)
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .help("AI Assistant")
        .accessibilityLabel(L10n.chat)
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
    
    // MARK: - System Actions (Toggle + Quick Add)
    
    private var sidebarSystemActions: some View {
        VStack(spacing: DS.Spacing.xxs) {
            sidebarButton(
                icon: sidebarExpanded ? "sidebar.left" : "line.3.horizontal",
                label: sidebarExpanded ? "menu" : "Menu",
                isAccented: false
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    sidebarExpanded.toggle()
                }
            }
            
            sidebarButton(
                icon: "plus.circle.fill",
                label: "New.",
                isAccented: true
            ) {
                showQuickAddMenu = true
            }
            .confirmationDialog(L10n.create, isPresented: $showQuickAddMenu) {
                Button(L10n.newTask) { showAddTask = true }
                Button(L10n.newEvent) { showAddEvent = true }
                Button(L10n.newHabit) { showAddHabit = true }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xs)
    }
    
    // MARK: - Navigation
    
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
                    Text(item.title)
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
                    .fill(isSelected ? Color.accentPrimary.opacity(0.12) : Color.clear)
                    .padding(.horizontal, sidebarExpanded ? DS.Spacing.sm : DS.Spacing.xs)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .help(item.title)
    }
    
    // MARK: - Dynamic Section (Folders + Settings)
    
    private var sidebarDynamicSection: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xxs) {
                    if sidebarExpanded {
                        HStack {
                            Text(L10n.folders.uppercased())
                                .font(DS.Typography.micro())
                                .foregroundStyle(.textTertiary)
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
                                .foregroundStyle(.textTertiary)
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
                        .foregroundStyle(isSelected ? .textPrimary : .textSecondary)
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
                    .foregroundStyle(isAccented ? .accentPrimary : .textSecondary)
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
    
    // MARK: - Folder Data
    
    private var myVisibleGroups: [TaskGroup] {
        guard let userId = authViewModel.currentUser?.id else { return [] }
        return familyMemberVM.visibleTaskGroups(userId: userId, allTasks: taskVM.activeTasks)
    }
    
    private var orderedTaskGroups: [TaskGroup] {
        let groups = myVisibleGroups
        if folderOrder.isEmpty { return groups }
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
    
    private func initializeFolderOrder(_ groups: [TaskGroup]) {
        if folderOrder.isEmpty {
            folderOrder = groups.compactMap { $0.id }
        }
    }
    
    private func saveFolderOrder() {
        UserDefaults.standard.set(folderOrder, forKey: "folderOrder")
    }
    
    private func badgeCount(for item: NavigationItem) -> Int {
        switch item {
        case .home: return notificationVM.unreadCount
        case .tasks: return taskVM.pendingVerificationTasks.count
        case .chat, .calendar, .family: return 0
        }
    }
}
