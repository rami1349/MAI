
//  CalendarCards.swift
//  
//
//  Card components for displaying events and tasks in calendar views
//

import SwiftUI

// MARK: - Multi-Day Event Bar (iOS Calendar style)

struct MultiDayEventBar: View {
    let event: CalendarEvent
    let startColumn: Int
    let endColumn: Int
    let isStart: Bool
    let isEnd: Bool
    
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let columnWidth = availableWidth / 7
            let startX = CGFloat(startColumn) * columnWidth
            let barWidth = CGFloat(endColumn - startColumn + 1) * columnWidth - 4
            
            HStack(spacing: 0) {
                Text(event.title)
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textOnAccent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: barWidth, height: 16)
            .background(
                RoundedRectangle(cornerRadius: isStart && isEnd ? 4 : (isStart ? 4 : (isEnd ? 4 : 0)))
                    .fill(Color(hex: event.color))
            )
            .clipShape(
                EventBarShape(isStart: isStart, isEnd: isEnd)
            )
            .offset(x: startX + 2)
        }
        .frame(height: 18)
    }
}

// MARK: - Event Bar Shape for rounded corners

struct EventBarShape: Shape {
    let isStart: Bool
    let isEnd: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 4
        var path = Path()
        
        let topLeft = isStart ? radius : 0
        let bottomLeft = isStart ? radius : 0
        let topRight = isEnd ? radius : 0
        let bottomRight = isEnd ? radius : 0
        
        path.move(to: CGPoint(x: topLeft, y: 0))
        path.addLine(to: CGPoint(x: rect.width - topRight, y: 0))
        
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.width - topRight, y: topRight),
                        radius: topRight,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(0),
                        clockwise: false)
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - bottomRight))
        
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.width - bottomRight, y: rect.height - bottomRight),
                        radius: bottomRight,
                        startAngle: .degrees(0),
                        endAngle: .degrees(90),
                        clockwise: false)
        }
        
        path.addLine(to: CGPoint(x: bottomLeft, y: rect.height))
        
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: bottomLeft, y: rect.height - bottomLeft),
                        radius: bottomLeft,
                        startAngle: .degrees(90),
                        endAngle: .degrees(180),
                        clockwise: false)
        }
        
        path.addLine(to: CGPoint(x: 0, y: topLeft))
        
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: topLeft, y: topLeft),
                        radius: topLeft,
                        startAngle: .degrees(180),
                        endAngle: .degrees(270),
                        clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: CalendarEvent
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil
    
    private let calendar = Calendar.current
    
    private var isMultiDay: Bool {
        !calendar.isDate(event.startDate, inSameDayAs: event.endDate)
    }
    
    private var dateRangeText: String {
        if isMultiDay {
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d"
            return "\(startFormatter.string(from: event.startDate)) - \(endFormatter.string(from: event.endDate))"
        } else if event.isAllDay {
            return "allDay"
        } else {
            return "\(event.startDate.formattedTime) - \(event.endDate.formattedTime)"
        }
    }
    
    var body: some View {
        eventContent
            .swipeToDelete {
                onDelete?()
            }
    }
    
    private var eventContent: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: event.color))
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: isMultiDay ? "calendar" : "clock")
                            .font(.caption2)
                        Text(dateRangeText)
                            .font(.caption)
                    }
                    .foregroundStyle(.textSecondary)
                    
                    if let description = event.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isMultiDay {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.backgroundCard))
            .elevation1()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Calendar Task Card

struct CalendarTaskCard: View {
    let task: FamilyTask
    
    var statusColor: Color {
        switch task.status {
        case .todo: return Color.statusTodo
        case .inProgress: return Color.statusInProgress
        case .pendingVerification: return Color.statusPending
        case .completed: return Color.statusCompleted
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 4)
            
            Image(systemName: "checkmark.circle")
                .foregroundStyle(statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.textPrimary)
                
                if let time = task.scheduledTime {
                    Text(time.formattedTime)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
            }
            
            Spacer()
            
            if task.hasReward, let amount = task.rewardAmount {
                Text(amount.currencyString)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.accentGreen)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(statusColor.opacity(0.1))
                )
        )
    }
}

// MARK: - Special Event Model (Birthdays & Holidays)

struct SpecialEvent: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let type: EventType
    var date: Date? = nil
    
    enum EventType {
        case birthday
        case holiday
    }
}

// MARK: - Special Event Card

struct SpecialEventCard: View {
    let event: SpecialEvent
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(event.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: event.icon)
                    .font(.title3)
                    .foregroundStyle(event.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: event.type == .birthday ? "birthday.cake.fill" : "gift.fill")
                .font(.title2)
                .foregroundStyle(.pink)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(event.color.opacity(0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(event.color.opacity(0.3), lineWidth: 1)
        )
    }
}
