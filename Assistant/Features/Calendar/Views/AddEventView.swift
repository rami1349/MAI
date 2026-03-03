//
//  AddEventView.swift
//  FamilyHub
//
//  UNICORN REDESIGN - Progressive Disclosure Pattern
//  - Hero title input with large font
//  - Smart time selection with quick chips
//  - Collapsible optional fields
//  - Natural language parsing
//  - Minimal cognitive load
//

import SwiftUI
import UIKit

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    
    // MARK: - Form State
    @State private var title = ""
    @State private var notes = ""
    @State private var startDate = Self.smartDefaultStartDate()
    @State private var endDate = Self.smartDefaultEndDate()
    @State private var isAllDay = false
    @State private var selectedColor = "7C3AED"
    @State private var selectedParticipants: Set<String> = []
    
    // MARK: - UI State (Progressive Disclosure)
    @State private var showDatePicker = false
    @State private var showParticipants = false
    @State private var showMoreOptions = false
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var createError: String? = nil
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    
    // MARK: - Constants
    private let primaryColors = ["7C3AED", "3B82F6", "10B981", "F59E0B"]
    private let calendar = Calendar.current
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeSurfacePrimary
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.xl) {
                        // Primary: Event title (Hero input)
                        heroTitleSection
                        
                        // Primary: Smart time selection
                        smartTimeSection
                        
                        // Secondary: Optional fields (collapsed by default)
                        optionalFieldsSection
                        
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, DS.Spacing.screenH)
                    .padding(.top, DS.Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text(L10n.addEvent)
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: createEvent) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(L10n.add)
                                .font(DS.Typography.label())
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(title.isEmpty ? .textTertiary : .accentPrimary)
                    .disabled(title.isEmpty || isLoading)
                }
            }
            .overlay {
                if showSuccess {
                    SuccessDismissOverlay(message: L10n.eventCreated) {
                        dismiss()
                    }
                }
            }
            .globalErrorBanner(errorMessage: $createError)
        }
    }
    
    // MARK: - Hero Title Section
    private var heroTitleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.eventWhatHappening)
                .font(DS.Typography.caption())
                .foregroundStyle(.textTertiary)
            
            TextField(L10n.eventTitlePlaceholder, text: $title)
                .font(DS.Typography.displayMedium())
                .foregroundStyle(.textPrimary)
                .focused($isTitleFocused)
                .padding(.vertical, DS.Spacing.sm)
                .onChange(of: title) { _, newValue in
                    parseNaturalLanguage(newValue)
                }
            
            Rectangle()
                .fill(isTitleFocused ? Color.accentPrimary : Color.textTertiary.opacity(0.3))
                .frame(height: isTitleFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.2), value: isTitleFocused)
        }
    }
    
    // MARK: - Smart Time Section
    private var smartTimeSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Current selection summary (tappable to expand)
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showDatePicker.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(.accentPrimary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedDateRange)
                            .font(DS.Typography.body())
                            .foregroundStyle(.textPrimary)
                        
                        if isAllDay {
                            Text(L10n.allDay)
                                .font(DS.Typography.caption())
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.change)
                            .font(DS.Typography.caption())
                            .foregroundStyle(.accentPrimary)
                        
                        Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                            .font(DS.Typography.bodySmall())
                            .foregroundStyle(.accentPrimary)
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
            .buttonStyle(.plain)
            
            // Quick time chips (visible when date picker is collapsed)
            if !showDatePicker {
                quickTimeChips
            }
            
            // Expanded date picker
            if showDatePicker {
                expandedDatePicker
            }
        }
    }
    
    // MARK: - Quick Time Chips
    private var quickTimeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                QuickTimeChip(
                    label: L10n.tonight,
                    sublabel: "6:00 PM",
                    isSelected: isTonight
                ) {
                    setTime(hour: 18, today: true)
                }
                
                QuickTimeChip(
                    label: L10n.tomorrow,
                    sublabel: "9:00 AM",
                    isSelected: isTomorrowMorning
                ) {
                    setTime(hour: 9, today: false)
                }
                
                QuickTimeChip(
                    label: L10n.thisWeekend,
                    sublabel: saturdayLabel,
                    isSelected: isThisWeekend
                ) {
                    setWeekend()
                }
                
                QuickTimeChip(
                    label: L10n.allDay,
                    sublabel: L10n.tomorrow,
                    isSelected: isAllDay && isTomorrowAllDay
                ) {
                    setAllDayTomorrow()
                }
            }
        }
    }
    
    // MARK: - Expanded Date Picker
    private var expandedDatePicker: some View {
        VStack(spacing: 0) {
            // All Day Toggle
            Toggle(isOn: $isAllDay) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "sun.max.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(.accentPrimary)
                        .frame(width: 24)
                    
                    Text(L10n.allDay)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                }
            }
            .tint(.accentPrimary)
            .padding(DS.Spacing.md)
            .onChange(of: isAllDay) { _, allDay in
                if allDay {
                    startDate = calendar.startOfDay(for: startDate)
                    endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                } else {
                    let hour = calendar.component(.hour, from: Date())
                    startDate = calendar.date(bySettingHour: max(hour + 1, 9), minute: 0, second: 0, of: startDate) ?? startDate
                    endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
                }
            }
            
            Divider().padding(.leading, 48)
            
            // Start Date
            HStack {
                Image(systemName: "calendar")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 24)
                
                Text(L10n.starts)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: $startDate,
                    displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                )
                .labelsHidden()
                .onChange(of: startDate) { _, newStart in
                    if endDate <= newStart {
                        endDate = calendar.date(byAdding: .hour, value: 1, to: newStart)!
                    }
                }
            }
            .padding(DS.Spacing.md)
            
            Divider().padding(.leading, 48)
            
            // End Date
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textTertiary)
                    .frame(width: 24)
                
                Text(L10n.ends)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                )
                .labelsHidden()
            }
            .padding(DS.Spacing.md)
            
            // Duration display
            if !isAllDay || !calendar.isDate(startDate, inSameDayAs: endDate) {
                Divider().padding(.leading, 48)
                
                HStack {
                    Image(systemName: "hourglass")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textTertiary)
                        .frame(width: 24)
                    
                    Text(L10n.duration)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                    
                    Spacer()
                    
                    Text(durationText)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
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
    
    // MARK: - Optional Fields Section (Progressive Disclosure)
    private var optionalFieldsSection: some View {
        VStack(spacing: 0) {
            // Participants (collapsed by default)
            CollapsibleParticipantsRow(
                selectedIds: $selectedParticipants,
                members: familyMemberVM.familyMembers,
                isExpanded: $showParticipants
            )
            
            Divider().padding(.leading, 48)
            
            // More options (notes, color)
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showMoreOptions.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(showMoreOptions ? .accentPrimary : .textTertiary)
                        .frame(width: 24)
                    
                    Text(L10n.moreOptions)
                        .font(DS.Typography.body())
                        .foregroundStyle(showMoreOptions ? .textPrimary : .textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: showMoreOptions ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textTertiary)
                }
                .padding(DS.Spacing.md)
            }
            .buttonStyle(.plain)
            
            if showMoreOptions {
                moreOptionsContent
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
    
    // MARK: - More Options Content
    private var moreOptionsContent: some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, 48)
            
            // Notes
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: "note.text")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textTertiary)
                        .frame(width: 24)
                    
                    Text(L10n.notes)
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                }
                
                TextField(L10n.addNotes, text: $notes, axis: .vertical)
                    .font(DS.Typography.body())
                    .lineLimit(2...4)
                    .focused($isNotesFocused)
                    .padding(.leading, 36)
            }
            .padding(DS.Spacing.md)
            
            Divider().padding(.leading, 48)
            
            // Color picker
            HStack {
                Image(systemName: "paintpalette.fill")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textTertiary)
                    .frame(width: 24)
                
                Text(L10n.color)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textSecondary)
                
                Spacer()
                
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(primaryColors, id: \.self) { color in
                        Button(action: { selectedColor = color }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 28, height: 28)
                                
                                if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .font(DS.Typography.captionMedium())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDateRange: String {
        let dateFormatter = DateFormatter()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        if calendar.isDateInToday(startDate) {
            dateFormatter.dateFormat = "'\(L10n.today)'"
        } else if calendar.isDateInTomorrow(startDate) {
            dateFormatter.dateFormat = "'\(L10n.tomorrow)'"
        } else {
            dateFormatter.dateFormat = "EEE, MMM d"
        }
        
        if isAllDay {
            if calendar.isDate(startDate, inSameDayAs: endDate) ||
                calendar.isDate(startDate, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: endDate)!) {
                return dateFormatter.string(from: startDate)
            } else {
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = "MMM d"
                return "\(dateFormatter.string(from: startDate)) - \(endFormatter.string(from: endDate))"
            }
        } else {
            let dateStr = dateFormatter.string(from: startDate)
            let startTime = timeFormatter.string(from: startDate)
            let endTime = timeFormatter.string(from: endDate)
            return "\(dateStr), \(startTime) - \(endTime)"
        }
    }
    
    private var durationText: String {
        let components = calendar.dateComponents([.day, .hour, .minute], from: startDate, to: endDate)
        
        if let days = components.day, days > 0 {
            if let hours = components.hour, hours > 0 {
                return "\(days) \(days == 1 ? L10n.day : L10n.days), \(hours) \(L10n.hr)"
            }
            return "\(days) \(days == 1 ? L10n.day : L10n.days)"
        } else if let hours = components.hour, hours > 0 {
            if let minutes = components.minute, minutes > 0 {
                return "\(hours) \(L10n.hr) \(minutes) \(L10n.min)"
            }
            return "\(hours) \(hours == 1 ? L10n.hour : L10n.hours)"
        } else if let minutes = components.minute {
            return "\(minutes) \(L10n.min)"
        }
        return ""
    }
    
    private var saturdayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: nextSaturday)
    }
    
    private var nextSaturday: Date {
        let weekday = calendar.component(.weekday, from: Date())
        let daysUntilSaturday = (7 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: Date())!
    }
    
    // Quick chip selection states
    private var isTonight: Bool {
        calendar.isDateInToday(startDate) && calendar.component(.hour, from: startDate) >= 17
    }
    
    private var isTomorrowMorning: Bool {
        calendar.isDateInTomorrow(startDate) && calendar.component(.hour, from: startDate) < 12
    }
    
    private var isThisWeekend: Bool {
        let weekday = calendar.component(.weekday, from: startDate)
        return weekday == 7 || weekday == 1 // Saturday or Sunday
    }
    
    private var isTomorrowAllDay: Bool {
        calendar.isDateInTomorrow(startDate)
    }
    
    // MARK: - Time Setting Methods
    
    private func setTime(hour: Int, today: Bool) {
        var targetDate = today ? Date() : calendar.date(byAdding: .day, value: 1, to: Date())!
        targetDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: targetDate)!
        
        startDate = targetDate
        endDate = calendar.date(byAdding: .hour, value: 1, to: targetDate)!
        isAllDay = false
        
        DS.Haptics.light()
    }
    
    private func setWeekend() {
        var saturday = nextSaturday
        saturday = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: saturday)!
        
        startDate = saturday
        endDate = calendar.date(byAdding: .hour, value: 2, to: saturday)!
        isAllDay = false
        
        DS.Haptics.light()
    }
    
    private func setAllDayTomorrow() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        startDate = calendar.startOfDay(for: tomorrow)
        endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        isAllDay = true
        
        DS.Haptics.light()
    }
    
    // MARK: - Natural Language Parsing
    
    private func parseNaturalLanguage(_ input: String) {
        let lowercased = input.lowercased()
        
        // Only parse if we detect time-related keywords
        guard lowercased.contains("tomorrow") ||
                lowercased.contains("tonight") ||
                lowercased.contains("weekend") ||
                lowercased.contains("next week") ||
                lowercased.range(of: #"at \d"#, options: .regularExpression) != nil else {
            return
        }
        
        // Date parsing
        if lowercased.contains("tomorrow") {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
            if !isAllDay {
                startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
                endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
            } else {
                startDate = calendar.startOfDay(for: tomorrow)
            }
        } else if lowercased.contains("tonight") {
            startDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
            endDate = calendar.date(byAdding: .hour, value: 2, to: startDate)!
            isAllDay = false
        } else if lowercased.contains("weekend") || lowercased.contains("saturday") {
            setWeekend()
        }
        
        // Time parsing (e.g., "at 7pm", "at 3:30")
        if let match = input.range(of: #"at (\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#, options: .regularExpression, range: nil, locale: nil) {
            let timeStr = String(input[match]).lowercased()
            
            // Extract hour
            if let hourMatch = timeStr.range(of: #"\d{1,2}"#, options: .regularExpression) {
                var hour = Int(timeStr[hourMatch]) ?? 9
                
                // Handle PM
                if timeStr.contains("pm") && hour < 12 {
                    hour += 12
                } else if timeStr.contains("am") && hour == 12 {
                    hour = 0
                } else if !timeStr.contains("am") && !timeStr.contains("pm") && hour < 7 {
                    // Assume PM for small hours without am/pm
                    hour += 12
                }
                
                startDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startDate)!
                endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
                isAllDay = false
            }
        }
    }
    
    // MARK: - Smart Defaults
    
    private static func smartDefaultStartDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        // Round up to next hour, minimum 9 AM
        let nextHour = max(hour + 1, 9)
        
        if nextHour >= 21 {
            // If it's late, default to tomorrow morning
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
        }
        
        return calendar.date(bySettingHour: nextHour, minute: 0, second: 0, of: now)!
    }
    
    private static func smartDefaultEndDate() -> Date {
        return Calendar.current.date(byAdding: .hour, value: 1, to: smartDefaultStartDate())!
    }
    
    // MARK: - Create Event
    
    private func createEvent() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isTitleFocused = false
        isNotesFocused = false
        isLoading = true
        createError = nil
        
        Task {
            await familyViewModel.createEvent(
                title: title.trimmingCharacters(in: .whitespaces),
                description: notes.isEmpty ? nil : notes,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                color: selectedColor,
                createdBy: userId,
                participants: Array(selectedParticipants)
            )
            
            isLoading = false
            
            if let error = familyViewModel.errorMessage {
                createError = error
                familyViewModel.errorMessage = nil
                DS.Haptics.error()
            } else {
                DS.Haptics.success()
                withAnimation {
                    showSuccess = true
                }
            }
        }
    }
}

// MARK: - Quick Time Chip Component

private struct QuickTimeChip: View {
    let label: String
    let sublabel: String
    var isSelected: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(DS.Typography.labelSmall())
                    .foregroundStyle(isSelected ? .white : .textPrimary)
                
                Text(sublabel)
                    .font(DS.Typography.micro())
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .textTertiary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color.accentPrimary : Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? Color.clear : Color.themeCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsible Participants Row

private struct CollapsibleParticipantsRow: View {
    @Binding var selectedIds: Set<String>
    let members: [FamilyUser]
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: selectedIds.isEmpty ? "person.2" : "person.2.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(selectedIds.isEmpty ? .textTertiary : .accentPrimary)
                        .frame(width: 24)
                    
                    if selectedIds.isEmpty {
                        Text(L10n.addParticipants)
                            .font(DS.Typography.body())
                            .foregroundStyle(.textTertiary)
                    } else {
                        Text(participantsSummary)
                            .font(DS.Typography.body())
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if !selectedIds.isEmpty {
                        Text("\(selectedIds.count)")
                            .font(DS.Typography.badge())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentPrimary))
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textTertiary)
                }
                .padding(DS.Spacing.md)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(members) { member in
                        Button(action: {
                            if let id = member.id {
                                if selectedIds.contains(id) {
                                    selectedIds.remove(id)
                                } else {
                                    selectedIds.insert(id)
                                }
                                DS.Haptics.light()
                            }
                        }) {
                            HStack(spacing: DS.Spacing.md) {
                                AvatarView(user: member, size: 32)
                                
                                Text(member.displayName)
                                    .font(DS.Typography.body())
                                    .foregroundStyle(.textPrimary)
                                
                                Spacer()
                                
                                if let id = member.id, selectedIds.contains(id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(DS.Typography.heading())
                                        .foregroundStyle(.accentPrimary)
                                } else {
                                    Circle()
                                        .stroke(Color.textTertiary.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .padding(.leading, 36)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, DS.Spacing.sm)
            }
        }
    }
    
    private var participantsSummary: String {
        let selected = members.filter { selectedIds.contains($0.id ?? "") }
        if selected.count == 1 {
            return selected.first?.displayName ?? ""
        } else if selected.count == 2 {
            return selected.map { $0.displayName.components(separatedBy: " ").first ?? $0.displayName }.joined(separator: " & ")
        } else {
            let firstName = selected.first?.displayName.components(separatedBy: " ").first ?? ""
            return "\(firstName) +\(selected.count - 1)"
        }
    }
}

// MARK: - Preview

#Preview {
    AddEventView()
        .environment(AuthViewModel())
        .environment({ let vm = FamilyViewModel(); return vm }())
        .environment({ let vm = FamilyViewModel(); return vm.familyMemberVM }())
}
