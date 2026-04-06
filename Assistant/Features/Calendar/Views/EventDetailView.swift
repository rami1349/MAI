//
//  EventDetailView.swift
//
//  PURPOSE:
//    Full detail screen for a calendar event. Shows time, duration,
//    participants, notes, and edit/delete actions.
//
//  ARCHITECTURE ROLE:
//    Detail view — reached from calendar agenda tap.
//    Presents EditEventView and confirms deletion.
//
//  DATA FLOW:
//    CalendarEvent (input) → display
//    FamilyViewModel → deleteEvent()
//

import SwiftUI

struct EventDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(CalendarViewModel.self) var calendarVM
    
    let event: CalendarEvent
    
    @State private var showDeleteConfirmation = false
    @State private var showEditEvent = false
    @State private var isDeleting = false
    
    private let calendar = Calendar.current
    
    /// Live event from the Firestore listener — reflects edits immediately.
    /// Falls back to the original `event` if it's been deleted.
    private var liveEvent: CalendarEvent {
        calendarVM.events.first(where: { $0.id == event.id }) ?? event
    }
    
    // MARK: - Computed Properties
    
    private var isMultiDayEvent: Bool {
        !calendar.isDate(liveEvent.startDate, inSameDayAs: liveEvent.endDate)
    }
    
    private var numberOfDays: Int {
        let days = calendar.dateComponents([.day], from: liveEvent.startDate, to: liveEvent.endDate).day ?? 0
        return max(days, 1)
    }
    
    private var durationText: String {
        let components = calendar.dateComponents([.day, .hour, .minute], from: liveEvent.startDate, to: liveEvent.endDate)
        
        if let days = components.day, days > 0 {
            if let hours = components.hour, hours > 0 {
                return "\(days) \(days == 1 ? AppStrings.localized("day") : AppStrings.localized("days")), \(hours) \(hours == 1 ? AppStrings.localized("hour") : AppStrings.localized("hours"))"
            }
            return "\(days) \(days == 1 ? AppStrings.localized("day") : AppStrings.localized("days"))"
        } else if let hours = components.hour, hours > 0 {
            if let minutes = components.minute, minutes > 0 {
                return "\(hours) \(AppStrings.localized("hr")) \(minutes) \(AppStrings.localized("min"))"
            }
            return "\(hours) \(hours == 1 ? AppStrings.localized("hour") : AppStrings.localized("hours"))"
        } else if let minutes = components.minute {
            return "\(minutes) \(AppStrings.localized("minutes"))"
        }
        return ""
    }
    
    private var eventColor: Color {
        Color(hex: liveEvent.color.replacingOccurrences(of: "#", with: ""))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero header with color
                    heroHeader
                    
                    // Content
                    VStack(spacing: DS.Spacing.lg) {
                        // Date & Time
                        dateTimeCard
                        
                        // Description (if exists)
                        if let description = liveEvent.description, !description.isEmpty {
                            notesCard(description)
                        }
                        
                        // Participants
                        if !liveEvent.participants.isEmpty {
                            participantsCard
                        }
                        
                        // Actions
                        actionsCard
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, DS.Spacing.screenH)
                    .padding(.top, DS.Spacing.lg)
                }
            }
            .background(Color.themeSurfacePrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text("event_details")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                }
            }
            .alert("delete_event_confirm", isPresented: $showDeleteConfirmation) {
                Button("cancel", role: .cancel) { }
                Button("delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("action_cannot_be_undone")
            }
            .sheet(isPresented: $showEditEvent) {
                EditEventView(event: liveEvent)
                    .presentationBackground(Color.themeSurfacePrimary)
            }
        }
    }
    
    // MARK: - Hero Header
    
    private var heroHeader: some View {
        VStack(spacing: DS.Spacing.md) {
            // Color indicator bar
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor)
                .frame(height: 6)
                .frame(maxWidth: 60)
            
            // Event title
            Text(liveEvent.title)
                .font(DS.Typography.displayMedium())
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            
            // Quick time summary
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: liveEvent.isAllDay ? "sun.max.fill" : "clock.fill")
                    .font(DS.Typography.body())
                    .foregroundStyle(eventColor)
                
                Text(quickTimeSummary)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .background(
            LinearGradient(
                colors: [eventColor.opacity(0.08), Color.themeSurfacePrimary],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var quickTimeSummary: String {
        if calendar.isDateInToday(liveEvent.startDate) {
            if liveEvent.isAllDay {
                return AppStrings.localized("today_all_day")
            }
            let time = liveEvent.startDate.formatted(date: .omitted, time: .shortened)
            return "\(AppStrings.localized("today")), \(time)"
        } else if calendar.isDateInTomorrow(liveEvent.startDate) {
            if liveEvent.isAllDay {
                return AppStrings.localized("tomorrow_all_day")
            }
            let time = liveEvent.startDate.formatted(date: .omitted, time: .shortened)
            return "\(AppStrings.localized("tomorrow")), \(time)"
        } else {
            if liveEvent.isAllDay {
                return liveEvent.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            }
            let date = liveEvent.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            let time = liveEvent.startDate.formatted(date: .omitted, time: .shortened)
            return "\(date), \(time)"
        }
    }
    
    // MARK: - Date Time Card
    
    private var dateTimeCard: some View {
        VStack(spacing: 0) {
            if isMultiDayEvent {
                // Multi-day layout
                multiDayTimeContent
            } else {
                // Single day layout
                singleDayTimeContent
            }
            
            // Duration (if not all-day single day)
            if !liveEvent.isAllDay || isMultiDayEvent {
                Divider().padding(.leading, 48)
                
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "hourglass")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textTertiary)
                        .frame(width: 24)
                    
                    Text("duration")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                    
                    Spacer()
                    
                    Text(durationText)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                }
                .padding(DS.Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color.themeCardBorder, lineWidth: 0.5)
        )
    }
    
    private var singleDayTimeContent: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar")
                .font(DS.Typography.body())
                .foregroundStyle(.accentPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(formatDate(liveEvent.startDate))
                    .font(DS.Typography.body())
                    .fontWeight(.medium)
                    .foregroundStyle(.textPrimary)
                
                if liveEvent.isAllDay {
                    Text("all_day")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textSecondary)
                } else {
                    Text("\(liveEvent.startDate.formattedTime) – \(liveEvent.endDate.formattedTime)")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(DS.Spacing.md)
    }
    
    private var multiDayTimeContent: some View {
        VStack(spacing: 0) {
            // Start
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("starts")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                    
                    Text(formatDate(liveEvent.startDate))
                        .font(DS.Typography.body())
                        .fontWeight(.medium)
                        .foregroundStyle(.textPrimary)
                    
                    if !liveEvent.isAllDay {
                        Text(liveEvent.startDate.formattedTime)
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(DS.Spacing.md)
            
            // Visual connector
            HStack {
                Rectangle()
                    .fill(eventColor.opacity(0.3))
                    .frame(width: 2)
                    .frame(height: 24)
                    .padding(.leading, 23)
                
                Spacer()
            }
            
            // End
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textTertiary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("ends")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                    
                    Text(formatDate(liveEvent.endDate))
                        .font(DS.Typography.body())
                        .fontWeight(.medium)
                        .foregroundStyle(.textPrimary)
                    
                    if !liveEvent.isAllDay {
                        Text(liveEvent.endDate.formattedTime)
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(DS.Spacing.md)
        }
    }
    
    // MARK: - Notes Card
    
    private func notesCard(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .font(DS.Typography.body())
                .foregroundStyle(.textTertiary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("notes")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
                
                Text(notes)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
            }
            
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color.themeCardBorder, lineWidth: 0.5)
        )
    }
    
    // MARK: - Participants Card
    
    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "person.2.fill")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 24)
                
                Text("participants")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
                
                Spacer()
                
                Text("\(liveEvent.participants.count)")
                    .font(DS.Typography.badge())
                    .foregroundStyle(.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.accentPrimary.opacity(0.1))
                    )
            }
            
            // Participant avatars
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(liveEvent.participants, id: \.self) { participantId in
                        if let member = familyMemberVM.familyMembers.first(where: { $0.id == participantId }) {
                            VStack(spacing: DS.Spacing.xs) {
                                AvatarView(user: member, size: DS.Avatar.md)
                                
                                Text(member.displayName.components(separatedBy: " ").first ?? member.displayName)
                                    .font(DS.Typography.micro())
                                    .foregroundStyle(.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 56)
                        }
                    }
                }
                .padding(.leading, 36)
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color.themeCardBorder, lineWidth: 0.5)
        )
    }
    
    // MARK: - Actions Card
    
    private var actionsCard: some View {
        HStack(spacing: DS.Spacing.md) {
            // Edit button
            Button(action: { showEditEvent = true }) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(DS.Typography.body())
                    Text("edit")
                        .font(DS.Typography.label())
                }
                .foregroundStyle(.accentPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(Color.accentPrimary.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            
            // Delete button
            Button(action: { showDeleteConfirmation = true }) {
                HStack(spacing: DS.Spacing.sm) {
                    if isDeleting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.red)
                    } else {
                        Image(systemName: "trash")
                            .font(DS.Typography.body())
                    }
                    Text("delete")
                        .font(DS.Typography.label())
                }
                .foregroundStyle(.statusError)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "today")
        } else if calendar.isDateInTomorrow(date) {
            return String(localized: "tomorrow")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "yesterday")
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        }
    }
    
    private func deleteEvent() {
        guard !isDeleting else { return }
        isDeleting = true
        
        Task {
            await familyViewModel.deleteEvent(liveEvent)
            isDeleting = false
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    let familyVM = FamilyViewModel()
    EventDetailView(event: CalendarEvent(
        familyId: "test",
        title: "Family Dinner",
        description: "Weekly family dinner at grandma's house. Don't forget to bring the dessert!",
        startDate: Date.now,
        endDate: Date.now.addingTimeInterval(7200),
        isAllDay: false,
        color: "7C3AED",
        createdBy: "user1",
        participants: ["user1", "user2"],
        linkedTaskId: nil,
        eventType: nil,
        createdAt: Date.now
    ))
    .environment(familyVM)
    .environment(familyVM.familyMemberVM)
}
