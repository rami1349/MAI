//
//  PaletteKey.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//  ThemeEnvironment - Lightweight, SwiftUI-native theme solution
//  Uses Environment for color scheme and custom EnvironmentKey for palette
//
//  NO view rebuilds - colors resolve dynamically via environment


import SwiftUI

// MARK: - Palette Environment Key
private struct PaletteKey: EnvironmentKey {
    static let defaultValue: ColorPalette = AppTheme.cremeMatcha.palette
}

extension EnvironmentValues {
    var palette: ColorPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Theme Modifier
/// Injects theme into environment - colors resolve dynamically, no rebuilds
struct ThemeModifier: ViewModifier {
    @ObservedObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
        // Appearance mode: SwiftUI handles this natively
            .environment(\.colorScheme, themeManager.colorScheme ?? .light)
            .preferredColorScheme(themeManager.colorScheme)
        // Palette: inject into environment for reactive access
            .environment(\.palette, themeManager.palette)
        // Tint uses primary tone (brand/accent color)
            .tint(Color(hex: themeManager.palette.primary))
    }
}

extension View {
    /// Apply theme via environment - no view rebuilds on theme change
    func themed(_ themeManager: ThemeManager = .shared) -> some View {
        modifier(ThemeModifier(themeManager: themeManager))
    }
}

// MARK: - Environment-Aware Color Extensions
/// Colors that read from environment palette (reactive)
extension Color {
    
    /// Create color from environment palette
    static func themed(_ keyPath: KeyPath<ColorPalette, String>) -> ThemedColor {
        ThemedColor(keyPath: keyPath)
    }
}

/// A color view that reads from environment palette
struct ThemedColor: View {
    @Environment(\.palette) private var palette
    let keyPath: KeyPath<ColorPalette, String>
    
    var body: some View {
        Color(hex: palette[keyPath: keyPath])
    }
    
    /// Get the resolved color value
    var color: Color {
        Color(hex: palette[keyPath: keyPath])
    }
}

// MARK: - Palette-Aware View Modifier
/// For views that need palette colors in modifiers
struct PaletteReader<Content: View>: View {
    @Environment(\.palette) private var palette
    let content: (ColorPalette) -> Content
    
    init(@ViewBuilder content: @escaping (ColorPalette) -> Content) {
        self.content = content
    }
    
    var body: some View {
        content(palette)
    }
}

// MARK: - Convenience Modifiers
extension View {
    /// Background using palette color
    func paletteBackground(_ keyPath: KeyPath<ColorPalette, String>) -> some View {
        modifier(PaletteBackgroundModifier(keyPath: keyPath))
    }
    
    /// Foreground using palette color
    func paletteForeground(_ keyPath: KeyPath<ColorPalette, String>) -> some View {
        modifier(PaletteForegroundModifier(keyPath: keyPath))
    }
}

private struct PaletteBackgroundModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let keyPath: KeyPath<ColorPalette, String>
    
    func body(content: Content) -> some View {
        content.background(Color(hex: palette[keyPath: keyPath]))
    }
}

private struct PaletteForegroundModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let keyPath: KeyPath<ColorPalette, String>
    
    func body(content: Content) -> some View {
        content.foregroundColor(Color(hex: palette[keyPath: keyPath]))
    }
}
