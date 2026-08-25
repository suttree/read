import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: ReadAppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerTheme) private var theme

    @State private var newSourceURL = ""

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

            Spacer()
        }
        .padding(24)
        .frame(width: 480, height: 480)
        .background(theme.texturedPaper)
        .preferredColorScheme(.light)
    }

    private func addSource() {
        model.addSource(urlString: newSourceURL)
        newSourceURL = ""
    }
}
