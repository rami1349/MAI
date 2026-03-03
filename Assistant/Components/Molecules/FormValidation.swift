
//  FormValidation.swift
//  FamilyHub
//
//  Reusable inline validation components for form fields.
//  Used by AuthenticationView but generic enough for any form.
//

import SwiftUI

// MARK: - Form Validator

/// Pure validation functions for real-time field hints.
/// These run on every keystroke — kept lightweight (no network calls).
enum FormValidator {
    
    /// Checks whether a string looks like a plausible email address.
    /// Intentionally permissive — the server is the real authority.
    static func isEmailPlausible(_ email: String) -> Bool {
        guard email.count >= 5 else { return false }
        // At minimum: something@something.something
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Returns a password strength level based on length and complexity.
    static func passwordStrength(_ password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .empty }
        guard password.count >= 6 else { return .tooShort }
        
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.range(of: #"[A-Z]"#, options: .regularExpression) != nil { score += 1 }
        if password.range(of: #"[0-9]"#, options: .regularExpression) != nil { score += 1 }
        if password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil { score += 1 }
        
        switch score {
        case 0...1: return .weak
        case 2...3: return .fair
        default:    return .strong
        }
    }
    
    enum PasswordStrength {
        case empty, tooShort, weak, fair, strong
        
        var meetsMinimum: Bool {
            switch self {
            case .empty, .tooShort: return false
            default: return true
            }
        }
    }
}

// MARK: - Field Hint View

/// Subtle inline hint shown below a form field.
/// Appears with a gentle transition only after the user has begun typing.
struct FieldHint: View {
    let status: HintStatus
    
    enum HintStatus {
        case idle
        case invalid(String)
        case valid(String)
        case info(String)
    }
    
    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .invalid(let message):
            hintRow(icon: "xmark.circle.fill", text: message, color: .accentRed)
        case .valid(let message):
            hintRow(icon: "checkmark.circle.fill", text: message, color: .accentGreen)
        case .info(let message):
            hintRow(icon: "info.circle.fill", text: message, color: .textSecondary)
        }
    }
    
    private func hintRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Password Strength Bar

/// A tiny segmented bar showing password strength visually.
struct PasswordStrengthBar: View {
    let strength: FormValidator.PasswordStrength
    
    private var filledSegments: Int {
        switch strength {
        case .empty, .tooShort: return 0
        case .weak:   return 1
        case .fair:   return 2
        case .strong: return 3
        }
    }
    
    private var color: Color {
        switch strength {
        case .empty, .tooShort: return .gray.opacity(0.3)
        case .weak:   return .accentRed
        case .fair:   return .accentYellow
        case .strong: return .accentGreen
        }
    }
    
    private var label: String {
        switch strength {
        case .empty, .tooShort: return ""
        case .weak:   return L10n.passwordWeak
        case .fair:   return L10n.passwordFair
        case .strong: return L10n.passwordStrong
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Three-segment bar
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < filledSegments ? color : Color.gray.opacity(0.2))
                        .frame(height: 3)
                }
            }
            .frame(width: 48)
            
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: filledSegments)
    }
}
