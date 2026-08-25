import AppKit
import SwiftUI

/// A named color theme — greyscale "Default" (the original e-reader look)
/// plus a few pastel options, each carrying its own paper background, ink
/// tones, header-bar tint, and app-icon color. Read via `@Environment(\.readTheme)`
/// rather than as static constants, so every view picks up the active
/// theme instead of being hardcoded to one palette.
enum ReaderTheme: String, CaseIterable, Identifiable {
    case standard
    case meadow
    case sky
    case sunset
    case bubblegum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Default"
        case .meadow: "Meadow"
        case .sky: "Sky"
        case .sunset: "Sunset"
        case .bubblegum: "Bubblegum"
        }
    }

    var paper: Color {
        switch self {
        case .standard: Color(white: 0.96)
        case .meadow: Color(red: 0.90, green: 0.97, blue: 0.91)
        case .sky: Color(red: 0.92, green: 0.96, blue: 1.0)
        case .sunset: Color(red: 1.0, green: 0.96, blue: 0.90)
        case .bubblegum: Color(red: 1.0, green: 0.94, blue: 0.97)
        }
    }

    var paperInset: Color {
        switch self {
        case .standard: Color(white: 0.99)
        case .meadow: Color(red: 0.95, green: 0.99, blue: 0.96)
        case .sky: Color(red: 0.96, green: 0.98, blue: 1.0)
        case .sunset: Color(red: 1.0, green: 0.98, blue: 0.95)
        case .bubblegum: Color(red: 1.0, green: 0.97, blue: 0.99)
        }
    }

    var ink: Color {
        switch self {
        case .standard: Color(white: 0.12)
        case .meadow: Color(red: 0.10, green: 0.20, blue: 0.13)
        case .sky: Color(red: 0.08, green: 0.14, blue: 0.24)
        case .sunset: Color(red: 0.30, green: 0.16, blue: 0.05)
        case .bubblegum: Color(red: 0.30, green: 0.08, blue: 0.18)
        }
    }

    var inkSecondary: Color {
        switch self {
        case .standard: Color(white: 0.42)
        case .meadow: Color(red: 0.30, green: 0.42, blue: 0.33)
        case .sky: Color(red: 0.35, green: 0.44, blue: 0.55)
        case .sunset: Color(red: 0.55, green: 0.40, blue: 0.25)
        case .bubblegum: Color(red: 0.55, green: 0.30, blue: 0.42)
        }
    }

    var rule: Color {
        switch self {
        case .standard: Color(white: 0.82)
        case .meadow: Color(red: 0.75, green: 0.87, blue: 0.78)
        case .sky: Color(red: 0.78, green: 0.87, blue: 0.97)
        case .sunset: Color(red: 0.95, green: 0.85, blue: 0.68)
        case .bubblegum: Color(red: 0.96, green: 0.80, blue: 0.88)
        }
    }

    /// The window title/header bar tint — a slightly more saturated version
    /// of the paper tone, the same technique Fork uses for its title bar.
    var headerTint: Color {
        switch self {
        case .standard: Color(white: 0.96)
        case .meadow: Color(red: 0.80, green: 0.94, blue: 0.83)
        case .sky: Color(red: 0.79, green: 0.89, blue: 1.0)
        case .sunset: Color(red: 1.0, green: 0.87, blue: 0.55)
        case .bubblegum: Color(red: 0.98, green: 0.82, blue: 0.90)
        }
    }

    /// Placeholder app-icon color until there's real artwork — a flat
    /// squircle in this tone, generated at runtime rather than needing an
    /// image asset.
    var iconColor: NSColor {
        switch self {
        case .standard: NSColor(white: 0.15, alpha: 1)
        case .meadow: NSColor(red: 0.55, green: 0.80, blue: 0.60, alpha: 1)
        case .sky: NSColor(red: 0.55, green: 0.72, blue: 0.95, alpha: 1)
        case .sunset: NSColor(red: 0.95, green: 0.65, blue: 0.35, alpha: 1)
        case .bubblegum: NSColor(red: 0.95, green: 0.60, blue: 0.78, alpha: 1)
        }
    }

    /// +1pt over whatever size is asked for, applied here once rather than
    /// at every call site, so the whole app's type scale can move together.
    private static let sizeBump: CGFloat = 1

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size + sizeBump, weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size + sizeBump, weight: weight, design: .default)
    }

    /// Paper color plus a faint tiled polka-dot texture — the same 4×4-unit,
    /// two-dot repeating pattern used as the background on duncangough.com
    /// (a small SVG data URI there), redrawn here tinted to each theme's ink
    /// tone rather than the site's fixed purple-grey.
    var texturedPaper: some View {
        paper.overlay(PolkaDotTexture(color: inkSecondary.opacity(0.06)))
    }
}

private struct ReaderThemeKey: EnvironmentKey {
    static let defaultValue: ReaderTheme = .standard
}

extension EnvironmentValues {
    var readerTheme: ReaderTheme {
        get { self[ReaderThemeKey.self] }
        set { self[ReaderThemeKey.self] = newValue }
    }
}

private struct PolkaDotTexture: View {
    var color: Color
    var unit: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            let tile = unit * 4
            var y: CGFloat = -tile
            while y < size.height + tile {
                var x: CGFloat = -tile
                while x < size.width + tile {
                    context.fill(Path(CGRect(x: x + unit, y: y + unit * 3, width: unit, height: unit)), with: .color(color))
                    context.fill(Path(CGRect(x: x + unit * 3, y: y + unit, width: unit, height: unit)), with: .color(color))
                    x += tile
                }
                y += tile
            }
        }
        .allowsHitTesting(false)
    }
}

/// Generates and applies a theme-colored squircle app icon with the app's
/// hand-drawn open-book artwork on top (recolored to white, matching Fork's
/// two-tone flat-icon style), persisting the choice across relaunches since
/// an icon override is otherwise just an in-memory NSApplication property
/// macOS has no reason to remember on its own.
enum AppIconTheming {
    private static let storageKey = "ReadThemeIconVariant"

    private static let artwork: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIconArtwork", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    @MainActor
    static func apply(_ theme: ReaderTheme) {
        guard let image = squircleIcon(color: theme.iconColor) else {
            return
        }
        NSApplication.shared.applicationIconImage = image
        UserDefaults.standard.set(theme.rawValue, forKey: storageKey)
    }

    @MainActor
    static func applyStoredSelection() {
        guard let stored = UserDefaults.standard.string(forKey: storageKey),
              let theme = ReaderTheme(rawValue: stored) else {
            return
        }
        apply(theme)
    }

    private static func squircleIcon(color: NSColor, size: CGFloat = 512) -> NSImage? {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let inset = size * 0.06
        let squircleRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let path = NSBezierPath(roundedRect: squircleRect, xRadius: squircleRect.width * 0.22, yRadius: squircleRect.height * 0.22)
        color.setFill()
        path.fill()

        if let artwork, let tinted = tintedArtwork(artwork, tint: .white, fillFraction: 0.74, in: squircleRect.size) {
            let drawRect = NSRect(
                x: squircleRect.midX - tinted.size.width / 2,
                y: squircleRect.midY - tinted.size.height / 2,
                width: tinted.size.width,
                height: tinted.size.height
            )
            tinted.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        return image
    }

    /// Recolors the artwork's opaque pixels to `tint` (the classic
    /// "template image" trick: paint the source, then fill with
    /// `.sourceAtop` so only pixels the artwork already made opaque get
    /// covered) — done on its own transparent image first, rather than
    /// directly on the squircle background. Doing it directly on the
    /// squircle doesn't work: that background is already fully opaque, so
    /// `.sourceAtop` there matches every pixel in the draw rect, not just
    /// the artwork's silhouette, painting a solid tinted square instead of
    /// the artwork's shape.
    private static func tintedArtwork(_ artwork: NSImage, tint: NSColor, fillFraction: CGFloat, in bounds: NSSize) -> NSImage? {
        let artworkAspect = artwork.size.width / max(artwork.size.height, 1)
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        if artworkAspect >= 1 {
            targetWidth = bounds.width * fillFraction
            targetHeight = targetWidth / artworkAspect
        } else {
            targetHeight = bounds.height * fillFraction
            targetWidth = targetHeight * artworkAspect
        }

        let result = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        result.lockFocus()
        artwork.draw(in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight), from: .zero, operation: .sourceOver, fraction: 1.0)
        let context = NSGraphicsContext.current
        context?.compositingOperation = .sourceAtop
        tint.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight)).fill()
        context?.compositingOperation = .sourceOver
        result.unlockFocus()
        return result
    }
}
