//
//  HomePendingVerificationSection.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//



import SwiftUI
import UIKit

// MARK: - Pending Verification Section

struct HomePendingVerificationSection: View {
    let tasks: [FamilyTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 14))
                    .foregroundColor(Color.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                
                Text(L10n.awaitingVerification)
                    .font(DS.Typography.subheading())
                    .foregroundColor(Color.textPrimary)
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
                    .font(.system(size: 18))
                    .foregroundColor(Color.accentPrimary)
            }
            
            // Text
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.calendarAccess)
                    .font(DS.Typography.label())
                    .foregroundColor(Color.textPrimary)
                
                Text(L10n.enableCalendarMessage)
                    .font(DS.Typography.caption())
                    .foregroundColor(Color.textSecondary)
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
                    .foregroundColor(.white)
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
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(Color.accentPrimary.opacity(0.06))
        )
    }
}

// MARK: - Pending Verification Card

struct PendingVerificationCard: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var familyViewModel: FamilyViewModel
    @EnvironmentObject var familyMemberVM: FamilyMemberViewModel
    
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
                            .foregroundColor(Color.textPrimary)
                        
                        Text(L10n.submittedProof)
                            .font(DS.Typography.micro())
                            .foregroundColor(Color.textTertiary)
                    }
                }
                
                Spacer()
                
                if task.hasReward, let amount = task.rewardAmount {
                    Text(amount.currencyString)
                        .font(DS.Typography.label())
                        .foregroundColor(.accentGreen)
                }
            }
            
            // Task title
            Text(task.title)
                .font(DS.Typography.body())
                .foregroundColor(Color.textPrimary)
            
            // View proof button (supports multiple proof images)
            if task.hasProofUploaded {
                Button(action: { showProof = true }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: task.proofType == .video ? "play.circle.fill" : "doc.fill")
                            .font(.system(size: 14))
                        
                        Text(L10n.viewProof)
                            .font(DS.Typography.captionMedium())
                        
                        // Show count if multiple proofs
                        if task.allProofURLs.count > 1 {
                            Text("(\(task.allProofURLs.count))")
                                .font(DS.Typography.caption())
                                .foregroundColor(Color.textTertiary)
                        }
                    }
                    .foregroundColor(Color.accentPrimary)
                }
            }
            
            // Action buttons
            HStack(spacing: DS.Spacing.md) {
                // Reject
                Button(action: {
                    print(" Reject button tapped")
                    print("   - task.id: \(task.id ?? "nil")")
                    print("   - currentUser.id: \(authViewModel.currentUser?.id ?? "nil")")
                    guard !actionInFlight else { return }
                    actionInFlight = true
                    Task {
                        await familyViewModel.verifyProof(
                            for: task,
                            verifierId: authViewModel.currentUser?.id ?? "",
                            approved: false
                        )
                        actionInFlight = false
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                }) {
                    HStack(spacing: DS.Spacing.xs) {
                        if actionInFlight {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(Color(hex: "E57373"))
                        }
                        Text(L10n.reject)
                            .font(DS.Typography.captionMedium())
                    }
                    .foregroundColor(Color(hex: "E57373"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(Color(hex: "E57373").opacity(0.5), lineWidth: 1)
                    )
                }
                .disabled(actionInFlight)
                
                // Approve
                Button(action: {
                    print(" Approve button tapped")
                    print("   - task.id: \(task.id ?? "nil")")
                    print("   - currentUser.id: \(authViewModel.currentUser?.id ?? "nil")")
                    guard !actionInFlight else { return }
                    actionInFlight = true
                    Task {
                        await familyViewModel.verifyProof(
                            for: task,
                            verifierId: authViewModel.currentUser?.id ?? "",
                            approved: true
                        )
                        actionInFlight = false
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }) {
                    HStack(spacing: DS.Spacing.xs) {
                        if actionInFlight {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        }
                        Text(L10n.approveLabel)
                            .font(DS.Typography.captionMedium())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color.accentGreen)
                    )
                }
                .disabled(actionInFlight)
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
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
                    Text(L10n.videoPlayer)
                        .font(DS.Typography.body())
                        .foregroundColor(Color.textSecondary)
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
            .navigationTitle(L10n.proofLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                        .font(DS.Typography.body())
                }
            }
        }
    }
}
