import SwiftUI

/// The "Read" wordmark in the window's title bar, doubling as a home link —
/// shared by the feed and permalink pages so the header looks identical on
/// both. macOS 26 draws a glass background capsule behind every toolbar item,
/// which around a bare wordmark reads as a stray bubble rather than a logo, so
/// there that shared background is hidden and the text sits directly on the
/// header tint.
struct BrandToolbarItem: ToolbarContent {
    let goHome: () -> Void
    let isRefreshing: Bool
    let refresh: () -> Void
    let settings: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            content.sharedBackgroundVisibility(.hidden)
        } else {
            content
        }
    }

    @ToolbarContentBuilder
    private var content: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            BackPill(isEnabled: false) {}
        }
        ToolbarItem(placement: .principal) {
            HomeCandleButton(action: goHome)
        }
        HeaderActions(isRefreshing: isRefreshing, refresh: refresh, settings: settings)
    }
}

/// Article navigation stays on the left, Home in the centre, and actions
/// on the right, using the same placements as the feed.
struct PermalinkBrandToolbarItem: ToolbarContent {
    let goBack: () -> Void
    let goHome: () -> Void
    let isRefreshing: Bool
    let refresh: () -> Void
    let settings: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            content.sharedBackgroundVisibility(.hidden)
        } else {
            content
        }
    }

    @ToolbarContentBuilder
    private var content: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            BackPill(isEnabled: true, action: goBack)
        }
        ToolbarItem(placement: .principal) {
            HomeCandleButton(action: goHome)
        }
        HeaderActions(isRefreshing: isRefreshing, refresh: refresh, settings: settings)
    }
}

private struct BackPill: View {
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.readerTheme) private var theme
    @State private var isHovering = false

    init(isEnabled: Bool, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            ZStack {
                Color.clear
                Image(systemName: "chevron.left")
                    .font(BrandTypeface.appFont(15, weight: .medium))
                    .foregroundStyle(theme.headerInk.opacity(isHovering ? 0.46 : 0.78))
            }
            .frame(width: 54, height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(Capsule().fill(Color.white.opacity(0.82)))
        .contentShape(Capsule())
        .allowsHitTesting(isEnabled)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Back")
    }
}

private struct HomeCandleButton: View {
    let action: () -> Void

    @Environment(\.readerTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            CandleMark(
                height: 40,
                opacity: isHovering ? 0.46 : 0.78,
                tint: theme.headerInk
            )
            .frame(width: 46, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
        .help("Home")
    }
}

private struct HeaderActions: ToolbarContent {
    let isRefreshing: Bool
    let refresh: () -> Void
    let settings: () -> Void

    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.flexible, placement: .primaryAction)
        } else {
            ToolbarItem(placement: .primaryAction) { Spacer() }
        }
        ToolbarItem(placement: .primaryAction) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.regular)
                    .frame(width: 36, height: 36)
            } else {
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh")
                .help("Refresh")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: settings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .help("Settings")
        }
    }
}
