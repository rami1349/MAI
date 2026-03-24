//
//  HomeHeaderSection.swift
//  
//


import SwiftUI
import UIKit
import os

// MARK: - Pending Verification Section

struct HomePendingVerificationSection: View {
    let tasks: [FamilyTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.seal")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text("awaitingVerification")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)
                Circle()
                    .fill(Color.accentPrimary)
                    .frame(width: 8, height: 8)
                
                Spacer()
            }
            
            // Verification cards
            VStack(spacing: DS.Spacing.sm) {
                ForEach(tasks, id: \.stableId) { task in
                    PendingVerificationCard(task: task)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.screenH)
    }
}

// MARK: - Calendar Permission Prompt

struct CalendarPermissionPrompt: View {
    let authStatus: CalendarAuthStatus
    let onRequestAccess: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.accentPrimary)
            }
            
            // Text
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("calendarAccess")
                    .font(DS.Typography.label())
                    .foregroundStyle(.textPrimary)
                
                Text("enableCalendarMessage")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textSecondary)
            }
            
            Spacer()
            
            // Button
            Button(action: {
                if authStatus == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    onRequestAccess()
                }
            }) {
                Text(authStatus == .denied ? "Settings" : "Enable")
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(.textOnAccent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.accentPrimary)
                    )
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.accentPrimary.opacity(0.06))
        )
    }
}

// MARK: - Pending Verification Card

struct PendingVerificationCard: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    
    let task: FamilyTask
    @State private var showProof = false
    @State private var actionInFlight = false
    
    /// Primary assignee for display (uses allAssignees for multi-assignee support)
    var assignee: FamilyUser? {
        task.primaryAssignee.flatMap { familyMemberVM.getMember(by: $0) }
    }
    
    /// All assignees for multi-assignee tasks
    var allAssigneeUsers: [FamilyUser] {
        task.allAssignees.compactMap { familyMemberVM.getMember(by: $0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header: Avatar + Name + Reward
            HStack {
                if let assignee = assignee {
                    AvatarView(user: assignee, size: 36)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(assignee.displayName)
                            .font(DS.Typography.label())
                            .foregroundStyle(.textPrimary)
                        
                        Text("submittedProof")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                    }
                }
                
                Spacer()
                
                if task.hasReward, let amount = task.rewardAmount {
                    Text(amount.currencyString)
                        .font(DS.Typography.label())
                        .foregroundStyle(.accentGreen)
                }
            }
            
            // Task title
            Text(task.title)
                .font(DS.Typography.body())
                .foregroundStyle(.textPrimary)
            
            // View proof button (supports multiple proof images)
            if task.hasProofUploaded {
                Button(action: { showProof = true }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: task.proofType == .video ? "play.circle.fill" : "doc.fill")
                            .font(DS.Typography.body())
                        
                        Text("viewProof")
                            .font(DS.Typography.captionMedium())
                        
                        // Show count if multiple proofs
                        if task.allProofURLs.count > 1 {
                            Text("(\(task.allProofURLs.count))")
                                .font(DS.Typography.caption())
                                .foregroundStyle(.textTertiary)
                        }
                    }
                    .foregroundStyle(.accentPrimary)
                }
            }
            
            // Action buttons
            HStack(spacing: DS.Spacing.md) {
                // Reject
                Button(action: {
                    Log.tasks.debug("Reject tapped for task \(task.id ?? "nil", privacy: .private)")
                    guard !actionInFlight else { return }
                    actionInFlight = true
                    Task {
                        await familyViewModel.verifyProof(
                            for: task,
                            verifierId: authViewModel.currentUser?.id ?? "",
                            approved: false
                        )
                        actionInFlight = false
                        DS.Haptics.warning()
                    }
                }) {
                    HStack(spacing: DS.Spacing.xs) {
                        if actionInFlight {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(Color.statusError)
                        }
                        Text("reject")
                            .font(DS.Typography.captionMedium())
                    }
                    .foregroundStyle(.statusError)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(Color.statusError.opacity(0.5), lineWidth: 1)
                    )
                }
                .disabled(actionInFlight)
                
                // Approve
                Button(action: {
                    Log.tasks.debug("Approve tapped for task \(task.id ?? "nil", privacy: .private)")
                    guard !actionInFlight else { return }
                    actionInFlight = true
                    Task {
                        await familyViewModel.verifyProof(
                            for: task,
                            verifierId: authViewModel.currentUser?.id ?? "",
                            approved: true
                        )
                        actionInFlight = false
                        DS.Haptics.success()
                    }
                }) {
                    HStack(spacing: DS.Spacing.xs) {
                        if actionInFlight {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        }
                        Text("approveLabel")
                            .font(DS.Typography.captionMedium())
                    }
                    .foregroundStyle(.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(Color.accentGreen)
                    )
                }
                .disabled(actionInFlight)
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
        .sheet(isPresented: $showProof) {
            if let proofURL = task.firstProofURL {
                ProofViewerSheet(proofURL: proofURL, proofType: task.proofType ?? .photo)
            }
        }
    }
}

// MARK: - Proof Viewer Sheet

struct ProofViewerSheet: View {
    @Environment(\.dismiss) var dismiss
    let proofURL: String
    let proofType: FamilyTask.ProofType  // kept for backward compat
    
    /// Infer from URL extension — more reliable than proofType which may be nil
    private var isVideo: Bool {
        let ext = URL(string: proofURL)?.pathExtension.lowercased() ?? ""
        return ["mp4", "mov", "m4v", "avi"].contains(ext) || proofType == .video
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeSurfacePrimary
                    .ignoresSafeArea()
                
                if isVideo {
                    Text("videoPlayer")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    AsyncImage(url: URL(string: proofURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
            .navigationTitle("proofLabel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                        .font(DS.Typography.body())
                }
            }
        }
    }
}
