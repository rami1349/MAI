//
//  DS.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.

//  Single source of truth — merged from DS + DS.
//  DS's 8pt grid · DS's Dynamic Type · Unified tokens.
//
//  Spacing scale (8pt grid): 4, 8, 12, 16, 20, 24, 32, 40, 48
//  Corner radius scale: 8, 12, 16, 20, 24, 9999 (pill)
//  Icon size scale: 12, 16, 20, 24, 32, 40, 48, 64
//  Elevation: 4 tiers (0–3) + accent
//

import SwiftUI

// MARK: - DS Namespace

/// All spacing values in the app. No magic numbers outside this enum.
///
/// Usage: `.padding(.horizontal, DS.Spacing.md)`
/// Usage: `VStack(spacing: DS.Spacing.sm)`
enum DS {
    
    // ─── Spacing (8pt grid) ──────────────────────────────────────
    
    enum Spacing {
        /// 4pt — tight inline spacing
        static let xxs: CGFloat = 4
        /// 8pt — inline spacing, icon gaps
        static let xs: CGFloat = 8
        /// 12pt — component internal spacing
        static let sm: CGFloat = 12
        /// 16pt — standard internal padding (cards, sections)
        static let md: CGFloat = 16
        /// 20pt — medium gaps
        static let lg: CGFloat = 20
        /// 24pt — between sections
        static let xl: CGFloat = 24
        /// 32pt — before new visual blocks
        static let xxl: CGFloat = 32
        /// 40pt — major section breaks
        static let xxxl: CGFloat = 40
        /// 48pt — hero / feature spacing
        static let jumbo: CGFloat = 48
        
        // MARK: Semantic Aliases
        
        /// Screen horizontal padding (= md, 16pt)
        static let screenH: CGFloat = md
        /// Card internal padding (= md, 16pt)
        static let cardPadding: CGFloat = md
        /// Gap between card child elements (= sm, 12pt)
        static let cardGap: CGFloat = sm
        /// Gap between sections (= xl, 24pt)
        static let sectionGap: CGFloat = xl
        /// Body text line spacing (= sm, 12pt)
        static let bodySpacing: CGFloat = sm
        /// Inline element spacing (= xs, 8pt)
        static let inline: CGFloat = xs
        /// Before new visual blocks (= xxl, 32pt)
        static let blockGap: CGFloat = xxl
        
        /// Adaptive screen padding — larger on iPad (delegates to Layout)
        static var adaptiveScreenH: CGFloat { Layout.adaptiveScreenPadding }
    }
    
    // ─── Layout (Content Width Constraints) ──────────────────────
    
    enum Layout {
        /// Max width for form content (auth screens, settings forms)
        static let formMaxWidth: CGFloat = 440
        /// Max width for card content (task cards, list items)
        static let cardMaxWidth: CGFloat = 600
        /// Max width for readable content (articles, long text)
        static let readableMaxWidth: CGFloat = 700
        /// Max width for dashboard/main content
        static let contentMaxWidth: CGFloat = 800
        /// Max width for wide content (grids, multi-column)
        static let wideMaxWidth: CGFloat = 1000
        
        static var isIPad: Bool {
            UIDevice.current.userInterfaceIdiom == .pad
        }
        
        static var shouldConstrainWidth: Bool { isIPad }
        
        /// Screen horizontal padding — larger on iPad
        static var adaptiveScreenPadding: CGFloat {
            isIPad ? 32 : Spacing.screenH
        }
    }
    
    // ─── Corner Radius ───────────────────────────────────────────
    
    enum Radius {
        /// 8pt — badges, chips, tags
        static let sm: CGFloat = 8
        /// 12pt — standard cards, inputs, controls
        static let md: CGFloat = 12
        /// 16pt — large cards, sections
        static let lg: CGFloat = 16
        /// 20pt — hero cards, feature sections
        static let xl: CGFloat = 20
        /// 24pt — modals, sheets, premium cards
        static let xxl: CGFloat = 24
        /// Pill / capsule (full-round)
        static let full: CGFloat = 9999
        
        // Semantic aliases
        static let badge: CGFloat = sm    // 8pt
        static let input: CGFloat = sm    // 8pt
        static let card: CGFloat = md     // 12pt
        static let button: CGFloat = md   // 12pt
        static let sheet: CGFloat = xl    // 20pt
    }
    
    // ─── Icon Sizes ──────────────────────────────────────────────
    
    enum IconSize {
        static let xs: CGFloat = 12   // Tiny indicator
        static let sm: CGFloat = 16   // Inline icon
        static let md: CGFloat = 20   // Default icon
        static let lg: CGFloat = 24   // Prominent icon
        static let xl: CGFloat = 32   // Feature icon
        static let xxl: CGFloat = 40  // Avatar small
        static let xxxl: CGFloat = 48 // Avatar medium
        static let jumbo: CGFloat = 64 // Avatar large
    }
    
    // ─── Icon Containers ─────────────────────────────────────────
    
    enum IconContainer {
        static let sm: CGFloat = 28  // Compact
        static let md: CGFloat = 36  // Standard
        static let lg: CGFloat = 44  // Large (meets tap target)
        static let xl: CGFloat = 56  // Extra large
    }
    
    // ─── Control Heights ─────────────────────────────────────────
    
    enum Control {
        static let compact: CGFloat = 36   // Badge, tag
        static let standard: CGFloat = 44  // Button, field (min tap target)
        static let large: CGFloat = 50     // Primary CTA
        static let fab: CGFloat = 56       // Floating action button
        static let minTapTarget: CGFloat = 44
    }
    
    // ─── Avatar Sizes ────────────────────────────────────────────
    
    enum Avatar {
        static let xs: CGFloat = 24  // Inline mention
        static let sm: CGFloat = 32  // Compact list row
        static let md: CGFloat = 40  // Standard list row
        static let lg: CGFloat = 56  // Profile card
        static let xl: CGFloat = 80  // Profile header
    }
    
    // ─── Typography (Dynamic Type) ───────────────────────────────
    
    /// Semantic typography roles. All Dynamic Type compatible.
    enum Typography {
        
        // Display (large, rare)
        static func displayLarge() -> Font { .largeTitle.weight(.bold) }
        static func displayMedium() -> Font { .title2.weight(.bold) }
        
        // Headings
        static func heading() -> Font { .headline }
        static func subheading() -> Font { .subheadline.weight(.semibold) }
        
        // Body
        static func body() -> Font { .subheadline }
        static func bodyMedium() -> Font { .subheadline.weight(.medium) }
        static func bodySmall() -> Font { .caption }
        
        // Labels
        static func label() -> Font { .subheadline.weight(.medium) }
        static func labelSmall() -> Font { .caption.weight(.medium) }
        static func badge() -> Font { .caption.weight(.medium) }
        
        // Captions & Metadata
        static func caption() -> Font { .caption }
        static func captionMedium() -> Font { .caption.weight(.medium) }
        static func micro() -> Font { .caption2 }
        
        // Numbers
        static func stat() -> Font { .title3.weight(.semibold) }
        static func statSmall() -> Font { .subheadline.weight(.semibold) }
    }
    
    // ─── Border Width ────────────────────────────────────────────
    
    enum Border {
        static let hairline: CGFloat = 0.5
        static let standard: CGFloat = 1
        static let emphasized: CGFloat = 2
        static let heavy: CGFloat = 3
    }
    
    // ─── Progress Bar ────────────────────────────────────────────
    
    enum ProgressBar {
        static let thin: CGFloat = 4
        static let standard: CGFloat = 6
        static let thick: CGFloat = 8
    }
    
    // ─── Timer/Focus Components ──────────────────────────────────
    
    enum Timer {
        static let ringPhone: CGFloat = 260
        static let ringPad: CGFloat = 200
        static let ringStroke: CGFloat = 14
        static let displayFont: CGFloat = 64
        static let displayFontCompact: CGFloat = 56
    }
    
    // ─── Empty State ─────────────────────────────────────────────
    
    enum EmptyState {
        static let icon: CGFloat = 48
        static let iconContainer: CGFloat = 80
    }
    
    // ─── Haptics ─────────────────────────────────────────────────
    
    enum Haptics {
        static func light()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        static func heavy()  { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
        static func soft()   { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        static func rigid()  { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
        
        static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        
        static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
        
        static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
        static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
            UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
        }
        static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
            UINotificationFeedbackGenerator().notificationOccurred(type)
        }
    }
    
    // ─── Shadow Definitions ──────────────────────────────────────
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        static let level0 = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        static let level1 = Shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        static let level2 = Shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        static let level3 = Shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 8)
        
        static func accent(_ color: Color) -> Shadow {
            Shadow(color: color.opacity(0.25), radius: 12, x: 0, y: 4)
        }
    }
    
    // ─── Animation Curves ────────────────────────────────────────
    
    enum Animation {
        /// 0.15s ease-out — micro interaction (tap, selection)
        static let micro = SwiftUI.Animation.easeOut(duration: 0.15)
        /// 0.25s ease-in-out — standard transition
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        /// Spring — smooth UI elements
        static let smooth = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
        /// Spring — bouncy / playful
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
        /// Spring — gentle / subtle
        static let gentle = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.9)
    }
}

// MARK: - Elevation (Shadow System)

extension View {
    
    /// Level 0 — flat, no shadow
    func elevation0() -> some View { self }
    
    /// Level 1 — subtle lift (section containers)
    func elevation1() -> some View {
        self.shadow(color: DS.Shadow.level1.color, radius: DS.Shadow.level1.radius,
                    x: DS.Shadow.level1.x, y: DS.Shadow.level1.y)
    }
    
    /// Level 2 — medium depth (cards, interactive)
    func elevation2() -> some View {
        self.shadow(color: DS.Shadow.level2.color, radius: DS.Shadow.level2.radius,
                    x: DS.Shadow.level2.x, y: DS.Shadow.level2.y)
    }
    
    /// Level 3 — high depth (floating, modals)
    func elevation3() -> some View {
        self.shadow(color: DS.Shadow.level3.color, radius: DS.Shadow.level3.radius,
                    x: DS.Shadow.level3.x, y: DS.Shadow.level3.y)
    }
    
    /// Accent glow (primary buttons)
    func elevationAccent(_ color: Color = Color.accentPrimary) -> some View {
        let s = DS.Shadow.accent(color)
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - Card Modifiers

extension View {
    
    /// Standard card: cardPadding, md radius, themed bg + border
    func standardCard() -> some View {
        self
            .padding(DS.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
            )
    }
    
    /// Hero/feature card: lg padding, xl radius, themed bg + border
    func heroCard() -> some View {
        self
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
            )
    }
}

// MARK: - iPad Layout Modifiers

extension View {
    
    func constrainedWidth(_ style: ConstrainedWidthStyle = .form) -> some View {
        modifier(ConstrainedWidthModifier(maxWidth: style.maxWidth))
    }
    
    func constrainedWidth(maxWidth: CGFloat) -> some View {
        modifier(ConstrainedWidthModifier(maxWidth: maxWidth))
    }
    
    func adaptiveScreenPadding() -> some View {
        self.padding(.horizontal, DS.Layout.adaptiveScreenPadding)
    }
    
    func formLayout() -> some View {
        self.constrainedWidth(.form).adaptiveScreenPadding()
    }
    
    func contentLayout() -> some View {
        self.constrainedWidth(.content).adaptiveScreenPadding()
    }
}

enum ConstrainedWidthStyle {
    case form, card, readable, content, wide
    
    var maxWidth: CGFloat {
        switch self {
        case .form: return DS.Layout.formMaxWidth
        case .card: return DS.Layout.cardMaxWidth
        case .readable: return DS.Layout.readableMaxWidth
        case .content: return DS.Layout.contentMaxWidth
        case .wide: return DS.Layout.wideMaxWidth
        }
    }
}

struct ConstrainedWidthModifier: ViewModifier {
    let maxWidth: CGFloat
    func body(content: Content) -> some View {
        if DS.Layout.shouldConstrainWidth {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                content.frame(maxWidth: maxWidth)
                Spacer(minLength: 0)
            }
        } else { content }
    }
}

struct ConstrainedContainer<Content: View>: View {
    let style: ConstrainedWidthStyle
    let content: Content
    
    init(style: ConstrainedWidthStyle = .form, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        if DS.Layout.shouldConstrainWidth {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                content.frame(maxWidth: style.maxWidth)
                Spacer(minLength: 0)
            }
        } else { content }
    }
}

// MARK: - Icon Container

/// Rounded-rect icon container with tinted background.
struct IconBox: View {
    let icon: String
    var color: Color = Color.accentPrimary
    var size: CGFloat = DS.IconContainer.md
    var iconSize: CGFloat = DS.IconSize.sm
    var cornerRadius: CGFloat = DS.Radius.sm
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color.opacity(0.10))
            )
    }
}

// MARK: - Theme Colors (from DS)
//
// themeCardBorder and themeHighlight are defined in Theme.swift.
// The four below are the DS-originated additions.

extension Color {
    
    /// Section background — slightly elevated from app background
    static var themeSectionBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.04)
                : UIColor.white.withAlphaComponent(0.7)
        })
    }
    
    /// Overlay scrim for modals/sheets
    static var themeScrim: Color {
        Color.black.opacity(0.25)
    }
    
    /// Soft divider colour
    static var themeDivider: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
                : UIColor.black.withAlphaComponent(0.06)
        })
    }
    
    /// Subtle metadata text colour
    static var themeTextMuted: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.5)
                : UIColor.black.withAlphaComponent(0.45)
        })
    }
}

// MARK: - Theme Divider

struct ThemeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.themeDivider)
            .frame(height: 1)
    }
}

// MARK: - Theme Gradients
//
// primaryGradient is defined in Theme.swift.
// The two below are the DS-originated additions.

extension LinearGradient {
    
    /// Subtle surface gradient for backgrounds
    static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [Color.themeSurfacePrimary, Color.themeSurfaceSecondary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Glass-like gradient overlay
    static var glassOverlay: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.15),
                Color.white.opacity(0.05),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview

#Preview("Design Tokens") {
    ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            
            Text("Spacing (8pt grid)")
                .font(DS.Typography.displayMedium())
            
            Group {
                spacingSwatch("xxs (4)", DS.Spacing.xxs)
                spacingSwatch("xs (8)", DS.Spacing.xs)
                spacingSwatch("sm (12)", DS.Spacing.sm)
                spacingSwatch("md (16)", DS.Spacing.md)
                spacingSwatch("lg (20)", DS.Spacing.lg)
                spacingSwatch("xl (24)", DS.Spacing.xl)
                spacingSwatch("xxl (32)", DS.Spacing.xxl)
                spacingSwatch("xxxl (40)", DS.Spacing.xxxl)
                spacingSwatch("jumbo (48)", DS.Spacing.jumbo)
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Corner Radius")
                .font(DS.Typography.displayMedium())
            
            HStack(spacing: 12) {
                radiusSwatch("sm\n8", DS.Radius.sm)
                radiusSwatch("md\n12", DS.Radius.md)
                radiusSwatch("lg\n16", DS.Radius.lg)
                radiusSwatch("xl\n20", DS.Radius.xl)
                radiusSwatch("xxl\n24", DS.Radius.xxl)
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Icon Containers")
                .font(DS.Typography.displayMedium())
            
            HStack(spacing: 16) {
                IconBox(icon: "star.fill", size: DS.IconContainer.sm, iconSize: DS.IconSize.xs)
                IconBox(icon: "calendar", size: DS.IconContainer.md, iconSize: DS.IconSize.sm)
                IconBox(icon: "house.fill", size: DS.IconContainer.lg, iconSize: DS.IconSize.md)
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Typography")
                .font(DS.Typography.displayMedium())
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Large").font(DS.Typography.displayLarge())
                Text("Display Medium").font(DS.Typography.displayMedium())
                Text("Heading").font(DS.Typography.heading())
                Text("Subheading").font(DS.Typography.subheading())
                Text("Body").font(DS.Typography.body())
                Text("Body Medium").font(DS.Typography.bodyMedium())
                Text("Body Small").font(DS.Typography.bodySmall())
                Text("Label").font(DS.Typography.label())
                Text("Caption").font(DS.Typography.caption())
                Text("Micro").font(DS.Typography.micro())
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Elevation")
                .font(DS.Typography.displayMedium())
            
            VStack(spacing: 16) {
                elevationSample("Level 0 — flat", 0)
                elevationSample("Level 1 — cards", 1)
                elevationSample("Level 2 — floating", 2)
                elevationSample("Level 3 — modal", 3)
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Cards")
                .font(DS.Typography.displayMedium())
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Standard Card Title")
                    .font(DS.Typography.subheading())
                Text("16pt padding, 12pt radius, themed background.")
                    .font(DS.Typography.body())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .standardCard()
            
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Hero Card Title")
                    .font(DS.Typography.heading())
                Text("20pt padding, 20pt radius, for feature/summary cards.")
                    .font(DS.Typography.body())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCard()
        }
        .padding(DS.Spacing.screenH)
    }
    .background(Color.themeSurfacePrimary)
}

// Preview helpers
private func spacingSwatch(_ label: String, _ size: CGFloat) -> some View {
    HStack(spacing: 8) {
        Text(label)
            .font(.caption.monospaced())
            .frame(width: 100, alignment: .leading)
        Rectangle()
            .fill(Color.accentPrimary)
            .frame(width: size, height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

private func radiusSwatch(_ label: String, _ radius: CGFloat) -> some View {
    VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.accentPrimary.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.accentPrimary, lineWidth: 1))
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

@ViewBuilder
private func elevationSample(_ label: String, _ level: Int) -> some View {
    let base = Text(label)
        .font(.caption)
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(Color.themeCardBackground))
    
    switch level {
    case 0: base.elevation0()
    case 1: base.elevation1()
    case 2: base.elevation2()
    case 3: base.elevation3()
    default: base
    }
}
