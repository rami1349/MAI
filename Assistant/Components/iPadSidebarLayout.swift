//
//  iPadSidebarLayout.swift
//  Assistant
//
//  Created by Ramiro  on 2/13/26.
//  iPad-specific layout with floating overlay sidebar
//  Includes collapsible navigation, folder management, and chat FAB
//

import SwiftUI

struct iPadSidebarLayout: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @Environment(NotificationViewModel.self) var notificationVM
    
    @Binding var selectedTab: NavigationItem
    @Binding var selectedGroup: TaskGroup?
    @Binding var tasksViewMode: TasksViewMode
    @Binding var showAddHabit: Bool
    @Binding var showAddTask: Bool
    @Binding var showAddEvent: Bool
    @Binding var showAIChat: Bool
    @Binding var showSettings: Bool
    @Binding var folderOrder: [String]
    
    let resetTrigger: UUID
    let myVisibleGroups: [TaskGroup]
    
    // MARK: - Sidebar State
    
    @State private var sidebarExpanded = false
    @State private var showQuickAddMenu = false
    
    private let collapsedWidth: CGFloat = 64
    private let expandedWidth: CGFloat = 240
    
    private var sidebarWidth: CGFloat {
        sidebarExpanded ? expandedWidth : collapsedWidth
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Layer 1: Main content — always full width, constant padding
            NavigationStack {
                detailContent
            }
            .padding(.leading, collapsedWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Layer 2: Scrim (only when expanded)
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
            
            // Layer 3: THE sidebar — one panel, widens in place
            sidebarPanel
                .zIndex(2)
            
            // Layer 4: Floating chat button (bottom-right)
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
    }
    
    // MARK: - iPad Floating Chat Button
    
    private var iPadChatFAB: some View {
        Button(action: { showAIChat = true }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentPrimary, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DS.Control.fab, height: DS.Control.fab)
                    .shadow(color: Color.accentPrimary.opacity(0.35), radius: DS.Spacing.sm, y: DS.Spacing.xs)
                
                Image("samy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: DS.IconSize.lg + 4, height: DS.IconSize.lg + 4)
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
            // Background that fills through safe area
            Color.themeSurfacePrimary
                .shadow(
                    color: .black.opacity(sidebarExpanded ? 0.14 : 0.06),
                    radius: sidebarExpanded ? 20 : 6,
                    x: 3, y: 0
                )
                .ignoresSafeArea()
            
            // Content respects safe area
            VStack(spacing: 0) {
                // TOP: System Actions
                sidebarSystemActions
                
                sidebarDivider
                
                // MIDDLE: Navigation
                sidebarNavigation
                
                sidebarDivider
                
                // BOTTOM: Dynamic (folders + settings)
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
    
    // MARK: - TOP: System Actions
    
    private var sidebarSystemActions: some View {
        VStack(spacing: DS.Spacing.xxs) {
            // Sidebar toggle
            sidebarButton(
                icon: sidebarExpanded ? "sidebar.left" : "line.3.horizontal",
                label: sidebarExpanded ? "Menu" : "Menu",
                isAccented: false
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    sidebarExpanded.toggle()
                }
            }
            
            // Quick add
            sidebarButton(
                icon: "plus.circle.fill",
                label: "New...",
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
    
    // MARK: - MIDDLE: Navigation
    
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
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
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
    
    // MARK: - BOTTOM: Dynamic Section
    
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
            
            // Settings — pinned at bottom
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
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(DS.Typography.micro())
                            .foregroundStyle(Color.textTertiary)
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
                        .foregroundStyle(isAccented ? Color.accentPrimary : Color.textSecondary)
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
    
    // MARK: - Folder Context Menu
    
    @ViewBuilder
    private func folderContextMenu(for group: TaskGroup) -> some View {
        Button(role: .destructive, action: {
            Task {
                await familyViewModel.deleteTaskGroup(group)
            }
        }) {
            Label(L10n.delete, systemImage: "trash")
        }
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
    
    // MARK: - Helpers
    
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
}
