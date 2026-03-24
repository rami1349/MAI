//
//  Theme.swift
//  
//
//  REWRITTEN: Simplified 4-color palette system
//  Each theme has: Primary, Accent, Surface, Card
//  Plus system neutrals for text/separators
//
//  Color palettes: Matcha Linen, Oyster Silk, Rose Clay
//  NO LOGIC CHANGES - Only color values updated
//


import SwiftUI

// MARK: - Theme Manager
@Observable
class ThemeManager {
    static let shared = ThemeManager()
    
    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.cremeMatcha.rawValue
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .cremeMatcha
        
        let savedAppearance = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: savedAppearance) ?? .system
        
        applyAppearance()
    }
    
    private func applyAppearance() {
        Task { @MainActor in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            switch self.appearanceMode {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
    
    var palette: ColorPalette {
        currentTheme.palette
    }
    
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Simplified 4-Color Palette
struct ColorPalette {
    // Core 4 colors
    let primary: String      // Buttons, CTAs, active states
    let accent: String       // Secondary actions, highlights, badges
    let surface: String      // Main background
    let card: String         // Elevated surfaces (cards, sheets, modals)
    
    // Dark mode variants
    let primaryDark: String
    let accentDark: String
    let surfaceDark: String
    let cardDark: String
}

// MARK: - App Themes (3 Distinctive Palettes)
enum AppTheme: String, CaseIterable, Identifiable {
    case cremeMatcha = "cremeMatcha"
    case oysterGlow = "oysterGlow"
    case rustRoseQuartz = "rustRoseQuartz"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cremeMatcha: return "Matcha Linen"
        case .oysterGlow: return "Oyster Silk"
        case .rustRoseQuartz: return "Rose Clay"
        }
    }
    
    var palette: ColorPalette {
        switch self {
        case .cremeMatcha:
            // MATCHA LINEN - Soft sage with warm linen undertones
            // Calm, natural, organic - reduces anxiety
            return ColorPalette(
                primary: "92A378",        // Sage green - buttons, CTAs
                accent: "C3CAB2",         // Muted sage (Primary Soft)
                surface: "FBF9F6",        // Warm linen cream background
                card: "F5F3EC",           // Elevated cream cards
                // Dark mode
                primaryDark: "A8B88E",    // Lighter sage for dark mode
                accentDark: "8A9A72",     // Deeper sage accent
                surfaceDark: "1A1D16",    // Deep forest background
                cardDark: "252820"        // Forest card
            )
            
        case .oysterGlow:
            // OYSTER SILK - Warm neutral elegance
            // Minimal, timeless, sophisticated
            return ColorPalette(
                primary: "B0A89F",        // Oyster/taupe - buttons, CTAs
                accent: "DDD0C8",         // Soft taupe (Primary Soft)
                surface: "F0EBE5",        // Warm oyster background
                card: "F6F3EF",           // Silk cream cards
                // Dark mode
                primaryDark: "C8C0B7",    // Light oyster for dark mode
                accentDark: "9A9288",     // Medium taupe accent
                surfaceDark: "1C1A17",    // Deep charcoal background
                cardDark: "28261F"        // Charcoal card
            )
            
        case .rustRoseQuartz:
            // ROSE CLAY - Warm terracotta with rose undertones
            // Earthy, warm, grounding
            return ColorPalette(
                primary: "C9877B",        // Rose clay - buttons, CTAs
                accent: "E7C6BE",         // Soft rose (Primary Soft)
                surface: "FEF3F0",        // Soft rose background
                card: "FCEDE9",           // Blush cream cards
                // Dark mode
                primaryDark: "D4A095",    // Light rose clay for dark mode
                accentDark: "B08A7E",     // Deep terracotta accent
                surfaceDark: "1E1816",    // Deep brown background
                cardDark: "2C2421"        // Brown card
            )
        }
    }
    
    // Preview colors for theme picker (shows the 4 colors)
    var previewColors: [Color] {
        [
            Color(hex: palette.primary),
            Color(hex: palette.accent),
            Color(hex: palette.surface),
            Color(hex: palette.card)
        ]
    }
}

// MARK: - System Neutrals (Pure grays - don't change with theme)
// UPDATED: Softer, warmer neutrals for premium feel
struct SystemNeutrals {
    struct Light {
        static let textPrimary = Color(hex: "2C2C2E")      // Slightly softer black
        static let textSecondary = Color(hex: "6E6E73")    // iOS system gray
        static let textTertiary = Color(hex: "AEAEB2")     // Muted gray
        static let separator = Color(hex: "E8E8ED")        // Soft divider
        static let fill = Color(hex: "F5F5F7")             // Apple-style fill
        static let fillSecondary = Color(hex: "EBEBF0")    // Secondary fill
    }
    
    struct Dark {
        static let textPrimary = Color(hex: "F5F5F7")      // Soft white (not pure)
        static let textSecondary = Color(hex: "98989D")    // Medium gray
        static let textTertiary = Color(hex: "636366")     // Muted gray
        static let separator = Color(hex: "38383A")        // Dark divider
        static let fill = Color(hex: "2C2C2E")             // Dark fill
        static let fillSecondary = Color(hex: "38383A")    // Secondary fill
    }
}

// MARK: - Semantic Colors (Status colors - consistent across themes)
struct SemanticColors {
    // Success - Softer green
    static let success = Color(hex: "34C759")
    static let successLight = Color(hex: "E8F8ED")
    
    // Warning - Warm amber
    static let warning = Color(hex: "FF9500")
    static let warningLight = Color(hex: "FFF4E5")
    
    // Error - Softer red
    static let error = Color(hex: "FF3B30")
    static let errorLight = Color(hex: "FFEBEA")
    
    // Info - Calm blue
    static let info = Color(hex: "007AFF")
    static let infoLight = Color(hex: "E5F1FF")
}

// MARK: - Color Extensions (Dynamic Theme Colors)
extension Color {
    
    // MARK: - Primary Colors (from current theme)
    static var accentPrimary: Color {
        Color(UIColor { traits in
            let palette = ThemeManager.shared.palette
            return traits.userInterfaceStyle == .dark
            ? UIColor(Color(hex: palette.primaryDark))
            : UIColor(Color(hex: palette.primary))
        })
    }
    
    static var accentSecondary: Color {
        Color(UIColor { traits in
            let palette = ThemeManager.shared.palette
            return traits.userInterfaceStyle == .dark
            ? UIColor(Color(hex: palette.accentDark))
            : UIColor(Color(hex: palette.accent))
        })
    }
    
    // Alias for compatibility
    static var accentTertiary: Color { accentSecondary }
    
    // MARK: - Surface Colors (from current theme)
    static var themeSurfacePrimary: Color {
        Color(UIColor { traits in
            let palette = ThemeManager.shared.palette
            return traits.userInterfaceStyle == .dark
            ? UIColor(Color(hex: palette.surfaceDark))
            : UIColor(Color(hex: palette.surface))
        })
    }
    
    static var themeSurfaceSecondary: Color {
        // Slightly darker/lighter than primary surface for subtle layering
        Color(UIColor { traits in
            let palette = ThemeManager.shared.palette
            if traits.userInterfaceStyle == .dark {
                return UIColor(Color(hex: palette.cardDark))
            } else {
                // Use a slightly tinted version of surface
                return UIColor(Color(hex: palette.surface)).withAlphaComponent(0.7)
                    .blended(withFraction: 0.3, of: UIColor(Color(hex: palette.accent)))!
            }
        })
    }
    
    // MARK: - Card Colors (from current theme)
    static var themeCardBackground: Color {
        Color(UIColor { traits in
            let palette = ThemeManager.shared.palette
            return traits.userInterfaceStyle == .dark
            ? UIColor(Color(hex: palette.cardDark))
            : UIColor(Color(hex: palette.card))
        })
    }
    
    // themeCardBorder and themeHighlight → moved to DS.swift
    
    // MARK: - Semantic Status Colors
    static var statusSuccess: Color { SemanticColors.success }
    static var statusWarning: Color { SemanticColors.warning }
    static var statusError: Color { SemanticColors.error }
    static var statusInfo: Color { SemanticColors.info }
    
    static var accentGreen: Color { SemanticColors.success }
    static var accentYellow: Color { SemanticColors.warning }
    static var accentOrange: Color { Color(hex: "F97316") }
    static var accentRed: Color { SemanticColors.error }
    static var accentBlue: Color { SemanticColors.info }
    
    // Task status colors
    static var statusTodo: Color { Color(hex: "8E8E93") }
    static var statusInProgress: Color { SemanticColors.info }
    static var statusPending: Color { SemanticColors.warning }
    static var statusCompleted: Color { SemanticColors.success }
    
    // MARK: - Legacy Aliases (for backward compatibility)
    static var backgroundPrimary: Color { themeSurfacePrimary }
    static var backgroundSecondary: Color { themeSurfaceSecondary }
    static var backgroundCard: Color { themeCardBackground }
    static var surfaceElevated: Color { themeCardBackground }
    static var backgroundCardElevated: Color { themeCardBackground }
    static var surfaceColor: Color { fill }
    
    // MARK: - Text Colors (Pure Neutrals - cached for performance)
    private static let _textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(SystemNeutrals.Dark.textPrimary)
        : UIColor(SystemNeutrals.Light.textPrimary)
    })
    static var textPrimary: Color { _textPrimary }
    
    private static let _textSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(SystemNeutrals.Dark.textSecondary)
        : UIColor(SystemNeutrals.Light.textSecondary)
    })
    static var textSecondary: Color { _textSecondary }
    
    private static let _textTertiary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(SystemNeutrals.Dark.textTertiary)
        : UIColor(SystemNeutrals.Light.textTertiary)
    })
    static var textTertiary: Color { _textTertiary }
    
    static var textOnAccent: Color { .white }
    
    // MARK: - Fill Colors (Pure Neutrals - cached)
    private static let _fill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(SystemNeutrals.Dark.fill)
        : UIColor(SystemNeutrals.Light.fill)
    })
    static var fill: Color { _fill }
    
    private static let _fillSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(SystemNeutrals.Dark.fillSecondary)
        : UIColor(SystemNeutrals.Light.fillSecondary)
    })
    static var fillSecondary: Color { _fillSecondary }
    
    // MARK: - Separator Colors (Pure Neutrals - cached)
    private static let _separator = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(SystemNeutrals.Dark.separator)
        : UIColor(SystemNeutrals.Light.separator)
    })
    static var separator: Color { _separator }
    
    static var dividerColor: Color { separator }
    
    // Legacy alias
    static var themeAccent: Color { accentSecondary }
    
    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - ShapeStyle Convenience (enables .textPrimary instead of Color.textPrimary)
//
// Swift's .foregroundStyle() accepts any ShapeStyle. By extending ShapeStyle
// with static properties that return Color, we can write:
//     .foregroundStyle(.textPrimary)
// instead of:
//     .foregroundStyle(.textPrimary)
//
// This also works with .tint(), .background(), .overlay(), etc.

extension ShapeStyle where Self == Color {
    
    // MARK: Text
    static var textPrimary: Color { Color.textPrimary }
    static var textSecondary: Color { Color.textSecondary }
    static var textTertiary: Color { Color.textTertiary }
    static var textOnAccent: Color { Color.textOnAccent }
    
    // MARK: Accent
    static var accentPrimary: Color { Color.accentPrimary }
    static var accentSecondary: Color { Color.accentSecondary }
    static var accentTertiary: Color { Color.accentTertiary }
    
    // MARK: Accent Colors
    static var accentGreen: Color { Color.accentGreen }
    static var accentYellow: Color { Color.accentYellow }
    static var accentOrange: Color { Color.accentOrange }
    static var accentRed: Color { Color.accentRed }
    static var accentBlue: Color { Color.accentBlue }
    
    // MARK: Status
    static var statusSuccess: Color { Color.statusSuccess }
    static var statusWarning: Color { Color.statusWarning }
    static var statusError: Color { Color.statusError }
    static var statusInfo: Color { Color.statusInfo }
    static var statusTodo: Color { Color.statusTodo }
    static var statusInProgress: Color { Color.statusInProgress }
    static var statusPending: Color { Color.statusPending }
    static var statusCompleted: Color { Color.statusCompleted }
    
    // MARK: Surfaces
    static var themeSurfacePrimary: Color { Color.themeSurfacePrimary }
    static var themeSurfaceSecondary: Color { Color.themeSurfaceSecondary }
    static var themeCardBackground: Color { Color.themeCardBackground }
    static var backgroundPrimary: Color { Color.backgroundPrimary }
    static var backgroundSecondary: Color { Color.backgroundSecondary }
    static var backgroundCard: Color { Color.backgroundCard }
    static var surfaceElevated: Color { Color.surfaceElevated }
    static var surfaceColor: Color { Color.surfaceColor }
    
    // MARK: Borders & Dividers
    static var dividerColor: Color { Color.dividerColor }
    
    // MARK: Fill
    static var fill: Color { Color.fill }
    static var fillSecondary: Color { Color.fillSecondary }
}
extension UIColor {
    func blended(withFraction fraction: CGFloat, of color: UIColor) -> UIColor? {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        guard self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return nil
        }
        
        return UIColor(
            red: r1 + fraction * (r2 - r1),
            green: g1 + fraction * (g2 - g1),
            blue: b1 + fraction * (b2 - b1),
            alpha: a1 + fraction * (a2 - a1)
        )
    }
}

// primaryGradient, backgroundGradient, surfaceGradient, glassOverlay → moved to DS.swift

// MARK: - Adaptive Background View
struct AdaptiveBackgroundView: View {
    var body: some View {
        Color.themeSurfacePrimary
            .ignoresSafeArea()
    }
}

// MARK: - View Extensions
extension View {
    func adaptiveBackground() -> some View {
        self.background(Color.themeSurfacePrimary.ignoresSafeArea())
    }
    
    /// Deprecated: Use `.standardCard()` or `.heroCard()` from DesignTokens instead.
    @available(*, deprecated, message: "Use .standardCard() or .heroCard() instead")
    func themedCardBackground() -> some View {
        self.standardCard()
    }
}

// MARK: - Shadows (Deprecated → use DS elevation system)
extension View {
    /// Deprecated: Use `.elevation1()` from DesignTokens instead.
    @available(*, deprecated, message: "Use .elevation1() instead")
    func cardShadow() -> some View {
        self.elevation1()
    }
    
    /// Deprecated: Use `.elevation2()` from DesignTokens instead.
    @available(*, deprecated, message: "Use .elevation2() instead")
    func softShadow() -> some View {
        self.elevation2()
    }
    
    /// Deprecated: Use `.elevationAccent()` from DesignTokens instead.
    @available(*, deprecated, message: "Use .elevationAccent() instead")
    func buttonShadow() -> some View {
        self.elevationAccent()
    }
}

// MARK: - Task Group Colors & Icons
struct TaskGroupColors {
    static let colors: [(name: String, hex: String)] = [
        ("Purple", "5C4F6E"),
        ("Green", "92A378"),
        ("Taupe", "9A918A"),
        ("Terracotta", "A15C48"),
        ("Blue", "3B82F6"),
        ("Pink", "EC4899"),
        ("Red", "EF4444"),
        ("Indigo", "6366F1"),
        ("Teal", "14B8A6"),
        ("Orange", "F97316")
    ]
    
    static let icons: [(name: String, systemName: String)] = [
        ("Briefcase", "briefcase.fill"),
        ("Person", "person.fill"),
        ("Book", "book.fill"),
        ("House", "house.fill"),
        ("Cart", "cart.fill"),
        ("Heart", "heart.fill"),
        ("Star", "star.fill"),
        ("Gift", "gift.fill"),
        ("Gamecontroller", "gamecontroller.fill"),
        ("Music", "music.note"),
        ("Camera", "camera.fill"),
        ("Plane", "airplane"),
        ("Car", "car.fill"),
        ("Leaf", "leaf.fill"),
        ("Dumbbell", "dumbbell.fill")
    ]
}

// MARK: - Habit Colors (Soft, desaturated)
struct HabitColors {
    static let colors: [(name: String, hex: String)] = [
        ("Lavender", "8B7BA3"),
        ("Sage", "92A378"),
        ("Sand", "B0A89F"),
        ("Rose", "C4897A"),
        ("Sky", "7EB8C8"),
        ("Peach", "C8A87E"),
        ("Slate", "8B9EC8"),
        ("Coral", "C89E8B"),
        ("Mint", "8BC8B8"),
        ("Mauve", "B88BC8")
    ]
    
    static let icons: [(name: String, icon: String)] = [
        ("Star", "star.fill"),
        ("Heart", "heart.fill"),
        ("Book", "book.fill"),
        ("Drop", "drop.fill"),
        ("Flame", "flame.fill"),
        ("Moon", "moon.fill"),
        ("Sun", "sun.max.fill"),
        ("Leaf", "leaf.fill"),
        ("Figure", "figure.walk"),
        ("Brain", "brain.head.profile"),
        ("Bed", "bed.double.fill"),
        ("Cup", "cup.and.saucer.fill"),
        ("Music", "music.note"),
        ("Pencil", "pencil"),
        ("Dumbbell", "dumbbell.fill")
    ]
}

// MARK: - Preview
#Preview("Theme Colors") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(AppTheme.allCases) { theme in
                VStack(alignment: .leading, spacing: 12) {
                    Text(theme.displayName)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            let colors = [
                                theme.palette.primary,
                                theme.palette.accent,
                                theme.palette.surface,
                                theme.palette.card
                            ]
                            let labels = ["Primary", "Accent", "Surface", "Card"]
                            
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: colors[index]))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                                
                                Text(labels[index])
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(hex: theme.palette.surface))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            }
        }
        .padding()
    }
}
