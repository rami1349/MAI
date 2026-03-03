//
//  AuthenticationView.swift
//  FamilyHub
//
//  LUXURY CALM REDESIGN
//  - Elegant, minimal authentication flow
//  - Soft shadows, premium typography
//  - FIXED: Removed toolbar Done button (tap outside to dismiss)
//  - Uses existing FieldHint and PasswordStrengthBar
//

import SwiftUI
import AuthenticationServices
import UIKit

enum AuthMode {
    case signIn
    case signUp
}

struct AuthenticationView: View {
    @State private var isSignUp: Bool
    
    init(initialMode: AuthMode = .signIn) {
        _isSignUp = State(initialValue: initialMode == .signUp)
    }
    
    var body: some View {
        ZStack {
            // Luxury calm background
            Color.themeSurfacePrimary
                .ignoresSafeArea()
            
            if isSignUp {
                SignUpView(switchToSignIn: { isSignUp = false })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                SignInView(switchToSignUp: { isSignUp = true })
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isSignUp)
    }
}

// MARK: - Auth Error Field Classification

enum AuthErrorField {
    case email
    case password
    case both
    
    static func classify(_ message: String?) -> AuthErrorField? {
        guard let message = message else { return nil }
        let lower = message.lowercased()
        
        if lower.contains("email") || lower.contains("account found") {
            return .email
        } else if lower.contains("password") {
            return .password
        } else if lower.contains("network") || lower.contains("too many") {
            return .both
        }
        return .both
    }
}

// MARK: - Social Login Buttons (Luxury)

struct SocialLoginButtonsView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Continue with Google
            Button(action: {
                Task { await authViewModel.signInWithGoogle() }
            }) {
                HStack(spacing: DS.Spacing.md) {
                    Image("google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    
                    Text(L10n.continueWithGoogle)
                        .font(DS.Typography.label())
                }
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(Color.themeCardBackground)
                )
                .elevation1()
            }
            .disabled(authViewModel.isLoading)
            
            // Sign in with Apple
            AppleSignInButton(authViewModel: authViewModel)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .disabled(authViewModel.isLoading)
        }
    }
}

// MARK: - Apple Sign In Button

struct AppleSignInButton: View {
    let authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        AppleSignInButtonRepresentable(
            authViewModel: authViewModel,
            buttonStyle: colorScheme == .dark ? .white : .black
        )
        .id(colorScheme)
    }
}

struct AppleSignInButtonRepresentable: UIViewRepresentable {
    let authViewModel: AuthViewModel
    let buttonStyle: ASAuthorizationAppleIDButton.Style
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .continue, style: buttonStyle)
        button.cornerRadius = 12
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleAppleSignIn), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.authViewModel = authViewModel
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(authViewModel: authViewModel)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        var authViewModel: AuthViewModel
        private var currentNonce: String?
        
        init(authViewModel: AuthViewModel) {
            self.authViewModel = authViewModel
        }
        
        @objc func handleAppleSignIn() {
            let nonce = AppleSignInNonce.randomNonceString()
            currentNonce = nonce
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return UIWindow()
            }
            return window
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                Task { @MainActor in
                    authViewModel.errorMessage = "Unable to get Apple ID credential"
                }
                return
            }
            
            // Pass the raw PersonNameComponents to AuthViewModel
            let displayName = appleIDCredential.fullName
            
            Task { @MainActor in
                await authViewModel.signInWithApple(
                    idTokenString: idTokenString,
                    nonce: nonce,
                    displayName: displayName
                )
            }
            
            currentNonce = nil
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            
            Task { @MainActor in
                authViewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Or Divider (Luxury)

struct OrDivider: View {
    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            Rectangle()
                .fill(Color.textTertiary.opacity(0.2))
                .frame(height: 0.5)
            
            Text(L10n.orDivider)
                .font(DS.Typography.caption())
                .foregroundStyle(Color.textTertiary)
            
            Rectangle()
                .fill(Color.textTertiary.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Luxury Error Banner

struct LuxuryErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Typography.body())
            
            Text(message)
                .font(DS.Typography.caption())
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Color(hex: "E57373"))
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(Color(hex: "E57373").opacity(0.08))
        )
    }
}

// MARK: - Luxury Primary Button

struct LuxuryAuthButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }
                
                Text(title)
                    .font(DS.Typography.label())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(
                        isDisabled || isLoading
                        ? Color.accentPrimary.opacity(0.4)
                        : Color.accentPrimary
                    )
            )
            .shadow(
                color: isDisabled ? .clear : Color.accentPrimary.opacity(0.25),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(isDisabled || isLoading)
        .animation(.easeOut(duration: 0.15), value: isDisabled)
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var shakeTrigger: Int = 0
    @State private var emailTouched = false
    
    let switchToSignUp: () -> Void
    
    @FocusState private var focusedField: SignInField?
    
    enum SignInField: Hashable {
        case email, password
    }
    
    private var errorField: AuthErrorField? {
        AuthErrorField.classify(authViewModel.errorMessage)
    }
    
    private var emailHasError: Bool {
        guard let field = errorField else { return false }
        return field == .email || field == .both
    }
    
    private var passwordHasError: Bool {
        guard let field = errorField else { return false }
        return field == .password || field == .both
    }
    
    private var emailHintStatus: FieldHint.HintStatus {
        guard emailTouched, !email.isEmpty else { return .idle }
        if emailHasError { return .idle }
        
        if FormValidator.isEmailPlausible(email) {
            return .valid(L10n.validEmail)
        } else {
            return .invalid(L10n.invalidEmailFormat)
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.xl) {
                Spacer().frame(height: DS.Spacing.xxl)
                
                // Logo & Title
                VStack(spacing: DS.Spacing.md) {
                    Image("panda")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                    
                    Text(L10n.appTitle)
                        .font(DS.Typography.displayMedium())
                        .foregroundStyle(Color.textPrimary)
                    
                    Text(L10n.manageFamily)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textSecondary)
                }
                
                // Social Login
                SocialLoginButtonsView()
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                
                // Divider
                OrDivider()
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                
                // Form
                VStack(spacing: DS.Spacing.md) {
                    // Email
                    VStack(spacing: DS.Spacing.xs) {
                        CustomTextField(
                            placeholder: L10n.email,
                            text: $email,
                            icon: "envelope",
                            submitLabel: .next,
                            onSubmit: { focusedField = .password },
                            hasError: emailHasError
                        )
                        .focused($focusedField, equals: .email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        
                        FieldHint(status: emailHintStatus)
                    }
                    
                    // Password
                    CustomTextField(
                        placeholder: L10n.password,
                        text: $password,
                        isSecure: true,
                        icon: "lock",
                        submitLabel: .go,
                        onSubmit: signIn,
                        hasError: passwordHasError
                    )
                    .focused($focusedField, equals: .password)
                    .textContentType(.password)
                    
                    // Forgot Password
                    HStack {
                        Spacer()
                        Button(action: {
                            focusedField = nil
                            Task { await authViewModel.resetPassword(email: email) }
                        }) {
                            Text(L10n.forgotPassword)
                                .font(DS.Typography.captionMedium())
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
                }
                .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                .shake(trigger: shakeTrigger)
                
                // Error
                if let error = authViewModel.errorMessage {
                    LuxuryErrorBanner(message: error)
                        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Sign In Button
                LuxuryAuthButton(
                    title: L10n.signIn,
                    isLoading: authViewModel.isLoading,
                    isDisabled: email.isEmpty || password.isEmpty,
                    action: signIn
                )
                .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                
                // Sign Up Link
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.dontHaveAccount)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textSecondary)
                    
                    Button(action: {
                        focusedField = nil
                        Task { @MainActor in switchToSignUp() }
                    }) {
                        Text(L10n.signUp)
                            .font(DS.Typography.label())
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                
                Spacer().frame(height: DS.Spacing.xxl)
            }
            .constrainedWidth(.form)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedField = nil }
        // NO .toolbar - removed isolated Done button
        .onChange(of: focusedField) { oldValue, _ in
            if oldValue == .email && !email.isEmpty {
                emailTouched = true
            }
        }
        .onChange(of: email) { _, _ in
            if authViewModel.errorMessage != nil { authViewModel.errorMessage = nil }
        }
        .onChange(of: password) { _, _ in
            if authViewModel.errorMessage != nil { authViewModel.errorMessage = nil }
        }
        .onChange(of: authViewModel.errorMessage) { _, newValue in
            if newValue != nil {
                withAnimation(.default) { shakeTrigger += 1 }
                DS.Haptics.error()
            }
        }
    }
    
    private func signIn() {
        focusedField = nil
        Task { await authViewModel.signIn(email: email, password: password) }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date())!
    @State private var showDatePicker = false
    @State private var shakeTrigger: Int = 0
    @State private var emailTouched = false
    @State private var passwordTouched = false
    
    let switchToSignIn: () -> Void
    
    @FocusState private var focusedField: SignUpField?
    
    enum SignUpField: Hashable {
        case displayName, email, password, confirmPassword
    }
    
    var isFormValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    private var errorField: AuthErrorField? {
        AuthErrorField.classify(authViewModel.errorMessage)
    }
    
    private var emailHasError: Bool {
        guard let field = errorField else { return false }
        return field == .email || field == .both
    }
    
    private var passwordHasError: Bool {
        guard let field = errorField else { return false }
        return field == .password || field == .both
    }
    
    private var passwordStrength: FormValidator.PasswordStrength {
        FormValidator.passwordStrength(password)
    }
    
    private var emailHintStatus: FieldHint.HintStatus {
        guard emailTouched, !email.isEmpty else { return .idle }
        if emailHasError { return .idle }
        
        if FormValidator.isEmailPlausible(email) {
            return .valid(L10n.validEmail)
        } else {
            return .invalid(L10n.invalidEmailFormat)
        }
    }
    
    private var passwordHintStatus: FieldHint.HintStatus {
        guard passwordTouched, !password.isEmpty else { return .idle }
        if passwordHasError { return .idle }
        
        switch passwordStrength {
        case .empty:
            return .idle
        case .tooShort:
            return .invalid("\(password.count)/6 " + L10n.charactersMinimum)
        case .weak, .fair, .strong:
            return .valid("\(password.count) " + L10n.characters)
        }
    }
    
    private var confirmHintStatus: FieldHint.HintStatus {
        guard !confirmPassword.isEmpty else { return .idle }
        
        if password == confirmPassword {
            return .valid(L10n.passwordMatch)
        } else {
            return .invalid(L10n.passwordDontMatch)
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.xl) {
                Spacer().frame(height: DS.Spacing.lg)
                
                // Header
                VStack(spacing: DS.Spacing.sm) {
                    Image("panda")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    
                    Text(L10n.createAccount)
                        .font(DS.Typography.displayMedium())
                        .foregroundStyle(Color.textPrimary)
                    
                    Text(L10n.joinFamily)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textSecondary)
                }
                
                // Social Login
                SocialLoginButtonsView()
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                
                // Divider
                OrDivider()
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                
                // Form
                VStack(spacing: DS.Spacing.md) {
                    // Display Name
                    CustomTextField(
                        placeholder: L10n.displayName,
                        text: $displayName,
                        icon: "person",
                        submitLabel: .next,
                        onSubmit: { focusedField = .email }
                    )
                    .focused($focusedField, equals: .displayName)
                    .textContentType(.name)
                    
                    // Email
                    VStack(spacing: DS.Spacing.xs) {
                        CustomTextField(
                            placeholder: L10n.email,
                            text: $email,
                            icon: "envelope",
                            submitLabel: .next,
                            onSubmit: {
                                focusedField = nil
                                showDatePicker = true
                            },
                            hasError: emailHasError
                        )
                        .focused($focusedField, equals: .email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        
                        FieldHint(status: emailHintStatus)
                    }
                    
                    // Date of Birth
                    Button(action: {
                        focusedField = nil
                        showDatePicker = true
                    }) {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "calendar")
                                .font(DS.Typography.body())
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 24)
                            
                            Text(dateOfBirth.formattedDate)
                                .font(DS.Typography.body())
                                .foregroundStyle(Color.textPrimary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.captionMedium())
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md + 2)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(Color.themeCardBackground)
                        )
                        .elevation1()
                    }
                    
                    // Password
                    VStack(spacing: DS.Spacing.xs) {
                        CustomTextField(
                            placeholder: L10n.password,
                            text: $password,
                            isSecure: true,
                            icon: "lock",
                            submitLabel: .next,
                            onSubmit: { focusedField = .confirmPassword },
                            hasError: passwordHasError
                        )
                        .focused($focusedField, equals: .password)
                        .textContentType(.newPassword)
                        
                        if passwordTouched && !password.isEmpty && !passwordHasError {
                            HStack(spacing: DS.Spacing.sm) {
                                FieldHint(status: passwordHintStatus)
                                Spacer()
                                if passwordStrength.meetsMinimum {
                                    PasswordStrengthBar(strength: passwordStrength)
                                }
                            }
                        }
                    }
                    
                    // Confirm Password
                    VStack(spacing: DS.Spacing.xs) {
                        CustomTextField(
                            placeholder: L10n.confirmPassword,
                            text: $confirmPassword,
                            isSecure: true,
                            icon: "lock.fill",
                            submitLabel: .go,
                            onSubmit: { if isFormValid { signUp() } },
                            hasError: passwordHasError
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .textContentType(.newPassword)
                        
                        FieldHint(status: confirmHintStatus)
                    }
                }
                .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                .shake(trigger: shakeTrigger)
                
                // Error
                if let error = authViewModel.errorMessage {
                    LuxuryErrorBanner(message: error)
                        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Sign Up Button
                LuxuryAuthButton(
                    title: L10n.createAccount,
                    isLoading: authViewModel.isLoading,
                    isDisabled: !isFormValid,
                    action: signUp
                )
                .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                
                // Sign In Link
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.alreadyHaveAccount)
                        .font(DS.Typography.body())
                        .foregroundStyle(Color.textSecondary)
                    
                    Button(action: {
                        focusedField = nil
                        Task { @MainActor in switchToSignIn() }
                    }) {
                        Text(L10n.signIn)
                            .font(DS.Typography.label())
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                
                Spacer().frame(height: DS.Spacing.xxl)
            }
            .constrainedWidth(.form)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedField = nil }
        // NO .toolbar - removed isolated Done button
        .sheet(isPresented: $showDatePicker, onDismiss: {
            focusedField = .password
        }) {
            DatePickerSheet(selectedDate: $dateOfBirth, title: L10n.dateOfBirth)
        }
        .onChange(of: focusedField) { oldValue, _ in
            if oldValue == .email && !email.isEmpty {
                emailTouched = true
            }
            if oldValue == .password && !password.isEmpty {
                passwordTouched = true
            }
        }
        .onChange(of: email) { _, _ in
            if authViewModel.errorMessage != nil { authViewModel.errorMessage = nil }
        }
        .onChange(of: password) { _, _ in
            if authViewModel.errorMessage != nil { authViewModel.errorMessage = nil }
        }
        .onChange(of: authViewModel.errorMessage) { _, newValue in
            if newValue != nil {
                withAnimation(.default) { shakeTrigger += 1 }
                DS.Haptics.error()
            }
        }
    }
    
    private func signUp() {
        focusedField = nil
        Task {
            await authViewModel.signUp(
                email: email,
                password: password,
                displayName: displayName,
                dateOfBirth: dateOfBirth
            )
        }
    }
}

#Preview {
    AuthenticationView()
        .environment(AuthViewModel())
}
