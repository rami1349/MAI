// ============================================================================
// AuthViewModel.swift
// FamilyHub
//
// PURPOSE:
//   Central authentication controller and session manager for FamilyHub.
//   Owns all Firebase Auth state, user profile hydration, and account lifecycle
//   operations (sign-up, sign-in, OAuth, reauthentication, deletion).
//
// ARCHITECTURE ROLE:
//   - Single source of truth for authentication state across the app.
//   - Injected as @Environment at the root; all views read from here.
//   - Delegates account deletion to AccountDeletionService (data cleanup).
//   - Delegates family CRUD to FamilyManagementService.
//   - Auth state changes are driven exclusively by Firebase's auth listener —
//     sign-in methods never manually set isAuthenticated to prevent race conditions.
//
// DATA FLOW:
//   Firebase Auth → authStateListener → loadUserData() → Firestore snapshot
//   → currentUser (FamilyUser) → Views
//
// KEY DEPENDENCIES:
//   - FirebaseAuth   — identity & session tokens
//   - FirebaseFirestore — user profile storage
//   - GoogleSignIn   — OAuth flow for Google accounts
//   - AuthenticationServices — Sign in with Apple
//   - LocalNotificationService — FCM token lifecycle
//
// SECURITY NOTES:
//   - Sensitive operations (account deletion) require reauthentication.
//   - Apple Sign-In uses a one-time cryptographic nonce (SHA-256) to prevent
//     replay attacks. See AppleSignInNonce.swift.
//   - FCM tokens are removed on sign-out to stop push delivery to stale sessions.
//
// ============================================================================

import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices

/// Manages authentication state and user session for the entire FamilyHub app.
///
/// This class is the authoritative source for whether a user is authenticated,
/// who they are (`currentUser`), and whether they belong to a family.
/// It coordinates Firebase Auth listeners, Firestore profile sync, and
/// all sign-in/sign-out/OAuth flows.
@MainActor
@Observable
class AuthViewModel {
    
    // MARK: - Published State
    //
    // All UI-facing state. Views bind to these directly via @Environment.
    
    /// The currently authenticated user's profile, hydrated from Firestore.
    /// `nil` when logged out. Updated in real-time by a Firestore snapshot listener.
    var currentUser: FamilyUser?
    
    /// `true` once the auth listener has confirmed the user is signed in.
    /// Toggled exclusively by `setupAuthListener()` — never by sign-in methods.
    var isAuthenticated = false
    
    /// `true` when `currentUser.familyId` is non-nil.
    /// Drives routing between FamilySetupView and the main app experience.
    var hasFamily = false
    
    /// Indicates an in-flight network operation. Drives loading spinners.
    var isLoading = false
    
    /// Localized, user-facing error message. Set by `handleAuthError(_:)`.
    /// Cleared at the start of each operation via `withLoading(_:)`.
    var errorMessage: String?
    
    /// Prevents the login screen from flashing on a cold start when the user
    /// is already authenticated. Set to `true` after the auth listener fires
    /// for the first time (for both logged-in and logged-out states).
    ///
    /// Views should gate rendering on `authReady` to avoid a brief unauthenticated
    /// flash before Firebase resolves the persisted session.
    var authReady = false
    
    /// `true` when a sensitive operation (e.g., account deletion) fails because
    /// the session credential is too old. Triggers the reauthentication UI.
    var needsReauthentication = false
    
    /// Controls presentation of the delete-account confirmation sheet.
    var showDeleteAccountSheet = false
    
    // MARK: - Private
    
    /// Handle to the Firebase Auth state listener. Retained so it can be
    /// deregistered on `deinit` to prevent memory leaks.
    @ObservationIgnored private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// Firestore real-time listener for the current user's profile document.
    /// Removed and re-established each time a different user signs in.
    @ObservationIgnored private var userListener: ListenerRegistration?
    
    /// NotificationCenter observer for FCM token refresh events.
    @ObservationIgnored private var fcmObserver: NSObjectProtocol?
    
    /// Firestore singleton accessor. @ObservationIgnored because db access
    /// is infrastructure — not UI state that views should observe.
    private var db: Firestore { Firestore.firestore() }
    
    // MARK: - Initialization
    
    /// Configures the auth state listener and FCM token observer on creation.
    /// This is called once when the app launches via dependency injection.
    init() {
        setupAuthListener()
        setupFCMTokenObserver()
    }
    
    /// Cleans up Firebase listeners to prevent retain cycles and dangling
    /// Firestore connections after the ViewModel is deallocated.
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        userListener?.remove()
        if let observer = fcmObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - FCM Token Observer
    
    /// Listens for FCM token refresh events posted by the AppDelegate/NotificationService.
    ///
    /// FCM tokens can be rotated by the OS at any time. When a new token arrives,
    /// we immediately persist it to Firestore so Cloud Functions can always reach
    /// this device with push notifications. The observer is weak-captured to avoid
    /// retaining the ViewModel from the NotificationCenter.
    private func setupFCMTokenObserver() {
        fcmObserver = NotificationCenter.default.addObserver(
            forName: .fcmTokenReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let userId = self.currentUser?.id {
                    // Re-save the latest token for the authenticated user
                    await LocalNotificationService.shared.saveFCMToken(userId: userId)
                }
            }
        }
    }
    
    // MARK: - ========================
    // MARK: - AUTH STATE LISTENER (Single Source of Truth)
    // MARK: - ========================
    
    /// Establishes the Firebase Auth state listener — the ONLY place that sets
    /// `isAuthenticated`, `currentUser`, and `hasFamily`.
    ///
    /// Design rationale: All sign-in methods (email, Google, Apple) simply call
    /// their respective Firebase SDK methods. This listener then fires automatically,
    /// ensuring state updates are atomic and consistent regardless of sign-in path.
    /// Manually setting `isAuthenticated = true` in each sign-in method would
    /// risk partial state if an intermediate step fails.
    ///
    /// On sign-in:  Loads user profile from Firestore + saves FCM token.
    /// On sign-out: Removes Firestore listener + resets all state atomically.
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let user = user {
                    // User is authenticated — hydrate profile and mark ready
                    await self.loadUserData(userId: user.uid)
                    self.isAuthenticated = true
                    
                    // Persist FCM token for push notification delivery
                    await LocalNotificationService.shared.saveFCMToken(userId: user.uid)
                } else {
                    // User signed out — teardown Firestore listener and reset all state
                    self.userListener?.remove()
                    self.userListener = nil
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.hasFamily = false
                }
                
                // Signal that initial auth resolution is complete.
                // Gates the splash/login screen to prevent the unauthenticated flash.
                if !self.authReady {
                    self.authReady = true
                }
            }
        }
    }
    
    /// Attaches a real-time Firestore snapshot listener to the user's profile document.
    ///
    /// This keeps `currentUser` (including `balance`, `displayName`, etc.) in sync
    /// without requiring manual refreshes. Called by the auth listener after sign-in.
    ///
    /// - Parameter userId: Firebase Auth UID of the signed-in user.
    ///
    /// - Note: Any pre-existing listener is removed first to avoid duplicate listeners
    ///   if the auth state fires multiple times (e.g., token refresh).
    private func loadUserData(userId: String) async {
        // Remove any stale listener from a previous session
        userListener?.remove()
        
        // Real-time snapshot — updates currentUser whenever Firestore data changes
        userListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, snapshot.exists else { return }
                if let user = try? snapshot.data(as: FamilyUser.self) {
                    self.currentUser = user
                    // hasFamily drives whether to show FamilySetupView or main app
                    self.hasFamily = user.familyId != nil
                }
            }
    }
    
    // MARK: - ========================
    // MARK: - LOADING STATE HELPER
    // MARK: - ========================
    
    /// Wraps an async operation with consistent loading state management.
    ///
    /// Uses Swift's `defer` statement to guarantee `isLoading` is always reset
    /// to `false` — even if the operation throws or returns early. Also clears
    /// any previous error message at the start of each operation.
    ///
    /// - Parameter operation: The async work to perform while loading is active.
    /// - Returns: The result of the wrapped operation.
    /// - Throws: Re-throws any error from the wrapped operation.
    private func withLoading<T>(_ operation: () async throws -> T) async rethrows -> T {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false } // Guaranteed cleanup regardless of exit path
        return try await operation()
    }
    
    // MARK: - ========================
    // MARK: - EMAIL/PASSWORD AUTH
    // MARK: - ========================
    
    /// Creates a new Firebase Auth account and writes the user profile to Firestore.
    ///
    /// Steps:
    /// 1. Creates the Firebase Auth credential (email + password).
    /// 2. Writes a `FamilyUser` document to `users/{uid}` in Firestore.
    /// 3. Sets `currentUser` optimistically to prevent a UI flicker while the
    ///    auth listener resolves and the Firestore snapshot fires.
    ///
    /// - Parameters:
    ///   - email: The user's email address (validated by Firebase).
    ///   - password: Minimum 6 characters (enforced by Firebase).
    ///   - displayName: Chosen display name for the family view.
    ///   - dateOfBirth: Used for age-appropriate content and parental controls.
    ///
    /// - Note: `hasCompletedOnboarding: false` ensures new users go through
    ///   the onboarding flow before accessing the main app.
    func signUp(email: String, password: String, displayName: String, dateOfBirth: Date) async {
        await withLoading {
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                
                // Construct the full user profile for Firestore
                let newUser = FamilyUser(
                    id: result.user.uid,
                    email: email,
                    displayName: displayName,
                    avatarURL: nil,
                    dateOfBirth: dateOfBirth,
                    familyId: nil,          // No family until they create or join one
                    role: .member,
                    createdAt: Date(),
                    balance: 0,             // Reward wallet starts empty
                    goal: nil,
                    hasCompletedOnboarding: false   // Forces onboarding on first launch
                )
                
                // Persist profile to Firestore using Codable encoding
                try db.collection("users").document(result.user.uid).setData(from: newUser)
                
                // Optimistic local update — prevents flicker before auth listener fires.
                // The auth listener will also fire and call loadUserData, which is fine
                // (idempotent: same data will be decoded from the snapshot).
                currentUser = newUser
                
            } catch {
                handleAuthError(error)
            }
        }
    }
    
    /// Authenticates an existing user with email and password.
    ///
    /// State updates (isAuthenticated, currentUser, hasFamily) are handled
    /// exclusively by the auth state listener, not here.
    ///
    /// - Parameters:
    ///   - email: The user's registered email address.
    ///   - password: The user's current password.
    func signIn(email: String, password: String) async {
        await withLoading {
            do {
                _ = try await Auth.auth().signIn(withEmail: email, password: password)
                // Auth listener fires → loadUserData() → currentUser populated
            } catch {
                handleAuthError(error)
            }
        }
    }
    
    /// Signs the current user out of Firebase Auth and Google.
    ///
    /// Sequence:
    /// 1. Removes FCM token from Firestore to stop push delivery to this device.
    /// 2. Calls Google Sign-In SDK sign-out (clears Google session).
    /// 3. Calls Firebase Auth sign-out.
    /// 4. Auth listener fires → resets isAuthenticated, currentUser, hasFamily.
    ///
    /// - Note: FCM token removal is fire-and-forget (Task) to avoid blocking the UI.
    func signOut() {
        // Remove push token BEFORE signing out so we can still identify the user
        if let userId = currentUser?.id {
            Task {
                await LocalNotificationService.shared.removeFCMToken(userId: userId)
            }
        }
        
        do {
            GIDSignIn.sharedInstance.signOut() // Clear Google OAuth session
            try Auth.auth().signOut()           // Firebase session teardown
            // Auth listener handles state reset automatically
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Forces a re-fetch of the current user's Firestore profile.
    ///
    /// Used after operations that modify the user document (e.g., balance updates,
    /// onboarding completion) when you need the update reflected immediately
    /// without waiting for the next snapshot event.
    func refreshCurrentUser() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        await loadUserData(userId: userId)
    }
    
    /// Sends a password reset email to the specified address.
    ///
    /// Firebase will deliver a reset link only if the email is registered.
    /// For security, the UI should show a generic success message regardless
    /// of whether the address exists (prevents user enumeration).
    ///
    /// - Parameter email: The email address to send the reset link to.
    func resetPassword(email: String) async {
        await withLoading {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - ========================
    // MARK: - GOOGLE SIGN-IN
    // MARK: - ========================
    
    /// Initiates the Google Sign-In OAuth flow and authenticates with Firebase.
    ///
    /// Flow:
    /// 1. Presents Google's native sign-in sheet from the app's root view controller.
    /// 2. Exchanges the Google ID token + access token for a Firebase credential.
    /// 3. Signs in or links the Firebase account.
    /// 4. If this is a new Google user, creates a Firestore profile document.
    ///
    /// - Note: `getPresentingViewController()` traverses the UIWindowScene hierarchy
    ///   to find the correct presenting controller for OAuth sheet presentation.
    func signInWithGoogle() async {
        await withLoading {
            do {
                guard let presentingVC = Self.getPresentingViewController() else {
                    errorMessage = "Unable to get root view controller"
                    return
                }
                
                // Present Google's native OAuth sign-in sheet
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
                
                // Exchange Google tokens for a Firebase Auth credential
                guard let idToken = result.user.idToken?.tokenString else {
                    errorMessage = "Failed to get Google ID token"
                    return
                }
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                
                let authResult = try await Auth.auth().signIn(with: credential)
                
                // Only create Firestore profile for brand new Google sign-ins
                // (existing users already have a profile document)
                let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false
                if isNewUser {
                    let googleUser = result.user
                    let newUser = FamilyUser(
                        id: authResult.user.uid,
                        email: authResult.user.email ?? "",
                        displayName: googleUser.profile?.name ?? "User",
                        avatarURL: googleUser.profile?.imageURL(withDimension: 200)?.absoluteString,
                        dateOfBirth: Date(),
                        familyId: nil,
                        role: .member,
                        createdAt: Date(),
                        balance: 0,
                        goal: nil,
                        hasCompletedOnboarding: false
                    )
                    try db.collection("users").document(authResult.user.uid).setData(from: newUser)
                }
                // Auth listener handles isAuthenticated + currentUser population
                
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - ========================
    // MARK: - APPLE SIGN-IN
    // MARK: - ========================
    
    /// Completes Sign in with Apple using the identity token and nonce.
    ///
    /// This method is called by the ASAuthorizationControllerDelegate after
    /// Apple delivers the authorization credential. The `nonce` is a cryptographic
    /// value generated before the request (see `AppleSignInNonce.swift`) that
    /// Apple embeds in the identity token. Firebase verifies the nonce to prevent
    /// replay attacks — the same token cannot be reused.
    ///
    /// - Parameters:
    ///   - idTokenString: JWT identity token from Apple's authorization response.
    ///   - nonce: The raw (unhashed) nonce generated before the authorization request.
    ///   - displayName: Full name from Apple's credential (only available on first sign-in;
    ///     Apple does not re-provide the name on subsequent sign-ins).
    func signInWithApple(idTokenString: String, nonce: String, displayName: PersonNameComponents?) async {
        await withLoading {
            do {
                // Build a Firebase credential from Apple's JWT + the original nonce
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,    // Firebase verifies SHA-256(nonce) matches token
                    fullName: displayName
                )
                
                let authResult = try await Auth.auth().signIn(with: credential)
                
                // Create Firestore profile only for first-time Apple sign-ins
                // Apple only provides displayName on the FIRST authentication
                let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false
                if isNewUser {
                    let name = [displayName?.givenName, displayName?.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    
                    let newUser = FamilyUser(
                        id: authResult.user.uid,
                        email: authResult.user.email ?? "",
                        displayName: name.isEmpty ? "Apple User" : name,
                        avatarURL: nil,     // Apple does not provide profile photos
                        dateOfBirth: Date(),
                        familyId: nil,
                        role: .member,
                        createdAt: Date(),
                        balance: 0,
                        goal: nil,
                        hasCompletedOnboarding: false
                    )
                    try db.collection("users").document(authResult.user.uid).setData(from: newUser)
                }
                
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - ========================
    // MARK: - REAUTHENTICATION
    // MARK: - ========================
    //
    // Firebase requires recent authentication before sensitive operations like
    // account deletion. If the user's token is stale, deleteAccount() will set
    // `needsReauthentication = true`, prompting the appropriate reauth UI.
    
    /// Reauthenticates with email/password for sensitive operations (e.g., account deletion).
    ///
    /// - Parameters:
    ///   - email: The user's email address (must match the Firebase Auth account).
    ///   - password: The user's current password.
    /// - Returns: `true` if reauthentication succeeded; `false` otherwise.
    ///
    /// - Note: On success, `needsReauthentication` is set to `false` to dismiss
    ///   the reauth prompt and unblock the pending sensitive operation.
    func reauthenticate(email: String, password: String) async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in"
            return false
        }
        
        return await withLoading {
            do {
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                try await user.reauthenticate(with: credential)
                needsReauthentication = false
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
    }
    
    /// Reauthenticates with Google for users who originally signed in via Google.
    ///
    /// Presents the Google sign-in sheet again to obtain a fresh credential,
    /// then calls Firebase's reauthenticate API. Required before account deletion
    /// for Google-signed-in users.
    ///
    /// - Returns: `true` if reauthentication succeeded; `false` otherwise.
    func reauthenticateWithGoogle() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in"
            return false
        }
        
        return await withLoading {
            do {
                guard let presentingVC = Self.getPresentingViewController() else {
                    errorMessage = "Unable to get root view controller"
                    return false
                }
                
                // Re-trigger Google OAuth to get a fresh token
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
                
                guard let idToken = result.user.idToken?.tokenString else {
                    errorMessage = "Failed to get Google ID token"
                    return false
                }
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                
                try await user.reauthenticate(with: credential)
                needsReauthentication = false
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
    }
    
    /// Reauthenticates with Apple Sign-In for users who originally signed in via Apple.
    ///
    /// - Parameters:
    ///   - idTokenString: Fresh Apple identity token from a new authorization request.
    ///   - nonce: The raw nonce used in the new authorization request.
    /// - Returns: `true` if reauthentication succeeded; `false` otherwise.
    func reauthenticateWithApple(idTokenString: String, nonce: String) async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in"
            return false
        }
        
        return await withLoading {
            do {
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: nil   // Name not needed for reauthentication
                )
                try await user.reauthenticate(with: credential)
                needsReauthentication = false
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
    }
    
    // MARK: - ========================
    // MARK: - ACCOUNT DELETION
    // MARK: - ========================
    
    /// Permanently and irreversibly deletes the user's account and all associated data.
    ///
    /// Delegates data cleanup to `AccountDeletionService`, which handles:
    /// - Firestore document deletion (user profile, tasks, habits, notifications, etc.)
    /// - Firebase Storage cleanup (avatars, proof images)
    /// - Family membership cleanup (or family deletion if user is last member)
    /// - Firebase Auth account deletion
    ///
    /// State reset after deletion is handled by the auth state listener
    /// (same path as a normal sign-out).
    ///
    /// Error paths:
    /// - `requiresReauthentication`: Session too old → sets `needsReauthentication = true`
    ///   to trigger reauth UI, then the user can retry.
    /// - Other errors: Surfaced via `errorMessage`.
    func deleteAccount() async {
        guard let userId = currentUser?.id else {
            errorMessage = "No user logged in"
            return
        }
        
        let familyId = currentUser?.familyId   // Captured before deletion clears currentUser
        
        isLoading = true
        errorMessage = nil
        
        // AccountDeletionService performs all multi-step cleanup with error aggregation
        let result = await AccountDeletionService.shared.deleteAccount(
            userId: userId,
            familyId: familyId
        )
        
        isLoading = false
        
        if result.success {
            // Auth listener fires after Firebase Auth deletion → state reset automatically
            if !result.warnings.isEmpty {
                // Non-fatal cleanup failures (e.g., orphaned Storage files)
                print("Account deleted with warnings: \(result.warnings)")
            }
        } else if result.requiresReauthentication {
            // Firebase token too old — prompt user to re-verify identity
            needsReauthentication = true
            errorMessage = result.error
        } else {
            errorMessage = result.error
        }
    }
    
    // MARK: - ========================
    // MARK: - FAMILY MANAGEMENT
    // MARK: - ========================
    
    /// Creates a new family unit and assigns the current user as its admin.
    ///
    /// Delegates to `FamilyManagementService`. On success, updates `currentUser`
    /// and `hasFamily` to route the user into the main app experience.
    ///
    /// - Parameter name: The display name for the new family (e.g., "The Johnsons").
    func createFamily(name: String) async {
        guard let user = currentUser else { return }
        
        await withLoading {
            let result = await FamilyManagementService.shared.createFamily(name: name, user: user)
            
            if result.success, let updatedUser = result.updatedUser {
                currentUser = updatedUser   // Contains new familyId
                hasFamily = true            // Routes user to main app
            } else {
                errorMessage = result.error
            }
        }
    }
    
    /// Joins an existing family using a shared invite code.
    ///
    /// Invite codes are generated in `InviteCodeSheet` and stored on the
    /// Family Firestore document. The service validates the code and updates
    /// the user's `familyId` if valid.
    ///
    /// - Parameter inviteCode: The alphanumeric invite code displayed to the family creator.
    func joinFamily(inviteCode: String) async {
        guard let user = currentUser else { return }
        
        await withLoading {
            let result = await FamilyManagementService.shared.joinFamily(inviteCode: inviteCode, user: user)
            
            if result.success, let updatedUser = result.updatedUser {
                currentUser = updatedUser   // Contains joined familyId
                hasFamily = true
            } else {
                errorMessage = result.error
            }
        }
    }
    
    /// Updates the current user's reward wallet balance by a delta amount.
    ///
    /// Used when a task reward is earned or a reward is redeemed from the wallet.
    /// Delegates the Firestore write to `FamilyManagementService`.
    ///
    /// - Parameter amount: Positive to add funds, negative to deduct.
    func updateUserBalance(amount: Double) async {
        guard let user = currentUser else { return }
        
        if let updatedUser = await FamilyManagementService.shared.updateUserBalance(user: user, amount: amount) {
            currentUser = updatedUser
        } else {
            errorMessage = "Failed to update balance"
        }
    }
    
    /// Marks the current user's onboarding flow as completed.
    ///
    /// Sets `hasCompletedOnboarding = true` on both the Firestore document and
    /// the local `currentUser` copy. The app's root routing logic reads this
    /// flag to determine whether to show the onboarding flow or the main UI.
    func completeOnboarding() async {
        guard let userId = currentUser?.id else { return }
        
        if await FamilyManagementService.shared.completeOnboarding(userId: userId) {
            currentUser?.hasCompletedOnboarding = true
        }
    }
    
    /// Resets onboarding state for testing and QA purposes.
    ///
    /// - Warning: Development/debug only. Should not be callable from production UI.
    func resetOnboarding() async {
        guard let userId = currentUser?.id else { return }
        
        if await FamilyManagementService.shared.resetOnboarding(userId: userId) {
            currentUser?.hasCompletedOnboarding = false
        }
    }
    
    // MARK: - ========================
    // MARK: - ERROR HANDLING
    // MARK: - ========================
    
    /// Maps Firebase Auth error codes to user-friendly, actionable messages.
    ///
    /// Firebase errors use `NSError` codes from `AuthErrorCode`. The default
    /// `error.localizedDescription` is often too technical for end users (e.g.,
    /// "The password is invalid or the user does not have a password").
    ///
    /// - Parameter error: The raw error from a Firebase Auth operation.
    ///
    /// - Note: The `default` case falls through to `localizedDescription` as a
    ///   safety net for undocumented or future Firebase error codes.
    private func handleAuthError(_ error: Error) {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            errorMessage = "This email is already registered. Please sign in instead."
        case AuthErrorCode.invalidEmail.rawValue:
            errorMessage = "Please enter a valid email address."
        case AuthErrorCode.weakPassword.rawValue:
            errorMessage = "Password must be at least 6 characters."
        case AuthErrorCode.wrongPassword.rawValue:
            errorMessage = "Incorrect password. Please try again."
        case AuthErrorCode.userNotFound.rawValue:
            errorMessage = "No account found with this email."
        case AuthErrorCode.networkError.rawValue:
            errorMessage = "Network error. Please check your connection."
        case AuthErrorCode.tooManyRequests.rawValue:
            errorMessage = "Too many attempts. Please try again later."
        default:
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - ========================
    // MARK: - UTILITIES
    // MARK: - ========================
    
    /// Returns the root view controller suitable for presenting OAuth sheets.
    ///
    /// Google Sign-In and ASAuthorizationController require a `UIViewController`
    /// to present their native UI. This traverses the UIWindowScene hierarchy to
    /// find the topmost presented controller, which ensures OAuth sheets are
    /// presented over any modals already on screen.
    ///
    /// - Returns: The frontmost `UIViewController`, or `nil` if the window hierarchy
    ///   is unavailable (e.g., during unit tests or app backgrounding).
    private static func getPresentingViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        // Prefer the presented controller (handles full-screen modals)
        return rootViewController.presentedViewController ?? rootViewController
    }
}

// MARK: - Improvements & Code Quality Notes
//
// SUGGESTION 1 — signUp race condition:
//   `currentUser = newUser` is set optimistically, but if the Firestore write fails,
//   `currentUser` will be set to a user that was never persisted. Consider only
//   setting `currentUser` after the Firestore write succeeds, or roll back on failure.
//
// SUGGESTION 2 — deleteAll() batching in deleteAccount():
//   AccountDeletionService should use Firestore batch writes for multi-document
//   deletes to reduce network round-trips and ensure atomicity.
//
// SUGGESTION 3 — Magic string "users":
//   The Firestore collection name "users" appears in multiple files. Consider
//   extracting to a `FirestoreCollections` constants enum to prevent typos.
//
// SUGGESTION 4 — resetOnboarding() is a debug function exposed publicly:
//   Gate this behind `#if DEBUG` to prevent it from being callable in production.
//
// SUGGESTION 5 — markAllAsRead() in NotificationViewModel doesn't use batch writes:
//   Individual Firestore writes in a loop should be replaced with a Firestore
//   WriteBatch for atomicity and performance (see NotificationViewModel).

