//
//  InviteCodeSheet.swift
//  Assistant
//
//  Created by Ramiro  on 2/9/26.
//  Displays the family invite code for sharing with new members
//

import SwiftUI

// MARK: - Invite Code Sheet
struct InviteCodeSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel

    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    
    var inviteCode: String { familyMemberVM.family?.inviteCode ?? "------" }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxxl) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: DS.IconSize.jumbo)).foregroundStyle(.accentPrimary) // DT-exempt: icon sizing
                
                VStack(spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text("invite_code").font(.title2).fontWeight(.bold)
                    }
                    Text("share_code_message")
                        .font(.subheadline).foregroundStyle(.textSecondary)
                }
                
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(Array(inviteCode), id: \.self) { char in
                        Text(String(char))
                            .font(DS.Typography.displayMedium())
                            .foregroundStyle(.accentPrimary)
                            .frame(width: DS.Control.standard, height: DS.Control.large + 6)
                            .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.accentPrimary.opacity(0.1)))
                    }
                }
                
                Button {
                    UIPasteboard.general.string = inviteCode
                } label: {
                    Label("copy_code", systemImage: "doc.on.doc")
                        .font(.headline).foregroundStyle(.textOnAccent)
                        .frame(maxWidth: .infinity).frame(height: DS.Control.large + 6)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.accentPrimary))
                }
                
                Spacer()
            }
            .padding(DS.Layout.adaptiveScreenPadding)
            .constrainedWidth(.form)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }
}
