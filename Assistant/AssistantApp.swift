//
//  AssistantApp.swift
//
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
    
    // ViewModels - initialized after Firebase via init()
    @State private var authViewModel: AuthViewModel
    @State private var familyViewModel: FamilyViewModel
    @State private var store: SubscriptionManager
    
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
                // DI: Injects ThemeManager, AppLanguage, TourManager + DependencyContainer
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
        // Firebase is already configured in AssistantApp.init()
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
