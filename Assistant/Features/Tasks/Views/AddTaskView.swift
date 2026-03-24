//
//  AddTaskView.swift
//
//


import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    
    // Compatibility: Keep this parameter but ignore it in simplified flow
    var preSelectedGroupId: String? = nil
    
    // MARK: - Form State
    
    @State private var taskType: FamilyTask.TaskType = .chore
    @State private var title: String = ""
    @State private var dueDate: Date = Self.defaultDueDate()
    @State private var selectedAssignees: Set<String> = []  // Only OTHER members
    @State private var rewardAmount: String = ""
    @State private var requiresProof: Bool = false
    
    /// Parse reward string to Int for comparisons and saving
    private var parsedReward: Int {
        Int(rewardAmount) ?? 0
    }
    
    // MARK: - UI State
    
    @State private var showDatePicker: Bool = false
    @State private var isCreating: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String? = nil
    
    @FocusState private var isTitleFocused: Bool
    
    // MARK: - Computed Properties
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    private var currentUserId: String {
        authViewModel.currentUser?.id ?? ""
    }
    
    private var currentUserCapabilities: MemberCapabilities {
        authViewModel.currentUser?.resolvedCapabilities
            ?? CapabilityPreset.standard.capabilities()
    }
    
    /// Only show incentives if user has canAttachRewards AND is assigning to others
    private var showIncentiveOptions: Bool {
        guard currentUserCapabilities.canAttachRewards else { return false }
        return !selectedAssignees.isEmpty
    }
    
    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Members this user can assign tasks to (capability-filtered).
    /// Empty when canAssignTasks is false → assignee section hidden.
    private var assignableMembers: [FamilyUser] {
        let caps = currentUserCapabilities
        guard caps.canAssignTasks else { return [] }
        return familyMemberVM.familyMembers.filter { member in
            guard let memberId = member.id, memberId != currentUserId else { return false }
            return caps.canAssign(to: memberId)
        }
    }
    
    /// Final assignees: if none selected, assign to self
    private var finalAssignees: [String] {
        if selectedAssignees.isEmpty {
            return [currentUserId]
        } else {
            return Array(selectedAssignees)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeSurfacePrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        taskTypeSection
                        titleSection
                        dueDateSection
                        
                        // Only show assignee section if there are other family members
                        if !assignableMembers.isEmpty {
                            assigneeSection
                        }
                        
                        if showIncentiveOptions {
                            incentiveSection
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                    .padding(.top, DS.Spacing.md)
                    .constrainedWidth(.form)
                }
                
                VStack {
                    Spacer()
                    createButton
                }
            }
            .navigationTitle("add_task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                AddTaskDatePickerSheet(selectedDate: $dueDate)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.themeSurfacePrimary)
            }
            .overlay {
                if showSuccess {
                    taskCreatedOverlay
                }
            }
        }
        .animation(.spring(response: 0.3), value: showIncentiveOptions)
        .animation(.spring(response: 0.3), value: taskType)
    }
    
    // MARK: - Task Type Section
    
    private var taskTypeSection: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(FamilyTask.TaskType.allCases, id: \.self) { type in
                Button {
                    withAnimation { taskType = type }
                    DS.Haptics.light()
                } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: type.icon)
                            .font(DS.Typography.displayMedium())
                        Text(type.displayName)
                            .font(DS.Typography.label())
                    }
                    .foregroundStyle(taskType == type ? .textOnAccent : .textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .fill(taskType == type ? Color.accentPrimary : Color.themeCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(taskType == type ? Color.clear : Color.themeCardBorder, lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            TextField("task_name", text: $title)
                .font(DS.Typography.body())
                .focused($isTitleFocused)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(Color.themeCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(isTitleFocused ? Color.accentPrimary : Color.themeCardBorder,
                                lineWidth: isTitleFocused ? 2 : 1)
                )
            
            // Hint for homework - AI will identify subject
            if taskType == .homework {
                HStack(spacing: DS.Spacing.xxs) {
                    Image("samy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: DS.IconSize.xl, height: DS.IconSize.xl)
                    Text("ai_will_identify_subject")
                        .font(DS.Typography.caption())
                }
                .foregroundStyle(.accentPrimary)
            }
        }
    }
    
    // MARK: - Due Date Section
    
    private var dueDateSection: some View {
        Button {
            showDatePicker = true
            DS.Haptics.light()
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                
                Text(formattedDueDate)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(Color.themeCardBorder, lineWidth: 1)
            )
        }
    }
    
    private var formattedDueDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(dueDate) {
            formatter.dateFormat = "'\("today"),' h:mm a"
        } else if calendar.isDateInTomorrow(dueDate) {
            formatter.dateFormat = "'\("tomorrow"),' h:mm a"
        } else {
            formatter.dateFormat = "EEEE, MMM d, h:mm a"
        }
        
        return formatter.string(from: dueDate)
    }
    
    // MARK: - Assignee Section (Only OTHER members)
    
    private var assigneeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("assign_to")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textSecondary)
                
                Spacer()
                if selectedAssignees.isEmpty {
                    Text("assigned_to_me")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(assignableMembers, id: \.id) { member in
                        if let memberId = member.id {
                            AddTaskAssigneeChip(
                                name: member.displayName,
                                avatarURL: member.avatarURL,
                                isSelected: selectedAssignees.contains(memberId),
                                onTap: { toggleAssignee(memberId) }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func toggleAssignee(_ id: String) {
        DS.Haptics.light()
        
        if selectedAssignees.contains(id) {
            selectedAssignees.remove(id)
        } else {
            selectedAssignees.insert(id)
        }
        
        // If no others selected, reset incentives
        if selectedAssignees.isEmpty {
            rewardAmount = ""
            requiresProof = false
        }
    }
    
    // MARK: - Incentive Section
    
    private var incentiveSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("incentives")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textSecondary)
                
                Spacer()
                
                Text("optional")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
            }
            
            // Reward — number input
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.accentGreen)
                
                Text("reward")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("$")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                    
                    TextField("0", text: $rewardAmount)
                        .keyboardType(.numberPad)
                        .font(DS.Typography.heading()) // was .rounded
                        .foregroundStyle(parsedReward > 0 ? .accentGreen : .textTertiary)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: rewardAmount) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue { rewardAmount = filtered }
                            if parsedReward >= 5 && !requiresProof {
                                requiresProof = true
                            }
                        }
                }
            }
            .standardCard()
            
            // Proof — simple toggle, accepts any file type
            HStack {
                Image(systemName: "camera.fill")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentTertiary)
                
                Text("require_proof")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $requiresProof)
                    .labelsHidden()
                    .tint(Color.accentPrimary)
                    .onChange(of: requiresProof) { _, _ in
                        DS.Haptics.light()
                    }
            }
            .standardCard()
            
            if parsedReward >= 5 && requiresProof {
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "lightbulb")
                        .font(DS.Typography.bodySmall())
                    Text("proof_auto_enabled_hint")
                        .font(DS.Typography.caption())
                }
                .foregroundStyle(.textTertiary)
            }
        }
    }
    
    // MARK: - Create Button
    
    private var createButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                createTask()
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    if isCreating {
                        ProgressView()
                            .tint(Color.textOnAccent)
                    }
                    Text("create_task")
                        .font(DS.Typography.label())
                }
                .foregroundStyle(.textOnAccent)
                .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(canCreate ? Color.accentPrimary : Color.textTertiary)
                )
            }
            .disabled(!canCreate || isCreating)
            .padding(.horizontal, DS.Spacing.screenH)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.themeSurfacePrimary)
        }
    }
    
    // MARK: - Success Overlay
    
    private var taskCreatedOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.displayLarge())
                    .foregroundStyle(.statusSuccess)
                
                Text("task_created")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)
            }
            .padding(DS.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xxl)
                    .fill(Color.themeCardBackground)
            )
            .elevation3()
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.0))
                dismiss()
            }
        }
    }
    
    // MARK: - Create Task Action
    
    private func createTask() {
        guard canCreate, !isCreating else { return }
        
        isCreating = true
        DS.Haptics.medium()
        
        Task {
            do {
                // For homework: auto-enable proof since AI needs image to verify
                let finalRequiresProof = taskType == .homework ? true : requiresProof
                
                // Determine if assigning to self only
                let assigningToSelfOnly = selectedAssignees.isEmpty
                let hasRewardFinal = !assigningToSelfOnly && parsedReward > 0
                
                let task = FamilyTask(
                    familyId: authViewModel.currentUser?.familyId ?? "",
                    groupId: nil,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: nil,
                    assignedTo: finalAssignees.first,
                    assignees: finalAssignees,
                    assignedBy: currentUserId,
                    dueDate: dueDate,
                    scheduledTime: dueDate,
                    status: .todo,
                    priority: .medium,
                    createdAt: Date(),
                    completedAt: nil,
                    hasReward: hasRewardFinal,
                    rewardAmount: hasRewardFinal ? Double(parsedReward) : nil,
                    requiresProof: finalRequiresProof,
                    proofType: nil,
                    proofURL: nil,
                    proofURLs: nil,
                    proofVerifiedBy: nil,
                    proofVerifiedAt: nil,
                    rewardPaid: false,
                    isRecurring: false,
                    recurrenceRule: nil,
                    taskType: taskType,
                    homeworkSubject: nil
                )
                
                try await taskVM.createTask(task)
                
                await MainActor.run {
                    isCreating = false
                    showSuccess = true
                    DS.Haptics.success()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    DS.Haptics.error()
                }
            }
        }
    }
    
    private static func defaultDueDate() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day = (components.day ?? 1) + 1
        components.hour = 17
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Assignee Chip

private struct AddTaskAssigneeChip: View {
    let name: String
    let avatarURL: String?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.xs) {
                avatarView
                
                Text(name)
                    .font(DS.Typography.labelSmall())
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.micro())
                }
            }
            .foregroundStyle(isSelected ? .textOnAccent : .textPrimary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule().fill(isSelected ? Color.accentPrimary : Color.themeCardBackground)
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.themeCardBorder, lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let url = avatarURL, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialCircle
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
        } else {
            initialCircle
        }
    }
    
    private var initialCircle: some View {
        Circle()
            .fill(Color.accentPrimary.opacity(0.2))
            .frame(width: 24, height: 24)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(DS.Typography.micro())
                    .foregroundStyle(.accentPrimary)
            )
    }
}

// MARK: - Date Picker Sheet

private struct AddTaskDatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) var dismiss
    
    @State private var tempDate: Date = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                // Quick date buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        AddTaskQuickDateButton(title: "today", date: todayEvening) {
                            tempDate = todayEvening
                        }
                        AddTaskQuickDateButton(title: "tomorrow", date: tomorrowEvening) {
                            tempDate = tomorrowEvening
                        }
                        AddTaskQuickDateButton(title: "this_weekend", date: thisWeekend) {
                            tempDate = thisWeekend
                        }
                        AddTaskQuickDateButton(title: "next_week", date: nextWeek) {
                            tempDate = nextWeek
                        }
                    }
                    .padding(.horizontal, DS.Spacing.screenH)
                }
                
                // Calendar - let it use natural height
                DatePicker(
                    "",
                    selection: $tempDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, DS.Spacing.screenH)
                
                Spacer()
            }
            .padding(.top, DS.Spacing.md)
            .navigationTitle("due_date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        selectedDate = tempDate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                tempDate = selectedDate
            }
        }
    }
    
    private var todayEvening: Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    private var tomorrowEvening: Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
    
    private var thisWeekend: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: Date()) ?? Date()
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: saturday) ?? saturday
    }
    
    private var nextWeek: Date {
        let next = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: next) ?? next
    }
}

private struct AddTaskQuickDateButton: View {
    let title: String
    let date: Date
    let onTap: () -> Void
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.labelSmall())
                    .foregroundStyle(.textPrimary)
                Text(formattedDate)
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(Color.themeCardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    AddTaskView()
        .environment(AuthViewModel())
        .environment(FamilyMemberViewModel())
        .environment(TaskViewModel())
}
