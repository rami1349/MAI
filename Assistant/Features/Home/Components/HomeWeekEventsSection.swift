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
        VStack(alignment: .leading, spacing: Luxury.Spacing.sm) {
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
            HStack(spacing: Luxury.Spacing.sm) {
                // Icon badge
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text(L10n.thisWeek)
                    .font(Luxury.Typography.subheading())
                    .foregroundColor(.textPrimary)
                
                // Count badge
                if !events.isEmpty {
                    Text("\(events.count)")
                        .font(Luxury.Typography.captionMedium())
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, Luxury.Spacing.sm)
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
                    .foregroundColor(.textTertiary)
            }
            .padding(.vertical, Luxury.Spacing.xs)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .padding(.horizontal, Luxury.Spacing.screenH)
        .accessibilityLabel("This week events, \(events.count) items")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var eventContent: some View {
        if events.isEmpty {
            // Empty state
            HStack(spacing: Luxury.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.08))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "leaf")
                        .font(.system(size: 16))
                        .foregroundColor(.accentPrimary.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: Luxury.Spacing.xxs) {
                    Text(L10n.noEvents)
                        .font(Luxury.Typography.body())
                        .foregroundColor(.textSecondary)
                    
                    Text("Enjoy a peaceful week")
                        .font(Luxury.Typography.caption())
                        .foregroundColor(.textTertiary)
                }
                
                Spacer()
            }
            .padding(.vertical, Luxury.Spacing.sm)
            .padding(.horizontal, Luxury.Spacing.screenH)
        } else {
            VStack(spacing: Luxury.Spacing.xs) {
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
            .padding(.horizontal, Luxury.Spacing.screenH)
        }
    }
}

// MARK: - Compact Event Row

struct CompactEventRow: View {
    let event: UpcomingEvent
    
    var body: some View {
        HStack(spacing: Luxury.Spacing.md) {
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
                    .font(Luxury.Typography.label())
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(Luxury.Typography.micro())
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Countdown badge
            Text(event.countdownText)
                .font(Luxury.Typography.captionMedium())
                .foregroundColor(event.daysUntil <= 1 ? .white : .accentPrimary)
                .padding(.horizontal, Luxury.Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(event.daysUntil <= 1 ? event.color : Color.accentPrimary.opacity(0.1))
                )
        }
        .padding(.vertical, Luxury.Spacing.sm)
        .padding(.horizontal, Luxury.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Luxury.Radius.md)
                .fill(Color.themeCardBackground)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}