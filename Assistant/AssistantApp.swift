//
//  AssistantApp.swift
//
//  v4: Added FeatureFlagService + CrashReporting + ListenerHealthMonitor
//
//  WHAT CHANGED (v3 → v4):
//    - FeatureFlagService.shared injected via .environment()
//    - Feature flags fetched on launch (non-blocking .task)
//    - CrashReporting.configure() in AppDelegate
//    - CrashReporting.setUser() on auth state changes
//    - ListenerHealthMonitor available in DEBUG builds
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseCrashlytics
import FirebaseFirestore
import UserNotifications
import GoogleSignIn

@main
struct AssistantApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // ViewModels - initialized after Firebase via init()
    @State private var authViewModel: AuthViewModel
    @State private var familyViewModel: FamilyViewModel
    @State private var store: SubscriptionManager
    
    // Navigation - centralized router
    @State private var router = NavigationRouter()
    
    // Keep observing ThemeManager for colorScheme reactivity at App level
    private var themeManager: ThemeManager { .shared }
    
    init() {
        // Configure Firebase BEFORE creating any ViewModels
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            
            // Configure Firestore settings
            let settings = FirestoreSettings()
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
            Firestore.firestore().settings = settings
        }
        
        // Now safe to create ViewModels that use Firebase
        _authViewModel = State(initialValue: AuthViewModel())
        _familyViewModel = State(initialValue: FamilyViewModel())
        _store = State(initialValue: SubscriptionManager())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .adaptiveLayout()
                // Navigation router
                .environment(router)
                // ViewModels
                .environment(authViewModel)
                .environment(familyViewModel)
                // PERF-5: Inject child VMs directly so views observe only what they need.
                .environment(familyViewModel.familyMemberVM)
                .environment(familyViewModel.taskVM)
                .environment(familyViewModel.calendarVM)
                .environment(familyViewModel.habitVM)
                .environment(familyViewModel.notificationVM)
                .environment(familyViewModel.rewardVM)
                // Store: @Observable injected via .environment()
                .environment(store)
                // Feature flags: kill switches for AI, monetization, etc.
                .environment(FeatureFlagService.shared)
                // DI: Injects ThemeManager, AppLanguage, TourManager
                .withLiveDependencies()
                // Locale: Drives all Text("key") resolution via Localizable.xcstrings
                .environment(\.locale, AppLanguage.shared.locale)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    Task {
                        await LocalNotificationService.shared.requestPermission()
                    }
                }
                .task {
                    // Fetch feature flags (non-blocking)
                    await FeatureFlagService.shared.fetchFlags()
                    // Load store products
                    await store.loadProducts()
                    await store.refreshEntitlementState()
                }
                // Set crash reporting + subscription context on auth changes
                .onChange(of: authViewModel.currentUser?.id) { _, newId in
                    if let user = authViewModel.currentUser, let id = newId {
                        // Crash reporting
                        CrashReporting.setUser(
                            id: id,
                            role: user.role.rawValue,
                            tier: user.subscription,
                            familySize: familyViewModel.familyMemberVM.familyMembers.count
                        )
                        CrashReporting.log("User signed in: role=\(user.role.rawValue)")
                        
                        // Subscription: load tier + credits from Firestore user doc
                        store.configure(userId: id, user: user)
                        
                        // Verify StoreKit entitlements match Firestore
                        Task { await store.refreshEntitlementState() }
                    } else {
                        CrashReporting.clearUser()
                        store.reset()
                    }
                }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Firebase is already configured in AssistantApp.init()
        
        // SA-2: Initialize crash reporting
        CrashReporting.configure()
        
        // Configure Google Sign-In with Firebase client ID
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        
        // Setup notification delegates
        UNUserNotificationCenter.current().delegate = LocalNotificationService.shared
        Messaging.messaging().delegate = LocalNotificationService.shared
        
        return true
    }
    
    // REQUIRED: Handle Google Sign-In URL callback
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CrashReporting.record(error, context: "AppDelegate.registerForRemoteNotifications")
    }
}
