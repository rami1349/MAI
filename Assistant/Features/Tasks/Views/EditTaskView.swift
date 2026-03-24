//
//  EditTaskView.swift
//  Assistant
//
//  Created by Ramiro  on 2/10/26.


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
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Task Type
                Section {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(FamilyTask.TaskType.allCases, id: \.self) { type in
                            Button {
                                withAnimation { taskType = type }
                                DS.Haptics.light()
                            } label: {
                                VStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: type.icon)
                                        .font(DS.Typography.heading())
                                    Text(type.displayName)
                                        .font(DS.Typography.bodySmall())
                                }
                                .foregroundStyle(taskType == type ? .textOnAccent : .textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.md)
                                        .fill(taskType == type ? Color.accentPrimary : Color.themeCardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.md)
                                        .stroke(taskType == type ? Color.clear : Color.themeCardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("type")
                }
                .listRowBackground(Color.backgroundCard)
                
                // MARK: - Basics
                Section {
                    TextField("task_title", text: $title)
                        .focused($focusedField, equals: .title)
                    
                    TextField("description_optional", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($focusedField, equals: .description)
                }
                .listRowBackground(Color.backgroundCard)
                
                // MARK: - Assignment
                Section {
                    Button {
                        activeSheet = .assignee
                    } label: {
                        HStack {
                            Label("assigned_to", systemImage: "person")
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            if let assignedTo, let member = familyMemberVM.getMember(by: assignedTo) {
                                HStack(spacing: DS.Spacing.xs) {
                                    AvatarView(user: member, size: 24)
                                    Text(member.displayName)
                                        .foregroundStyle(.textSecondary)
                                }
                            } else {
                                Text("unassigned")
                                    .foregroundStyle(.textTertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                    }
                    
                    Button {
                        activeSheet = .group
                    } label: {
                        HStack {
                            Label("task_group", systemImage: "folder")
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            if let groupId = selectedGroupId,
                               let group = familyMemberVM.getTaskGroup(by: groupId) {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: group.icon)
                                        .foregroundStyle(Color(hex: group.color))
                                    Text(group.name)
                                        .foregroundStyle(.textSecondary)
                                }
                            } else {
                                Text("no_group")
                                    .foregroundStyle(.textTertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                    }
                }
                .listRowBackground(Color.backgroundCard)
                
                // MARK: - Dates
                Section {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    
                    Toggle("Scheduled Time", isOn: $hasScheduledTime)
                    
                    if hasScheduledTime {
                        DatePicker("time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    }
                }
                .listRowBackground(Color.backgroundCard)
                
                // MARK: - Priority
                Section {
                    Picker("priority", selection: $priority) {
                        ForEach(FamilyTask.TaskPriority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.backgroundCard)
                
                // MARK: - Reward & Proof
                Section {
                    // Reward input
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(DS.Typography.heading())
                            .foregroundStyle(.accentGreen)
                        
                        Text("reward")
                            .foregroundStyle(.textPrimary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("$")
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
                    
                    // Proof toggle
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(DS.Typography.body())
                            .foregroundStyle(.accentTertiary)
                        
                        Text("require_proof")
                            .foregroundStyle(.textPrimary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $requiresProof)
                            .labelsHidden()
                            .tint(Color.accentPrimary)
                    }
                } header: {
                    Text("incentives")
                }
                .listRowBackground(Color.backgroundCard)
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .animation(.spring(response: 0.3), value: taskType)
            .navigationTitle("edit_task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { saveTask() }
                        .fontWeight(.semibold)
                        .disabled(!isValid || isLoading)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("done") { focusedField = nil }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .assignee:
                    MemberPicker(selectedMemberId: $assignedTo)
                        .presentationBackground(Color.backgroundPrimary)
                case .group:
                    TaskGroupPicker(selectedGroupId: $selectedGroupId)
                        .presentationBackground(Color.backgroundPrimary)
                }
            }
            .overlay {
                if showSuccess {
                    SuccessDismissOverlay(message: "Task Updated!") {
                        dismiss()
                    }
                }
            }
            .globalErrorBanner(errorMessage: $saveError)
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
