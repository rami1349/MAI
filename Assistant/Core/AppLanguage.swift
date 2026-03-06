
//  AppLanguage.swift
//  FamilyHub
//
//  Lightweight observable object for runtime language switching.
//
//  PURPOSE:
//  - Stores selected language code
//  - Exposes a Locale instance for SwiftUI environment injection
//  - Persists selection via UserDefaults
//
//  DOES NOT:
//  - Perform string translation (SwiftUI handles this via .environment(\.locale))
//  - Load bundles or lookup strings
//
//  USAGE:
//  1. Create @StateObject in App entry point
//  2. Inject via .environment(\.locale, appLanguage.locale)
//  3. Call appLanguage.setLanguage("es") to switch languages
//


import SwiftUI

// MARK: - Supported Languages

enum LanguageCode: String, CaseIterable, Identifiable {
    case system  = "system"
    case english = "en"
    case spanish = "es"
    case chinese = "zh-Hans"
    
    var id: String { rawValue }
    
    /// Display name shown in the language picker (in native language)
    var displayName: String {
        switch self {
        case .system:  return String(localized: "language.system")
        case .english: return "English"
        case .spanish: return "Español"
        case .chinese: return "中文"
        }
    }
    
    /// Locale identifier for SwiftUI environment
    var localeIdentifier: String {
        switch self {
        case .system:  return Locale.current.identifier
        case .english: return "en"
        case .spanish: return "es"
        case .chinese: return "zh-Hans"
        }
    }
}

// MARK: - App Language Manager

@Observable
@MainActor
final class AppLanguage {
    
    // MARK: - Singleton
    
    static let shared = AppLanguage()
    
    // MARK: - Storage Key
    
    @ObservationIgnored
    private let storageKey = "app_language_preference"
    
    // MARK: - Published State
    
    /// The user's selected language preference
    private(set) var selectedLanguage: LanguageCode
    
    /// The resolved locale for SwiftUI environment injection
    var locale: Locale {
        Locale(identifier: resolvedLocaleIdentifier)
    }
    
    // MARK: - Computed Properties
    
    /// The actual language code being used (resolves "system" to actual language)
    var resolvedLanguageCode: String {
        if selectedLanguage == .system {
            return Self.resolveSystemLanguage()
        }
        return selectedLanguage.rawValue
    }
    
    /// The locale identifier being used
    private var resolvedLocaleIdentifier: String {
        if selectedLanguage == .system {
            return Self.resolveSystemLanguage()
        }
        return selectedLanguage.localeIdentifier
    }
    
    /// Display name for current language (used in Settings)
    var displayName: String {
        if selectedLanguage == .system {
            // Show which language system resolves to
            let resolved = Self.resolveSystemLanguage()
            if let lang = LanguageCode(rawValue: resolved) {
                return "\(selectedLanguage.displayName) (\(lang.displayName))"
            }
        }
        return selectedLanguage.displayName
    }
    
    // MARK: - Init
    
    private init() {
        let savedValue = UserDefaults.standard.string(forKey: storageKey) ?? "system"
        self.selectedLanguage = LanguageCode(rawValue: savedValue) ?? .system
    }
    
    // MARK: - Public API
    
    /// Change the app language. UI updates automatically via SwiftUI environment.
    func setLanguage(_ language: LanguageCode) {
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
    }
    
    /// Change language using raw code string
    func setLanguage(code: String) {
        if let language = LanguageCode(rawValue: code) {
            setLanguage(language)
        }
    }
    
    // MARK: - System Language Resolution
    
    /// Resolves the system's preferred language to a supported language code
    private static func resolveSystemLanguage() -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        
        // Match supported languages
        if preferred.hasPrefix("es") { return "es" }
        if preferred.hasPrefix("zh") { return "zh-Hans" }
        
        // Default to English
        return "en"
    }
}

// MARK: - Environment Key (Alternative Injection)

/// Optional: Direct environment key for AppLanguage
/// Use if you prefer @Environment(\.appLanguage) over @Environment(AppLanguage.self)
private struct AppLanguageKey: EnvironmentKey {
    static var defaultValue: AppLanguage {
        MainActor.assumeIsolated { AppLanguage.shared }
    }
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
