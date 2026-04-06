//
//  DesignTokens.swift
//
//
//  Single source of truth for all layout values.
//  Every padding, spacing, corner radius, icon size, and control height
//  should reference a token from this file Ã¢â‚¬â€ never a magic number.
//
//  Spacing scale (8pt grid): 4, 8, 12, 16, 20, 24, 32, 40, 48
//  Corner radius scale: 8, 12, 16, 20, 24, 9999 (pill)
//  Icon size scale: 12, 16, 20, 24, 32, 40, 48, 64
//  Elevation: 4 tiers (0-3) + accent
//

import SwiftUI

// MARK: - Spacing

/// All spacing values in the app. No magic numbers outside this enum.
///
/// Usage: `.padding(.horizontal, DS.Spacing.md)`
/// Usage: `VStack(spacing: DS.Spacing.sm)`
enum DS {
    
    // 8pt grid: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48
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
    
    // MARK: - Layout (Content Width Constraints)
    
    /// Content width constraints for different contexts.
    /// Use these to prevent UI from stretching too wide on iPad/Mac.
    enum Layout {
        /// Max width for form content (auth screens, settings forms)
        /// 440pt provides comfortable reading width similar to iPhone
        static let formMaxWidth: CGFloat = 440
        
        /// Max width for card content (task cards, list items)
        static let cardMaxWidth: CGFloat = 600
        
        /// Max width for readable content (articles, long text)
        static let readableMaxWidth: CGFloat = 700
        
        /// Max width for dashboard/main content
        static let contentMaxWidth: CGFloat = 800
        
        /// Max width for wide content (grids, multi-column)
        static let wideMaxWidth: CGFloat = 1000
        
        /// Check if current device is iPad
        static var isIPad: Bool {
            UIDevice.current.userInterfaceIdiom == .pad
        }
        
        /// Check if current device should use constrained width
        static var shouldConstrainWidth: Bool {
            isIPad
        }
        
        /// Screen horizontal padding - larger on iPad
        static var adaptiveScreenPadding: CGFloat {
            isIPad ? 32 : Spacing.screenH
        }
    }
    
    // MARK: - Corner Radius
    
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
        /// Badge/tag corner radius (8pt)
        static let badge: CGFloat = sm
        /// Input field corner radius (8pt)
        static let input: CGFloat = sm
        /// Standard card corner radius (12pt)
        static let card: CGFloat = md
        /// Button corner radius (12pt)
        static let button: CGFloat = md
        /// Modal/sheet corner radius (20pt)
        static let sheet: CGFloat = xl
    }
    
    // MARK: - Icon Sizes
    
    /// Constrained icon size scale. Pick the closest size, never freestyle.
    enum IconSize {
        /// 12pt  Tiny indicators (dot, caret inside badge)
        static let xs: CGFloat = 12
        /// 16pt Inline icons (inside text rows, badges)
        static let sm: CGFloat = 16
        /// 20pt  Default icon (nav bar, list row leading icon)
        static let md: CGFloat = 20
        /// 24pt  Prominent icon (info row icon, tab bar)
        static let lg: CGFloat = 24
        /// 32pt Feature icon (empty state, section header)
        static let xl: CGFloat = 32
        /// 40pt  Avatar small, card leading icon
        static let xxl: CGFloat = 40
        /// 48pt  Avatar medium, card hero icon
        static let xxxl: CGFloat = 48
        /// 64pt  Avatar large, profile display
        static let jumbo: CGFloat = 64
    }
    
    // MARK: - Icon Containers (background circle/rounded rect behind icon)
    
    enum IconContainer {
        /// 28pt Compact icon container (list rows, badges)
        static let sm: CGFloat = 28
        /// 36pt  Standard icon container (info rows, settings)
        static let md: CGFloat = 36
        /// 44pt  Large icon container (card leading, meets tap target)
        static let lg: CGFloat = 44
        /// 56pt — Extra large icon container (feature icons, chat avatars)
        static let xl: CGFloat = 56
    }
    
    // MARK: - Control Heights
    
    enum Control {
        /// 36pt Compact control (badge, tag, small chip)
        static let compact: CGFloat = 36
        /// 44pt  Standard control (buttons, fields, filter chips)
        /// Also Apple's minimum tap target.
        static let standard: CGFloat = 44
        /// 50pt Ã¢â‚¬â€ Large control (primary CTA, prominent fields)
        static let large: CGFloat = 50
        /// 56pt — Floating action button (FAB), prominent circular buttons
        static let fab: CGFloat = 56
        /// 44pt  Minimum interactive touch target (Apple HIG)
        static let minTapTarget: CGFloat = 44
    }
    
    // MARK: - Avatar Sizes
    
    enum Avatar {
        /// 24pt iInline mention, filter chip avatar
        static let xs: CGFloat = 24
        /// 32pt Compact list row, comment thread
        static let sm: CGFloat = 32
        /// 40pt  Standard list row, card assignee
        static let md: CGFloat = 40
        /// 56pt  Profile card, member detail
        static let lg: CGFloat = 56
        /// 80pt  Profile header, onboarding
        static let xl: CGFloat = 80
    }
    
    // MARK: - Typography
    
    /// Semantic typography roles. Every text element should use one of these.
    /// All are Dynamic Type compatible (use system text styles).
    enum Typography {
        
        // MARK: Display (large, rare)
        
        /// Large screen titles, onboarding headlines
        static func displayLarge() -> Font { .largeTitle.weight(.bold) }
        /// Section hero text, feature titles
        static func displayMedium() -> Font { .title2.weight(.bold) }
        
        // MARK: Headings
        
        /// Screen/section title — visually distinct from body text
        static func heading() -> Font { .title3.weight(.semibold) }
        /// Card title, list group header
        static func subheading() -> Font { .headline }
        
        // MARK: Body
        
        /// Primary body text
        static func body() -> Font { .subheadline }
        /// Medium-weight body text (for emphasis within body)
        static func bodyMedium() -> Font { .subheadline.weight(.medium) }
        /// Secondary descriptive text
        static func bodySmall() -> Font { .caption }
        
        // MARK: Labels
        
        /// Control labels, button text
        static func label() -> Font { .subheadline.weight(.medium) }
        /// Small control labels, chips
        static func labelSmall() -> Font { .caption.weight(.medium) }
        /// Badge text, tag text, chip text
        static func badge() -> Font { .caption.weight(.medium) }
        
        // MARK: Captions & Metadata
        
        /// Caption text
        static func caption() -> Font { .caption }
        /// Medium-weight caption
        static func captionMedium() -> Font { .caption.weight(.medium) }
        /// Tiny metadata, timestamps
        static func micro() -> Font { .caption2 }
        
        // MARK: Numbers
        
        /// Large stat display (progress percentage, count)
        static func stat() -> Font { .title3.weight(.semibold) }
        /// Compact number (badge count, inline metric)
        static func statSmall() -> Font { .subheadline.weight(.semibold) }
    }
    
    // MARK: - Border Width
    
    enum Border {
        /// 0.5pt Subtle card border, divider
        static let hairline: CGFloat = 0.5
        /// 1pt Standard border (inputs, cards)
        static let standard: CGFloat = 1
        /// 2pt Emphasized border (selected state, focus ring)
        static let emphasized: CGFloat = 2
        /// 3pt Heavy border (selected theme card, active indicator)
        static let heavy: CGFloat = 3
    }
    
    // MARK: - Progress Bar
    
    enum ProgressBar {
        /// 4pt  Thin progress bar (inline, compact)
        static let thin: CGFloat = 4
        /// 6pt Standard progress bar
        static let standard: CGFloat = 6
        /// 8pt  Thick progress bar (hero card)
        static let thick: CGFloat = 8
    }
    
    // MARK: - Timer/Focus Components
    
    enum Timer {
        /// Ring diameter for phone (compact)
        static let ringPhone: CGFloat = 260
        /// Ring diameter for iPad/sheets (needs to fit in smaller viewport)
        static let ringPad: CGFloat = 200
        /// Ring stroke width
        static let ringStroke: CGFloat = 14
        /// Timer display font size
        static let displayFont: CGFloat = 64
        /// Timer display font size (compact)
        static let displayFontCompact: CGFloat = 56
    }
    
    // MARK: - Empty State
    
    enum EmptyState {
        /// Icon size for empty state illustrations
        static let icon: CGFloat = 48
        /// Container size for empty state icon background
        static let iconContainer: CGFloat = 80
    }
    
    // MARK: - Haptics
    
    /// Centralized haptic feedback for consistent tactile responses.
    /// Usage: `DS.Haptics.success()` or `DS.Haptics.impact(.light)`
    enum Haptics {
        
        // MARK: - Impact Feedback
        
        /// Light impact - subtle taps (selections, toggles)
        static func light() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        /// Medium impact - confirmations (button presses, card taps)
        static func medium() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        /// Heavy impact - significant actions (delete, major state changes)
        static func heavy() {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        
        /// Soft impact - gentle feedback (iOS 13+)
        static func soft() {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        
        /// Rigid impact - sharp, precise feedback (iOS 13+)
        static func rigid() {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        
        // MARK: - Notification Feedback
        
        /// Success - task completed, save successful
        static func success() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        
        /// Warning - attention needed, validation issue
        static func warning() {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        
        /// Error - action failed, invalid input
        static func error() {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        // MARK: - Selection Feedback
        
        /// Selection changed - picker scrolling, segment switching, tab changes
        static func selection() {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        
        // MARK: - Convenience Methods
        
        /// Impact with customizable style
        static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
        
        /// Impact with intensity (0.0 - 1.0)
        static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
            UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
        }
        
        /// Notification with customizable type
        static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
            UINotificationFeedbackGenerator().notificationOccurred(type)
        }
    }
    
    // MARK: - Shadow Definitions
    
    /// Shadow token struct — use via elevation modifiers, not directly.
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        /// Level 0 — flat, no shadow
        static let level0 = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        /// Level 1 — subtle lift (sections)
        static let level1 = Shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        /// Level 2 — medium depth (cards)
        static let level2 = Shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        /// Level 3 — high depth (floating, modals)
        static let level3 = Shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 8)
        
        /// Accent glow for primary buttons
        static func accent(_ color: Color) -> Shadow {
            Shadow(color: color.opacity(0.25), radius: 12, x: 0, y: 4)
        }
    }
    
    // MARK: - Animation Curves
    
    enum Animation {
        /// Micro interaction (tap, selection) — 0.15s ease-out
        static let micro = SwiftUI.Animation.easeOut(duration: 0.15)
        /// Standard transition — 0.25s ease-in-out
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        /// Smooth spring for UI elements
        static let smooth = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
        /// Bouncy spring for playful elements
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
        /// Gentle spring for subtle movements
        static let gentle = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.9)
    }
}

// MARK: - Elevation (Shadow System)

extension View {
    
    /// Level 0 — flat, no shadow
    func elevation0() -> some View {
        self
    }
    
    /// Level 1 — subtle lift (section containers)
    func elevation1() -> some View {
        self.shadow(
            color: DS.Shadow.level1.color,
            radius: DS.Shadow.level1.radius,
            x: DS.Shadow.level1.x,
            y: DS.Shadow.level1.y
        )
    }
    
    /// Level 2 — medium depth (cards, interactive)
    func elevation2() -> some View {
        self.shadow(
            color: DS.Shadow.level2.color,
            radius: DS.Shadow.level2.radius,
            x: DS.Shadow.level2.x,
            y: DS.Shadow.level2.y
        )
    }
    
    /// Level 3 — high depth (floating, modals)
    func elevation3() -> some View {
        self.shadow(
            color: DS.Shadow.level3.color,
            radius: DS.Shadow.level3.radius,
            x: DS.Shadow.level3.x,
            y: DS.Shadow.level3.y
        )
    }
    
    /// Accent glow (primary buttons)
    func elevationAccent(_ color: Color = .accentPrimary) -> some View {
        let s = DS.Shadow.accent(color)
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
    
    /// Backward-compat alias — use elevation0() instead
    @available(*, deprecated, renamed: "elevation0")
    func elevationNone() -> some View { elevation0() }
}

// MARK: - Standardized Card Modifier

extension View {
    
    /// Standard card appearance: 12pt padding, 12pt radius, themed bg + border + subtle lift
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
            .elevation1()
    }
    
    /// Hero/feature card: 16pt padding, 16pt radius, themed bg + border + medium depth
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
            .elevation2()
    }
}

// MARK: - iPad-Friendly Layout Modifiers

extension View {
    
    /// Constrains content to a maximum width and centers it.
    /// On iPhone, this is a no-op (content fills available width).
    /// On iPad, content is constrained to the specified max width and centered.
    ///
    /// Usage: `VStack { ... }.constrainedWidth(.form)`
    func constrainedWidth(_ style: ConstrainedWidthStyle = .form) -> some View {
        modifier(ConstrainedWidthModifier(maxWidth: style.maxWidth))
    }
    
    /// Constrains content to a specific maximum width and centers it.
    /// On iPhone, this is a no-op.
    ///
    /// Usage: `VStack { ... }.constrainedWidth(maxWidth: 500)`
    func constrainedWidth(maxWidth: CGFloat) -> some View {
        modifier(ConstrainedWidthModifier(maxWidth: maxWidth))
    }
    
    /// Applies adaptive horizontal padding - larger on iPad.
    /// iPhone: 16pt, iPad: 32pt
    func adaptiveScreenPadding() -> some View {
        self.padding(.horizontal, DS.Layout.adaptiveScreenPadding)
    }
    
    /// Combines constrained width with adaptive padding for form-like screens.
    /// Ideal for auth screens, settings, onboarding flows.
    func formLayout() -> some View {
        self
            .constrainedWidth(.form)
            .adaptiveScreenPadding()
    }
    
    /// Combines constrained width with adaptive padding for content screens.
    /// Ideal for detail views, articles, longer content.
    func contentLayout() -> some View {
        self
            .constrainedWidth(.content)
            .adaptiveScreenPadding()
    }
}

/// Predefined width constraint styles
enum ConstrainedWidthStyle {
    /// For forms, auth screens, settings (440pt)
    case form
    /// For cards, list items (600pt)
    case card
    /// For readable content (700pt)
    case readable
    /// For main content areas (800pt)
    case content
    /// For wide layouts (1000pt)
    case wide
    
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

/// View modifier that constrains content width on iPad
struct ConstrainedWidthModifier: ViewModifier {
    let maxWidth: CGFloat
    
    func body(content: Content) -> some View {
        if DS.Layout.shouldConstrainWidth {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                content
                    .frame(maxWidth: maxWidth)
                Spacer(minLength: 0)
            }
        } else {
            content
        }
    }
}

/// A container view that constrains its content to a readable width on iPad.
/// More explicit alternative to the modifier.
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
                content
                    .frame(maxWidth: style.maxWidth)
                Spacer(minLength: 0)
            }
        } else {
            content
        }
    }
}

// MARK: - Standardized Icon Container

/// Rounded-rect icon container with tinted background.
/// Use for leading icons in info rows, settings rows, etc.
struct IconBox: View {
    let icon: String
    var color: Color = .accentPrimary
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


// MARK: - Theme Color Extensions
//
// All theme colors consolidated here. Single source of truth.

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
    
    /// Text colour for subtle metadata
    static var themeTextMuted: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.5)
                : UIColor.black.withAlphaComponent(0.45)
        })
    }
    
    /// Subtle card border for premium feel
    static var themeCardBorder: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.06)
                : UIColor.black.withAlphaComponent(0.04)
        })
    }
    
    /// Subtle highlight for selected/active states (palette-aware)
    static var themeHighlight: Color {
        Color(UIColor { traits in
            let palette = ThemeManager.shared.palette
            if traits.userInterfaceStyle == .dark {
                return UIColor(Color(hex: palette.accentDark)).withAlphaComponent(0.15)
            } else {
                return UIColor(Color(hex: palette.accent)).withAlphaComponent(0.12)
            }
        })
    }
}

// MARK: - ThemeDivider

/// A 1pt horizontal divider using the theme divider color.
struct ThemeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.themeDivider)
            .frame(height: 1)
    }
}

// MARK: - Gradient Extensions
//
// All gradient tokens consolidated here. Single source of truth.

extension LinearGradient {
    
    /// Primary accent gradient (palette-aware)
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentPrimary, Color.accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Subtle top-to-bottom gradient for auth/setup screens
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.themeSurfacePrimary, Color.themeCardBackground],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
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

#Preview("Spacing Scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spacing Scale")
                .font(DS.Typography.displayMedium())
            
            Group {
                spacingSwatch("xxs (2)", DS.Spacing.xxs)
                spacingSwatch("xs (4)", DS.Spacing.xs)
                spacingSwatch("sm (8)", DS.Spacing.sm)
                spacingSwatch("md (12)", DS.Spacing.md)
                spacingSwatch("lg (16)", DS.Spacing.lg)
                spacingSwatch("xl (20)", DS.Spacing.xl)
                spacingSwatch("xxl (24)", DS.Spacing.xxl)
                spacingSwatch("xxxl (32)", DS.Spacing.xxxl)
                spacingSwatch("jumbo (40)", DS.Spacing.jumbo)
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Corner Radius")
                .font(DS.Typography.displayMedium())
            
            HStack(spacing: 12) {
                radiusSwatch("sm\n6", DS.Radius.sm)
                radiusSwatch("md\n8", DS.Radius.md)
                radiusSwatch("lg\n12", DS.Radius.lg)
                radiusSwatch("xl\n16", DS.Radius.xl)
                radiusSwatch("xxl\n20", DS.Radius.xxl)
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
                Text("Body Small").font(DS.Typography.bodySmall())
                Text("Label").font(DS.Typography.label())
                Text("Badge").font(DS.Typography.badge())
                Text("Micro").font(DS.Typography.micro())
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Elevation")
                .font(DS.Typography.displayMedium())
            
            VStack(spacing: 16) {
                elevationSample("Level 0 â€ flat", 0)
                elevationSample("Level 1 â€ cards", 1)
                elevationSample("Level 2 â€ floating", 2)
                elevationSample("Level 3 â€ modal", 3)
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Cards")
                .font(DS.Typography.displayMedium())
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Standard Card Title")
                    .font(DS.Typography.subheading())
                Text("Body text inside a standard card with 12pt padding and 12pt radius.")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .standardCard()
            
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Hero Card Title")
                    .font(DS.Typography.heading())
                Text("Larger padding (16pt) and radius (16pt) for feature/summary cards.")
                    .font(DS.Typography.body())
                    .foregroundStyle(.textSecondary)
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
            .frame(width: 90, alignment: .leading)
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
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
    }
}

@ViewBuilder
private func elevationSample(_ label: String, _ level: Int) -> some View {
    let base = Text(label)
        .font(.caption)
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.themeCardBackground))
    
    switch level {
    case 1: base.elevation1()
    case 2: base.elevation2()
    case 3: base.elevation3()
    default: base
    }
}
