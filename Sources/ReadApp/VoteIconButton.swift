import SwiftUI

/// A small up/down vote chevron with hover feedback and a persistent bold
/// "voted" state — shared between the homepage rail and the permalink page,
/// so voting looks and behaves the same wherever it appears.
struct VoteIconButton: View {
    let systemName: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.readerTheme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? systemName + ".fill" : systemName)
                .font(.system(size: 15, weight: isActive ? .bold : .regular))
                .foregroundStyle(color)
                .background(Circle().fill(theme.paper).frame(width: 13, height: 13))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.2 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .help(isActive ? "Voted" : "Vote")
    }

    private var color: Color {
        if isActive {
            return theme.ink
        }
        return isHovering ? theme.inkSecondary : theme.rule
    }
}
