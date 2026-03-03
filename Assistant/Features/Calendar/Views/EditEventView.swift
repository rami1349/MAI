//
//  EditEventView.swift
//  FamilyHub
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
                    Button(L10n.cancel) { dismiss() }
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text(L10n.editEvent)
                        .font(DS.Typography.subheading())
                        .foregroundStyle(Color.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveEvent) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(L10n.save)
                                .font(DS.Typography.label())
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(title.isEmpty ? Color.textTertiary : Color.accentPrimary)
                    .disabled(title.isEmpty || isLoading)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(L10n.done) {
                            isTitleFocused = false
                            isNotesFocused = false
                        }
                        .font(DS.Typography.label())
                    }
                }
            }
            .overlay {
                if showSuccess {
                    SuccessDismissOverlay(message: L10n.eventUpdated) {
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
            Text(L10n.eventWhatHappening)
                .font(DS.Typography.caption())
                .foregroundStyle(Color.textTertiary)
            
            TextField(L10n.eventTitlePlaceholder, text: $title)
                .font(DS.Typography.displayMedium())
                .foregroundStyle(Color.textPrimary)
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
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedDateRange)
                            .font(DS.Typography.body())
                            .foregroundStyle(Color.textPrimary)
                        
                        if isAllDay {
                            Text(L10n.allDay)
                                .font(DS.Typography.caption())
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.change)
                            .font(DS.Typography.caption())
                            .foregroundStyle(Color.accentPrimary)
                        
                        Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                            .font(DS.Typography.bodySmall())
                            .foregroundStyle(Color.accentPrimary)
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
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 24)
                    
                    Text(L10n.allDay)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textPrimary)
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
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 24)
                
                Text(L10n.starts)
                    .font(DS.Typography.body())
                    .foregroundStyle(Color.textPrimary)
                
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
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24)
                
                Text(L10n.ends)
                    .font(DS.Typography.body())
                    .foregroundStyle(Color.textPrimary)
                
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
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 24)
                    
                    Text(L10n.duration)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textSecondary)
                    
                    Spacer()
                    
                    Text(durationText)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textSecondary)
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
                        .foregroundStyle(showMoreOptions ? Color.accentPrimary : Color.textTertiary)
                        .frame(width: 24)
                    
                    Text(L10n.moreOptions)
                        .font(DS.Typography.body())
                        .foregroundStyle(showMoreOptions ? Color.textPrimary : Color.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: showMoreOptions ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(Color.textTertiary)
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
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 24)
                    
                    Text(L10n.notes)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textSecondary)
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
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24)
                
                Text(L10n.color)
                    .font(DS.Typography.body())
                    .foregroundStyle(Color.textSecondary)
                
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
                        .foregroundStyle(selectedIds.isEmpty ? Color.textTertiary : Color.accentPrimary)
                        .frame(width: 24)
                    
                    if selectedIds.isEmpty {
                        Text(L10n.addParticipants)
                            .font(DS.Typography.body())
                            .foregroundStyle(Color.textTertiary)
                    } else {
                        Text(participantsSummary)
                            .font(DS.Typography.body())
                            .foregroundStyle(Color.textPrimary)
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
                        .foregroundStyle(Color.textTertiary)
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
                                    .foregroundStyle(Color.textPrimary)
                                
                                Spacer()
                                
                                if let id = member.id, selectedIds.contains(id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(DS.Typography.heading())
                                        .foregroundStyle(Color.accentPrimary)
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
    .environment({ let vm = FamilyViewModel(); return vm }())
    .environment({ let vm = FamilyViewModel(); return vm.familyMemberVM }())
}
