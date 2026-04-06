//
//  QuickHabitsWidget.swift
//  Assistant
//
//  Created by Ramiro  on 1/25/26.
//  Today's Habits widget with interactive checkboxes for HomeView
//

import SwiftUI
import UIKit

// MARK: - Quick Habits Widget
struct QuickHabitsWidget: View {
    @Environment(FamilyViewModel.self) var familyViewModel

    @Environment(HabitViewModel.self) var habitVM
    @State private var togglingHabits: Set<String> = []
    
    private let calendar = Calendar.current
    private let today = Date.now
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.accentOrange)
                
                Text("todays_habits")
                    .font(DS.Typography.subheading())
                    .fontWeight(.bold)
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                // Completion indicator
                let completed = completedCount
                let total = habitVM.habits.count
                if total > 0 {
                    Text("\(completed)/\(total)")
                        .font(DS.Typography.caption())
                        .fontWeight(.medium)
                        .foregroundStyle(completed == total ? .accentGreen : .textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(completed == total ? Color.accentGreen.opacity(0.1) : Color.backgroundSecondary)
                        )
                }
            }
            
            if habitVM.habits.isEmpty {
                  emptyStateView
              } else {
                  VStack(spacing: 4) {
                      // Show max 3 habits visible, scroll for more
                      ScrollView(showsIndicators: false) {
                          VStack(spacing: 8) {
                              ForEach(habitVM.habits) { habit in
                                  QuickHabitRow(
                                      habit: habit,
                                      isCompleted: habitVM.isHabitCompleted(habitId: habit.id ?? "", date: today),
                                      isToggling: togglingHabits.contains(habit.id ?? ""),
                                      onToggle: {
                                          let id = habit.id ?? ""
                                          guard !togglingHabits.contains(id) else { return }
                                          togglingHabits.insert(id)
                                          Task {
                                              await familyViewModel.toggleHabitCompletion(habit: habit, date: today)
                                              togglingHabits.remove(id)
                                              DS.Haptics.light()
                                          }
                                      }
                                  )
                              }
                          }
                      }
                      .frame(maxHeight: maxScrollHeight)
                      
                      // Show scroll hint if more than 3 habits
                      if habitVM.habits.count > 3 {
                          HStack(spacing: 4) {
                              Image(systemName: "chevron.down")
                                  .font(DS.Typography.micro())
                          }
                          .foregroundStyle(.textTertiary)
                          .padding(.top, 4)
                      }
                  }
              }
          }
          .padding(DS.Spacing.lg)
          .background(
              RoundedRectangle(cornerRadius: DS.Radius.xl)
                  .fill(Color.backgroundCard)
          )
          .elevation1()
      }
    
    // PERFORMANCE: Use pre-computed count from ViewModel
    // Avoids repeated DateFormatter.string(from:) calls per habit
    private var completedCount: Int {
        habitVM.todayCompletedHabitCount(habits: habitVM.habits)
    }
    // Height for 3 habit rows (each row ~52pt + 8pt spacing)
    private var maxScrollHeight: CGFloat {
        let rowHeight: CGFloat = 52
        let spacing: CGFloat = 8
        let visibleRows = 3
        return CGFloat(visibleRows) * rowHeight + CGFloat(visibleRows - 1) * spacing
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.dashed")
                .font(DS.Typography.heading())
                .foregroundStyle(.textTertiary)
            Text("no_habits_short")
                .font(DS.Typography.label())
                .fontWeight(.medium)
                .foregroundStyle(.textPrimary)
            Text("add_habits_to_track")
                .font(DS.Typography.caption())
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Quick Habit Row
struct QuickHabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    var isToggling: Bool = false
    let onToggle: () -> Void
    
    @State private var animateCheck = false
    
    private var habitColor: Color { Color(hex: habit.colorHex) }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                animateCheck = true
            }
            onToggle()
            
            // Reset animation
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                animateCheck = false
            }
        }) {
            HStack(spacing: 14) {
                // Interactive checkbox with animation
                ZStack {
                    Circle()
                        .stroke(habitColor, lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isCompleted {
                        Circle()
                            .fill(habitColor)
                            .frame(width: 28, height: 28)
                            .scaleEffect(animateCheck ? 1.15 : 1.0)
                        
                        Image(systemName: "checkmark")
                            .font(DS.Typography.label())
                            .foregroundStyle(.textOnAccent)
                            .scaleEffect(animateCheck ? 1.2 : 1.0)
                    }
                }
                
                // Habit icon
                Image(systemName: habit.icon)
                    .font(DS.Typography.body())
                    .foregroundStyle(habitColor)
                    .frame(width: 24)
                
                // Habit name
                Text(habit.name)
                    .font(DS.Typography.label())
                    .fontWeight(.medium)
                    .foregroundStyle(isCompleted ? .textSecondary : .textPrimary)
                    .strikethrough(isCompleted, color: Color.textSecondary)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCompleted ? habitColor.opacity(0.08) : Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCompleted ? habitColor.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
        .opacity(isToggling ? 0.6 : 1)
    }
}

// MARK: - Preview
#Preview {
    let familyVM = FamilyViewModel()
    QuickHabitsWidget()
        .padding(20)
        .background(Color.backgroundPrimary)
        .environment(familyVM)
        .environment(familyVM.familyMemberVM)
        .environment(familyVM.taskVM)
        .environment(familyVM.calendarVM)
        .environment(familyVM.habitVM)
        .environment(familyVM.notificationVM)
}
