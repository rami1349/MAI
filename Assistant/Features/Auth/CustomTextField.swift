//
//  CustomTextField.swift


import SwiftUI

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)? = nil
    var hasError: Bool = false
    
    // Simple toggle - no ZStack overlay
    @State private var showPassword = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(DS.Typography.body())
                .foregroundStyle(hasError ? .statusError : (isFocused ? .accentPrimary : .textTertiary))
                .frame(width: 24)
            
            // Text field - direct approach, no ZStack overlay
            Group {
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(DS.Typography.body())
            .foregroundStyle(.textPrimary)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .focused($isFocused)
            
            // Show/hide password toggle
            if isSecure && !text.isEmpty {
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(DS.Typography.body())
                        .foregroundStyle(.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md + 2)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(
                    hasError ? Color.statusError.opacity(0.5) :
                    (isFocused ? Color.accentPrimary.opacity(0.3) : Color.clear),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: Color.black.opacity(isFocused ? 0.05 : 0.02),
            radius: isFocused ? 8 : 4,
            x: 0,
            y: 2
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .animation(.easeOut(duration: 0.15), value: hasError)
    }
}

#Preview {
    VStack(spacing: 16) {
        CustomTextField(placeholder: L10n.email, text: .constant(""), icon: "envelope")
        CustomTextField(placeholder: L10n.password, text: .constant("secret"), isSecure: true, icon: "lock")
        CustomTextField(placeholder: L10n.invalidEmailFormat, text: .constant("bad@"), icon: "envelope", hasError: true)
    }
    .padding()
    .background(Color.themeSurfacePrimary)
}
