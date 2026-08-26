import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: ReadAppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerTheme) private var theme

    @State private var newSourceURL = ""
    @State private var section: Section = .sources

    private enum Section: String, CaseIterable, Identifiable {
        case sources = "Sources"
        case themes = "Themes"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(ReaderTheme.serif(20, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Picker("", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch section {
            case .sources:
                sourcesSection
            case .themes:
                ThemeGallery(selected: model.theme) { model.theme = $0 }
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 560)
        .background(theme.texturedPaper)
        .preferredColorScheme(.light)
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
                Text("Tracked Sources")
                    .font(ReaderTheme.sans(13, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("Read pulls headlines from each site's front page.")
                    .font(ReaderTheme.sans(12))
                    .foregroundStyle(theme.inkSecondary)

                List {
                    ForEach(model.sources) { source in
                        HStack {
                            Text(source.url)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                model.removeSource(source.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 260)

                HStack {
                    TextField("https://example.com", text: $newSourceURL)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addSource)
                    Button("Add", action: addSource)
                        .disabled(newSourceURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
        }
    }

    private func addSource() {
        model.addSource(urlString: newSourceURL)
        newSourceURL = ""
    }
}

/// The theme picker: every palette as it will actually look, rather than as a
/// name in a menu. Each card shows the two surfaces a theme decides — the
/// patterned header bar and the paper underneath it — alongside the app icon
/// that comes with it, because the icon is the most visible consequence of the
/// choice and the hardest to picture from a name like "Delaunay Triangles".
private struct ThemeGallery: View {
    let selected: ReaderTheme
    let choose: (ReaderTheme) -> Void

    @Environment(\.readerTheme) private var theme

    private let columns = [GridItem(.adaptive(minimum: 208), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ReaderTheme.all) { candidate in
                    Button {
                        choose(candidate)
                    } label: {
                        ThemeCard(candidate: candidate, isSelected: candidate.id == selected.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct ThemeCard: View {
    let candidate: ReaderTheme
    let isSelected: Bool

    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The header strip, drawn with the same renderer the window uses,
            // with the icon overlapping it the way it does in the Dock.
            ZStack(alignment: .leading) {
                Image(nsImage: candidate.headerImage(width: 420, height: 44))
                    .resizable()
                    .frame(height: 34)
                    .clipped()

                Image(nsImage: candidate.iconImage(size: 128))
                    .resizable()
                    .frame(width: 30, height: 30)
                    .padding(.leading, 6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.title)
                    .font(ReaderTheme.sans(12, weight: .semibold))
                    .foregroundStyle(candidate.ink)
                    .lineLimit(1)
                Text("Aa headline, and the body copy under it.")
                    .font(ReaderTheme.serif(11))
                    .foregroundStyle(candidate.inkSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(candidate.paper)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? theme.ink : theme.rule, lineWidth: isSelected ? 2 : 1)
        )
    }
}
