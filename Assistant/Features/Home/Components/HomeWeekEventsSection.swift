//
//  HomeWeekEventsSection.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//



import SwiftUI

struct HomeWeekEventsSection: View {
    let events: [UpcomingEvent]
    let isLoading: Bool
    let onDeleteEvent: (UpcomingEvent) -> Void
    
    @State private var isExpanded: Bool = true
    
    private var shouldDefaultExpanded: Bool {
        events.count >= 1 && events.count <= 4
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader
            
            if isExpanded {
                eventContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .onAppear { isExpanded = shouldDefaultExpanded }
    }
    
    // MARK: - Header
    
    private var sectionHeader: some View {
        Button(action: { isExpanded.toggle() }) {
            HStack(spacing: DS.Spacing.sm) {
                // Icon badge
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(Color.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text(L10n.thisWeek)
                    .font(DS.Typography.subheading())
                    .foregroundColor(Color.textPrimary)
                
                // Count badge
                if !events.isEmpty {
                    Text("\(events.count)")
                        .font(DS.Typography.captionMedium())
                        .foregroundColor(Color.accentPrimary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.textTertiary)
            }
            .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .padding(.horizontal, DS.Spacing.screenH)
        .accessibilityLabel("This week events, \(events.count) items")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var eventContent: some View {
        if events.isEmpty {
            // Empty state
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.08))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "leaf")
                        .font(.system(size: 16))
                        .foregroundColor(Color.accentPrimary.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.noEvents)
                        .font(DS.Typography.body())
                        .foregroundColor(Color.textSecondary)
                    
                    Text("Enjoy a peaceful week")
                        .font(DS.Typography.caption())
                        .foregroundColor(Color.textTertiary)
                }
                
                Spacer()
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.screenH)
        } else {
            VStack(spacing: DS.Spacing.xs) {
                ForEach(events) { event in
                    if event.canDelete {
                        CompactEventRow(event: event)
                            .swipeToDelete {
                                onDeleteEvent(event)
                            }
                    } else {
                        CompactEventRow(event: event)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
        }
    }
}

// MARK: - Compact Event Row

struct CompactEventRow: View {
    let event: UpcomingEvent
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Color indicator
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)
            
            // Icon
            Image(systemName: event.icon)
                .font(.system(size: 14))
                .foregroundColor(event.color)
                .frame(width: 20)
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(DS.Typography.label())
                    .foregroundColor(Color.textPrimary)
                    .lineLimit(1)
                
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(DS.Typography.micro())
                        .foregroundColor(Color.textTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Countdown badge
            Text(event.countdownText)
                .font(DS.Typography.captionMedium())
                .foregroundColor(event.daysUntil <= 1 ? .white : Color.accentPrimary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(event.daysUntil <= 1 ? event.color : Color.accentPrimary.opacity(0.1))
                )
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(Color.themeCardBackground)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}
