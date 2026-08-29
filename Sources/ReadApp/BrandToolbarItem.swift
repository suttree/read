import SwiftUI

/// The "Read" wordmark in the window's title bar, doubling as a home link —
/// shared by the feed and permalink pages so the header looks identical on
/// both. macOS 26 draws a glass background capsule behind every toolbar item,
/// which around a bare wordmark reads as a stray bubble rather than a logo, so
/// there that shared background is hidden and the text sits directly on the
/// header tint.
struct BrandToolbarItem: ToolbarContent {
    let goHome: () -> Void

    @Environment(\.readerTheme) private var theme

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            wordmark.sharedBackgroundVisibility(.hidden)
        } else {
            wordmark
        }
    }

    private var wordmark: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 14) {
                HeaderLink(title: "< Back", isActive: false, isEnabled: false) {}
                CandleMark(height: 26, opacity: 0.78, tint: theme.headerInk)
                HeaderLink(title: "Home", isActive: true, action: goHome)
            }
        }
    }
}

/// The permalink page's header: the active back link followed by Home. Built
/// as one toolbar item so the two labels read as a single navigation group.
struct PermalinkBrandToolbarItem: ToolbarContent {
    let goHome: () -> Void

    @Environment(\.readerTheme) private var theme

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            content.sharedBackgroundVisibility(.hidden)
        } else {
            content
        }
    }

    private var content: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 14) {
                HeaderLink(title: "< Back", isActive: true, action: goHome)
                CandleMark(height: 26, opacity: 0.78, tint: theme.headerInk)
                HeaderLink(title: "Home", isActive: true, action: goHome)
            }
        }
    }
}

private struct HeaderLink: View {
    let title: String
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.readerTheme) private var theme
    @State private var isHovering = false

    init(title: String, isActive: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isActive = isActive
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BrandTypeface.wordmark(18, weight: .regular))
                .foregroundStyle(theme.headerInk.opacity(isHovering ? 0.46 : 0.78))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            guard isEnabled else { return }
            isHovering = hovering
        }
    }
}
