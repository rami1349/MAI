//  UpcomingEvent.swift
//
//
//  Upcoming event model used by HomeView, week events, and countdown cards.
//  Standalone file so every view can reference it without cross-dependencies.
//

import SwiftUI

struct UpcomingEvent: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let date: Date
    let daysUntil: Int
    let icon: String
    let color: Color
    let type: EventType
    let source: Source
    
    enum EventType {
        case birthday
        case holiday
        case event
    }
    
    enum Source {
        case birthday(memberId: String)
        case eventKit(eventId: String)
        case firestore(eventId: String)
        case holiday
    }
    
    var canDelete: Bool {
        switch source {
        case .firestore: return true
        case .birthday, .eventKit, .holiday: return false
        }
    }
    
    var countdownText: String {
        if daysUntil == 0 {
            return "today_exclamation"
        } else if daysUntil == 1 {
            return "tomorrow"
        } else {
            return AppStrings.xDays(daysUntil)
        }
    }
}

// MARK: - Countdown Card

/// Full-size countdown card (used outside HomeView, e.g. calendar).
struct CountdownCard: View {
    let event: UpcomingEvent
    
    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.themeHighlight)
                    .overlay(Circle().fill(event.color.opacity(0.12)))
                    .frame(width: DS.IconContainer.lg, height: DS.IconContainer.lg)
                
                Image(systemName: event.icon)
                    .font(.title3)
                    .foregroundStyle(event.color)
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(event.title)
                    .font(DS.Typography.label())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(DS.Typography.micro())
                        .foregroundStyle(.textSecondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(event.countdownText)
                    .font(DS.Typography.badge())
                    .fontWeight(.bold)
                    .foregroundStyle(event.daysUntil <= 3 ? event.color : .accentPrimary)
                
                Text(event.date.formattedShortDate)
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
        )
    }
}
