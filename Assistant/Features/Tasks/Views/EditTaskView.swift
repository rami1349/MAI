//
//  EditTaskView.swift
//  Assistant
//
//  PURPOSE:
//    Modal form for editing an existing task. Pre-populates all fields
//    from the task model and saves changes via FamilyViewModel.
//
//  ARCHITECTURE ROLE:
//    Form modal — presented from TaskDetailView.
//    Calls FamilyViewModel.updateTask() on save.
//
//  DATA FLOW:
//    FamilyTask (input) → pre-filled fields
//    FamilyViewModel → updateTask()
//

import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    
    let task: FamilyTask
    
    // MARK: - Editable State (seeded from task)
    @State private var title: String
    @State private var description: String
    @State private var assignedTo: String?
    @State private var dueDate: Date
    @State private var hasScheduledTime: Bool
    @State private var scheduledTime: Date
    @State private var priority: FamilyTask.TaskPriority
    @State private var selectedGroupId: String?
    @State private var taskType: FamilyTask.TaskType
    @State private var rewardAmount: String
    @State private var requiresProof: Bool
    
    /// Parse reward string to Int for comparisons and saving
    private var parsedReward: Int {
        Int(rewardAmount) ?? 0
    }
    
    // UI state
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var saveError: String? = nil
    @State private var activeSheet: EditTaskSheet? = nil
    @FocusState private var focusedField: FocusField?
    
    enum FocusField: Hashable { case title, description }
    enum EditTaskSheet: Identifiable {
        case assignee, group
        var id: Int { hashValue }
    }
    
    // MARK: - Init
    
    init(task: FamilyTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description ?? "")
        _assignedTo = State(initialValue: task.assignedTo)
        _dueDate = State(initialValue: task.dueDate)
        _hasScheduledTime = State(initialValue: task.scheduledTime != nil)
        _scheduledTime = State(initialValue: task.scheduledTime ?? task.dueDate)
        _priority = State(initialValue: task.priority)
        _selectedGroupId = State(initialValue: task.groupId)
        _taskType = State(initialValue: task.taskType ?? .chore)
        _rewardAmount = State(initialValue: {
            let amount = Int(task.rewardAmount ?? 0)
            return amount > 0 ? String(amount) : ""
        }())
        _requiresProof = State(initialValue: task.requiresProof)
    }
    
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeSurfacePrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        taskTypeSection
                        basicsSection
                        assignmentSection
                        dateSection
                        prioritySection
                        incentiveSection
                        
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, DS.Spacing.screenH)
                    .padding(.top, DS.Spacing.md)
                    .constrainedWidth(.form)
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
                    Text("edit_task")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveTask) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("save")
                                .font(DS.Typography.label())
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(isValid ? .accentPrimary : .textTertiary)
                    .disabled(!isValid || isLoading)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("done") { focusedField = nil }
                }
            }
            .animation(.spring(response: 0.3), value: taskType)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .assignee:
                    MemberPicker(selectedMemberId: $assignedTo)
                        .presentationBackground(Color.themeSurfacePrimary)
                case .group:
                    TaskGroupPicker(selectedGroupId: $selectedGroupId)
                        .presentationBackground(Color.themeSurfacePrimary)
                }
            }
            .overlay {
                if showSuccess {
                    SuccessDismissOverlay(message: "task_updated") {
                        dismiss()
                    }
                }
            }
            .globalErrorBanner(errorMessage: $saveError)
        }
    }
    
    // MARK: - Task Type Section
    
    private var taskTypeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("type")
                .font(DS.Typography.caption())
                .foregroundStyle(.textSecondary)
            
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
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Basics Section (Title + Description)
    
    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            TextField("task_title", text: $title)
                .font(DS.Typography.body())
                .focused($focusedField, equals: .title)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(Color.themeCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(focusedField == .title ? Color.accentPrimary : Color.themeCardBorder,
                                lineWidth: focusedField == .title ? 2 : 1)
                )
            
            TextField("description_optional", text: $description, axis: .vertical)
                .font(DS.Typography.body())
                .lineLimit(2...5)
                .focused($focusedField, equals: .description)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(Color.themeCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(focusedField == .description ? Color.accentPrimary : Color.themeCardBorder,
                                lineWidth: focusedField == .description ? 2 : 1)
                )
        }
    }
    
    // MARK: - Assignment Section
    
    private var assignmentSection: some View {
        VStack(spacing: 0) {
            // Assignee row
            Button {
                activeSheet = .assignee
            } label: {
                HStack {
                    Image(systemName: "person")
                        .font(DS.Typography.body())
                        .foregroundStyle(.accentPrimary)
                        .frame(width: 24)
                    
                    Text("assigned_to")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                    
                    if let assignedTo, let member = familyMemberVM.getMember(by: assignedTo) {
                        HStack(spacing: DS.Spacing.xs) {
                            AvatarView(user: member, size: 24)
                            Text(member.displayName)
                                .font(DS.Typography.body())
                                .foregroundStyle(.textSecondary)
                        }
                    } else {
                        Text("unassigned")
                            .font(DS.Typography.body())
                            .foregroundStyle(.textTertiary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                }
                .padding(DS.Spacing.md)
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 48)
            
            // Task group row
            Button {
                activeSheet = .group
            } label: {
                HStack {
                    Image(systemName: "folder")
                        .font(DS.Typography.body())
                        .foregroundStyle(.accentPrimary)
                        .frame(width: 24)
                    
                    Text("task_group")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                    
                    if let groupId = selectedGroupId,
                       let group = familyMemberVM.getTaskGroup(by: groupId) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: group.icon)
                                .foregroundStyle(Color(hex: group.color))
                            Text(group.name)
                                .font(DS.Typography.body())
                                .foregroundStyle(.textSecondary)
                        }
                    } else {
                        Text("no_group")
                            .font(DS.Typography.body())
                            .foregroundStyle(.textTertiary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textTertiary)
                }
                .padding(DS.Spacing.md)
            }
            .buttonStyle(.plain)
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
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        VStack(spacing: 0) {
            // Due date
            HStack {
                Image(systemName: "calendar")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 24)
                
                Text("due_date")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                DatePicker("", selection: $dueDate, displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(DS.Spacing.md)
            
            Divider().padding(.leading, 48)
            
            // Scheduled time toggle
            HStack {
                Image(systemName: "clock")
                    .font(DS.Typography.body())
                    .foregroundStyle(hasScheduledTime ? .accentPrimary : .textTertiary)
                    .frame(width: 24)
                
                Toggle("scheduled_time", isOn: $hasScheduledTime)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)
                    .tint(Color.accentPrimary)
            }
            .padding(DS.Spacing.md)
            
            // Time picker (when toggled on)
            if hasScheduledTime {
                Divider().padding(.leading, 48)
                
                HStack {
                    Image(systemName: "clock.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(.accentPrimary)
                        .frame(width: 24)
                    
                    Text("time")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                    
                    DatePicker("", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
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
        .animation(.spring(response: 0.3), value: hasScheduledTime)
    }
    
    // MARK: - Priority Section
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("priority")
                .font(DS.Typography.caption())
                .foregroundStyle(.textSecondary)
            
            Picker("priority", selection: $priority) {
                ForEach(FamilyTask.TaskPriority.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Incentive Section (Reward + Proof)
    
    private var incentiveSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("incentives")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textSecondary)
                
                Spacer()
                
                Text("optional")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.textTertiary)
            }
            
            VStack(spacing: 0) {
                // Reward input
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
                            .font(DS.Typography.heading())
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
                .padding(DS.Spacing.md)
                
                Divider().padding(.leading, 48)
                
                // Proof toggle
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
                }
                .padding(DS.Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.themeCardBorder, lineWidth: 0.5)
            )
            
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
    
    // MARK: - Save
    
    private func saveTask() {
        focusedField = nil
        isLoading = true
        saveError = nil
        
        var updated = task
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.description = description.isEmpty ? nil : description
        updated.assignedTo = assignedTo
        // FIX: Sync assignees array with assignedTo to prevent multi-assignee data loss.
        // Without this, editing a task with 3 assignees would silently drop all but one.
        updated.assignees = [assignedTo].compactMap { $0 }
        updated.groupId = selectedGroupId
        updated.dueDate = dueDate
        updated.scheduledTime = hasScheduledTime ? scheduledTime : nil
        updated.priority = priority
        updated.taskType = taskType
        updated.hasReward = parsedReward > 0
        updated.rewardAmount = parsedReward > 0 ? Double(parsedReward) : nil
        updated.requiresProof = taskType == .homework ? true : requiresProof
        
        Task {
            await familyViewModel.updateTask(updated)
            isLoading = false
            
            if let error = familyViewModel.errorMessage {
                saveError = error
                familyViewModel.errorMessage = nil
                DS.Haptics.error()
            } else {
                withAnimation { showSuccess = true }
            }
        }
    }
}
