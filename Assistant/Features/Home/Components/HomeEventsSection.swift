//  HomeEventsSection.swift
//  Assistant
//
//  Created by Ramiro  on 3/23/26.
//
// SLOT 5: My Events (Today/Tomorrow)
//
// Compact list of upcoming events for today and tomorrow only. Max 5 items.
// "See all" links to Calendar tab. Falls away cleanly when there are none.
//
// No role checks, no capability checks — events are visible to everyone.
// This replaces both HomeTimelineSection and HomeWeekEventsSection.
//

import SwiftUI

struct HomeEventsSection: View {
    let events: [UpcomingEvent]
    let onSeeAll: () -> Void
    let onDeleteEvent: (UpcomingEvent) async -> Void

    private var displayEvents: [UpcomingEvent] {
        Array(events.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(DS.Typography.label())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )

                Text("today_tomorrow_events")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)

                Spacer()

                Button(action: onSeeAll) {
                    Text("see_all")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.accentPrimary)
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)

            // Event rows
            VStack(spacing: DS.Spacing.xs) {
                ForEach(displayEvents) { event in
                    HomeEventRow(event: event, onDelete: {
                        Task { await onDeleteEvent(event) }
                    })
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
        }
    }
}

// MARK: - Event Row

struct HomeEventRow: View {
    let event: UpcomingEvent
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(event.color.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: event.icon)
                    .font(DS.Typography.label())
                    .foregroundStyle(event.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(DS.Typography.label())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.xs) {
                    Text(dayLabel)
                        .font(DS.Typography.micro())
                        .foregroundStyle(dayColor)

                    if let subtitle = event.subtitle {
                        Text("·")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                        Text(subtitle)
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Time
            Text(event.date.formatted(.dateTime.hour().minute()))
                .font(DS.Typography.captionMedium())
                .foregroundStyle(.textSecondary)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
    }

    private var dayLabel: String {
        if event.daysUntil == 0 {
            return AppStrings.localized("today")
        } else {
            return AppStrings.localized("tomorrow")
        }
    }

    private var dayColor: Color {
        event.daysUntil == 0 ? .accentOrange : .textSecondary
    }
}
