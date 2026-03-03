//
//  AssistantApp.swift
//  FamilyHub
//
//  App entry point with Firebase configuration and environment setup
//  Uses DependencyInjection.swift for singleton management.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications
import GoogleSignIn

@main
struct AssistantApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authViewModel = AuthViewModel()
    @State private var familyViewModel = FamilyViewModel()
    
    // @Observable uses @State (not @StateObject)
    @State private var store = SubscriptionManager()
    
    // Keep observing ThemeManager for colorScheme reactivity at App level
    private var themeManager: ThemeManager { .shared }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .adaptiveLayout()
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
                // DI: Injects ThemeManager, LocalizationManager, TourManager + DependencyContainer
                .withLiveDependencies()
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    Task {
                        await LocalNotificationService.shared.requestPermission()
                    }
                }
                .task {
                    await store.loadProducts()
                    await store.refreshEntitlementState()
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
        // 1. Configure Firebase FIRST
        FirebaseApp.configure()
        
        // 2. Configure Google Sign-In with Firebase client ID
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        
        // 3. Enable Firestore offline persistence with increased cache size
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber) // 100 MB cache
        Firestore.firestore().settings = settings
        
        // 4. Setup notification delegates
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
        // Pass token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Error handled silently - Firebase will retry
    }
}
