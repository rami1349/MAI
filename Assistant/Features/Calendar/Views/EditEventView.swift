//
//  EditEventView.swift
//
//
//  UNICORN REDESIGN - Matches AddEventView progressive disclosure pattern
//  - Pre-filled with existing event data
//  - Same streamlined UI as AddEventView
//  - Consistent experience across create/edit
//

import SwiftUI

struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    
    let event: CalendarEvent
    
    // MARK: - Form State (seeded from event)
    @State private var title: String
    @State private var notes: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var selectedColor: String
    @State private var selectedParticipants: Set<String>
    
    // MARK: - UI State
    @State private var showDatePicker = false
    @State private var showParticipants: Bool
    @State private var showMoreOptions: Bool
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var saveError: String? = nil
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    
    // MARK: - Constants
    private let primaryColors = ["7C3AED", "3B82F6", "10B981", "F59E0B"]
    private let calendar = Calendar.current
    
    // MARK: - Init
    
    init(event: CalendarEvent) {
        self.event = event
        _title = State(initialValue: event.title)
        _notes = State(initialValue: event.description ?? "")
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: event.endDate)
        _isAllDay = State(initialValue: event.isAllDay)
        
        let rawColor = event.color.replacingOccurrences(of: "#", with: "")
        _selectedColor = State(initialValue: rawColor)
        _selectedParticipants = State(initialValue: Set(event.participants))
        
        // Show sections if they have content
        _showParticipants = State(initialValue: !event.participants.isEmpty)
        _showMoreOptions = State(initialValue: !(event.description ?? "").isEmpty)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeSurfacePrimary
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.xl) {
                        // Primary: Event title
                        heroTitleSection
                        
                        // Primary: Smart time selection
                        smartTimeSection
                        
                        // Secondary: Optional fields
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
                    Button("cancel") { dismiss() }
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text("editEvent")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveEvent) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("save")
                                .font(DS.Typography.label())
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(title.isEmpty ? .textTertiary : .accentPrimary)
                    .disabled(title.isEmpty || isLoading)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("done") {
                            isTitleFocused = false
                            isNotesFocused = false
                        }
                        .font(DS.Typography.label())
                    }
                }
            }
            .overlay {
                if showSuccess {
                    SuccessDismissOverlay(message: "event_updated") {
                        dismiss()
                    }
                }
            }
            .globalErrorBanner(errorMessage: $saveError)
        }
    }
    
    // MARK: - Hero Title Section
    
    private var heroTitleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("what_happening")
                .font(DS.Typography.caption())
                .foregroundStyle(.textTertiary)
            
            TextField("event_title_placeholder", text: $title)
                .font(DS.Typography.displayMedium())
                .foregroundStyle(.textPrimary)
                .focused($isTitleFocused)
                .padding(.vertical, DS.Spacing.sm)
            
            Rectangle()
                .fill(isTitleFocused ? Color.accentPrimary : Color.textTertiary.opacity(0.3))
                .frame(height: isTitleFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.2), value: isTitleFocused)
        }
    }
    
    // MARK: - Smart Time Section
    
    private var smartTimeSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Current selection summary
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
                            Text("all_day")
                                .font(DS.Typography.caption())
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: DS.Spacing.xs) {
                        Text("change")
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
            
            // Expanded date picker
            if showDatePicker {
                expandedDatePicker
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
                    
                    Text("all_day")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                }
            }
            .tint(Color.accentPrimary)
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
                
                Text("starts")
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
                
                Text("ends")
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
                    
                    Text("duration")
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
    
    // MARK: - Optional Fields Section
    
    private var optionalFieldsSection: some View {
        VStack(spacing: 0) {
            // Participants
            EditCollapsibleParticipantsRow(
                selectedIds: $selectedParticipants,
                members: familyMemberVM.familyMembers,
                isExpanded: $showParticipants
            )
            
            Divider().padding(.leading, 48)
            
            // More options
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
                    
                    Text("more_options")
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
                    
                    Text("notes")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                }
                
                TextField("add_notes", text: $notes, axis: .vertical)
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
                
                Text("color")
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
                                        .foregroundStyle(.textOnAccent)
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
            dateFormatter.dateFormat = "'\(AppStrings.localized("today"))'"
        } else if calendar.isDateInTomorrow(startDate) {
            dateFormatter.dateFormat = "'\(AppStrings.localized("tomorrow"))'"
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
                return "\(days) \(days == 1 ? AppStrings.localized("day") : AppStrings.localized("days")), \(hours) \(AppStrings.localized("hr"))"
            }
            return "\(days) \(days == 1 ? AppStrings.localized("day") : AppStrings.localized("days"))"
        } else if let hours = components.hour, hours > 0 {
            if let minutes = components.minute, minutes > 0 {
                return "\(hours) \(AppStrings.localized("hr")) \(minutes) \(AppStrings.localized("min"))"
            }
            return "\(hours) \(hours == 1 ? AppStrings.localized("hour") : AppStrings.localized("hours"))"
        } else if let minutes = components.minute {
            return "\(minutes) \(AppStrings.localized("min"))"
        }
        return ""
    }
    
    // MARK: - Save Event
    
    private func saveEvent() {
        isTitleFocused = false
        isNotesFocused = false
        isLoading = true
        saveError = nil
        
        var updated = event
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.description = notes.isEmpty ? nil : notes
        updated.startDate = startDate
        updated.endDate = endDate
        updated.isAllDay = isAllDay
        updated.color = "#\(selectedColor.replacingOccurrences(of: "#", with: ""))"
        updated.participants = Array(selectedParticipants)
        
        Task {
            await familyViewModel.updateEvent(updated)
            isLoading = false
            
            if let error = familyViewModel.errorMessage {
                saveError = error
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

// MARK: - Edit Collapsible Participants Row

private struct EditCollapsibleParticipantsRow: View {
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
                        Text("add_participants")
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
                            .foregroundStyle(.textOnAccent)
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
    let familyVM = FamilyViewModel()
    EditEventView(event: CalendarEvent(
        familyId: "test",
        title: "Family Dinner",
        description: "Weekly family dinner",
        startDate: Date(),
        endDate: Date().addingTimeInterval(7200),
        isAllDay: false,
        color: "7C3AED",
        createdBy: "user1",
        participants: ["user1"],
        linkedTaskId: nil,
        eventType: nil,
        createdAt: Date()
    ))
    .environment(AuthViewModel())
    .environment(familyVM)
    .environment(familyVM.familyMemberVM)
}
