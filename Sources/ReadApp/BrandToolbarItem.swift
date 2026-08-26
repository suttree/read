import SwiftUI

/// The "Read" wordmark in the window's title bar, doubling as a home link —
/// shared by the feed and permalink pages so the header looks identical on
/// both. macOS 26 draws a glass background capsule behind every toolbar item,
/// which around a bare wordmark reads as a stray bubble rather than a logo, so
/// there that shared background is hidden and the text sits directly on the
/// header tint.
struct BrandToolbarItem: ToolbarContent {
    let goHome: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            wordmark.sharedBackgroundVisibility(.hidden)
        } else {
            wordmark
        }
    }

    private var wordmark: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            BrandWordmark(goHome: goHome)
        }
    }
}

private struct BrandWordmark: View {
    let goHome: () -> Void

    @Environment(\.readerTheme) private var theme

    var body: some View {
        Button(action: goHome) {
            Text("Read")
                .font(BrandTypeface.wordmark(15))
                .foregroundStyle(theme.headerInk)
                .underline()
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Back to the top of page 1")
    }
}

/// The permalink page's header: the same "Read" wordmark as the feed, plus a
/// middot and the article's own title, so the two don't run together the way
/// plain window-title text butted right up against the wordmark did. Built as
/// one toolbar item rather than two separate ones so macOS 26's glass
/// background — drawn per item, not per view inside one — wraps the whole
/// header as a single piece instead of two adjacent bubbles.
struct PermalinkBrandToolbarItem: ToolbarContent {
    let title: String
    let goHome: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            content.sharedBackgroundVisibility(.hidden)
        } else {
            content
        }
    }

    private var content: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 8) {
                BrandWordmark(goHome: goHome)
                PermalinkTitleBreadcrumb(title: title)
            }
        }
    }
}

private struct PermalinkTitleBreadcrumb: View {
    let title: String

    @Environment(\.readerTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Text("\u{00B7}")
                .font(BrandTypeface.wordmark(16, weight: .bold))
                .foregroundStyle(theme.headerInk.opacity(0.35))
            Text(title)
                .font(ReaderTheme.serif(14, weight: .medium))
                .foregroundStyle(theme.headerInk.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 320, alignment: .leading)
        }
    }
}
