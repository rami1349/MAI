//
//  TasksView.swift
//  FamilyHub
//
//  Tasks view container with tab toggle between Tasks and Habits.
//  MyTasksView and StatCard are in MyTasksView.swift
//

import SwiftUI

struct TasksView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(ThemeManager.self) var themeManager
    
    // MARK: - Environment
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Bindings from MainTabView
    @Binding var selectedMode: TasksViewMode
    @Binding var showAddHabit: Bool
    
    // MARK: - State
    
    @State private var selectedMainTab: MainTab = .tasks
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    enum MainTab: CaseIterable {
        case tasks
        case habits
        
        var displayName: String {
            switch self {
            case .tasks: return L10n.myTasks
            case .habits: return L10n.myHabits
            }
        }
        
        var accessibilityHint: String {
            switch self {
            case .tasks: return "Double tap to view and manage your tasks"
            case .habits: return "Double tap to view and track your habits"
            }
        }
    }
    
    var body: some View {
        ZStack {
            AdaptiveBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                mainTabToggle
                
                if selectedMainTab == .tasks {
                    MyTasksView()
                } else {
                    HabitTrackerView(showAddHabit: $showAddHabit)
                }
            }
        }
        .navigationTitle(selectedMainTab == .tasks ? L10n.tasks : L10n.habits)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedMainTab) { _, newValue in
            selectedMode = newValue == .habits ? TasksViewMode.habits : TasksViewMode.tasks
        }
    }
    
    // MARK: - Tab Toggle
    
    private var mainTabToggle: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button(action: {
                    if reduceMotion {
                        selectedMainTab = tab
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMainTab = tab
                        }
                    }
                    
                    AccessibilityAnnouncer.shared.announce(
                        "\(tab.displayName) selected",
                        haptic: .light
                    )
                }) {
                    Text(tab.displayName)
                        .font(DS.Typography.label())
                        .foregroundStyle(selectedMainTab == tab ? .textOnAccent : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DS.Control.standard)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .fill(selectedMainTab == tab ? Color.accentPrimary : Color.clear)
                        )
                }
                .accessibilityLabel(tab.displayName)
                .accessibilityHint(tab.accessibilityHint)
                .accessibilityValue(selectedMainTab == tab ? "Selected" : "")
                .accessibilityAddTraits(selectedMainTab == tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.backgroundSecondary)
        )
        .adaptiveHorizontalPadding()
        .padding(.vertical, DS.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.viewSelector)
    }
}

#Preview {
    let familyVM = FamilyViewModel()
    TasksView(selectedMode: .constant(TasksViewMode.tasks), showAddHabit: .constant(false))
        .environment(AuthViewModel())
        .environment(familyVM)
        .environment(familyVM.familyMemberVM)
        .environment(familyVM.taskVM)
        .environment(familyVM.calendarVM)
        .environment(familyVM.habitVM)
        .environment(familyVM.notificationVM)
        .environment(ThemeManager.shared)
}
