//
//  AvatarView.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//


import SwiftUI

struct AvatarView: View {
    let user: FamilyUser?
    var size: CGFloat = DS.Avatar.md
    
    var body: some View {
        Group {
            if let url = user?.avatarURL, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.accentPrimary.opacity(0.3), lineWidth: DS.Border.emphasized)
        )
    }
    
    private var initialsView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentPrimary, .accentBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(user?.displayName.prefix(2).uppercased() ?? "?")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

/// Small avatar variant for filter chips and compact displays
struct MemberAvatarSmall: View {
    let user: FamilyUser
    var size: CGFloat = DS.Avatar.xs
    
    var body: some View {
        Group {
            if let url = user.avatarURL, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private var initialsView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentPrimary, .accentBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(user.displayName.prefix(1).uppercased())
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// Type alias for backward compatibility
typealias MemberAvatar = AvatarView

#Preview {
    HStack(spacing: 16) {
        AvatarView(user: nil, size: 32)
        AvatarView(user: nil, size: 44)
        AvatarView(user: nil, size: 60)
    }
}
