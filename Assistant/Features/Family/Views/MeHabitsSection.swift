// ============================================================================
// MeHabitsSection.swift
//
// ME TAB section 6: My Habits
//
// Wraps HabitTrackerView (week/month/year analytics) inline in the Me scroll.
// Previously behind a segmented toggle in TasksView — now has its own section.
//
// The HabitTrackerView component is reused as-is. This wrapper adds:
//   - Section header with habit count
//   - Empty state CTA when no habits exist
//
// ============================================================================

import SwiftUI

struct MeHabitsSection: View {
    @Environment(HabitViewModel.self) var habitVM
    @Binding var showAddHabit: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(DS.Typography.label())
                    .foregroundStyle(.accentOrange)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Color.accentOrange.opacity(0.1))
                    )

                Text("my_habits")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)

                if !habitVM.habits.isEmpty {
                    Text("\(habitVM.habits.count)")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.accentOrange)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.accentOrange.opacity(0.1))
                        )
                }

                Spacer()

                if !habitVM.habits.isEmpty {
                    Button(action: { showAddHabit = true }) {
                        Image(systemName: "plus")
                            .font(DS.Typography.body())
                            .foregroundStyle(.accentPrimary)
                    }
                }
            }

            if habitVM.habits.isEmpty {
                // Empty state
                emptyHabitsCTA
            } else {
                // Full habit analytics (reused component)
                HabitTrackerView(showAddHabit: $showAddHabit)
            }
        }
    }

    private var emptyHabitsCTA: some View {
        Button(action: { showAddHabit = true }) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "flame")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.accentOrange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("start_tracking_habits")
                        .font(DS.Typography.label())
                        .foregroundStyle(.textPrimary)

                    Text("start_tracking_habits_subtitle")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.accentOrange)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .strokeBorder(
                        Color.accentOrange.opacity(0.2),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
