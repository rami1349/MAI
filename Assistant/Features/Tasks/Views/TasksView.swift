// ============================================================================
// TasksView.swift
//
// v2: PURE TASK EXECUTION
//
// WHAT CHANGED (v1 → v2):
//   - Habits toggle (Tasks/Habits segmented control): REMOVED
//   - selectedMode: TasksViewMode binding: REMOVED
//   - showAddHabit binding: REMOVED
//   - Habit analytics now live in the Me tab
//   - This view shows only: To Do / In Progress / Done
//
// ============================================================================

import SwiftUI

struct TasksView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(ThemeManager.self) var themeManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ZStack {
            AdaptiveBackgroundView()
                .ignoresSafeArea()

            MyTasksView()
        }
        .navigationTitle("tasks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let familyVM = FamilyViewModel()
    NavigationStack {
        TasksView()
            .environment(AuthViewModel())
            .environment(familyVM)
            .environment(familyVM.familyMemberVM)
            .environment(familyVM.taskVM)
            .environment(familyVM.calendarVM)
            .environment(familyVM.habitVM)
            .environment(familyVM.notificationVM)
            .environment(ThemeManager.shared)
    }
}
