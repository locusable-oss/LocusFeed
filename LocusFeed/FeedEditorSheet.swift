import SwiftUI

enum FeedEditorMode {
    case add
    case edit(Feed)
}

struct FeedEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: FeedEditorMode

    @State private var title: String = ""
    @State private var url: String = ""
    @State private var siteURL: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(heading)
                .font(.title3.weight(.semibold))

            Form {
                TextField("Title", text: $title)
                TextField("Feed URL", text: $url)
                    .textContentType(.URL)
                TextField("Site URL (optional)", text: $siteURL)
                    .textContentType(.URL)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(saveLabel) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!Self.isHTTPSURL(url.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear(perform: hydrate)
    }

    private var heading: String {
        switch mode {
        case .add: return "Add Feed"
        case .edit: return "Edit Feed"
        }
    }

    private var saveLabel: String {
        switch mode {
        case .add: return "Add"
        case .edit: return "Save"
        }
    }

    private func hydrate() {
        if case .edit(let feed) = mode {
            title = feed.title
            url = feed.url
            siteURL = feed.siteURL ?? ""
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = siteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let site = s.isEmpty ? nil : s

        guard Self.isHTTPSURL(u) else {
            appState.errorMessage = "Feed URL must be a valid HTTPS address."
            return
        }
        if let site, !Self.isHTTPSURL(site) {
            appState.errorMessage = "Site URL must be HTTPS when provided."
            return
        }

        switch mode {
        case .add:
            let display = t.isEmpty ? u : t
            appState.addFeed(title: display, url: u, siteURL: site)
        case .edit(var feed):
            feed.title = t.isEmpty ? u : t
            feed.url = u
            feed.siteURL = site
            appState.updateFeed(feed)
        }
        dismiss()
    }

    private static func isHTTPSURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(), let host = url.host else {
            return false
        }
        return scheme == "https" && !host.isEmpty
    }
}
