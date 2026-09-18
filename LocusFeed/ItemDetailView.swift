import SwiftUI
import WebKit
import AppKit

/// Detail pane: plain text by default; simple HTML via AttributedString or a sandboxed WKWebView.
struct ItemDetailView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let item = appState.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            appState.toggleItemRead(id: item.id)
                        } label: {
                            Label(
                                item.isRead ? "Mark Unread" : "Mark Read",
                                systemImage: item.isRead ? "circle" : "checkmark.circle"
                            )
                        }
                        .help(item.isRead ? "Mark this item unread" : "Mark this item read")
                    }

                    if let published = item.publishedAt {
                        Text(published.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let link = item.link, let url = URL(string: link) {
                        Link(link, destination: url)
                            .font(.caption)
                            .lineLimit(2)
                    }

                    Divider()

                    ItemBodyView(summary: item.summary, fontPoints: appState.bodyFontSize.points)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if appState.selectedFeedID != nil {
            ContentUnavailableView(
                "Select an item",
                systemImage: "doc.text",
                description: Text("Choose an article from the list to read it here.")
            )
        } else {
            ContentUnavailableView(
                "Select a feed",
                systemImage: "sidebar.left",
                description: Text("Choose a subscription or add a new one.")
            )
        }
    }
}

private struct ItemBodyView: View {
    let summary: String?
    var fontPoints: Double = BodyFontSize.regular.points

    var body: some View {
        let raw = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            Text("No content available for this item.")
                .font(.system(size: fontPoints))
                .foregroundStyle(.secondary)
        } else if Self.looksLikeHTML(raw) {
            if let attributed = Self.htmlAttributed(raw, fontPoints: fontPoints) {
                Text(attributed)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                SimpleHTMLWebView(html: Self.wrapHTML(raw, fontPoints: fontPoints))
                    .frame(minHeight: 240)
                    .frame(maxWidth: .infinity)
            }
        } else {
            Text(raw)
                .font(.system(size: fontPoints))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func looksLikeHTML(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.contains("<p") || lower.contains("<br") || lower.contains("<div")
            || lower.contains("<a ") || lower.contains("<ul") || lower.contains("<li")
            || lower.contains("<h1") || lower.contains("<h2") || lower.contains("<em")
            || lower.contains("<strong") || lower.contains("&lt;") || lower.contains("<html")
    }

    private static func htmlAttributed(_ html: String, fontPoints: Double) -> AttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard let base = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        let ns = NSMutableAttributedString(attributedString: base)
        let range = NSRange(location: 0, length: ns.length)
        if range.length > 0 {
            let target = CGFloat(fontPoints)
            ns.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let sized: NSFont
                if let existing = value as? NSFont,
                   let resized = NSFont(descriptor: existing.fontDescriptor, size: target) {
                    sized = resized
                } else {
                    sized = NSFont.systemFont(ofSize: target)
                }
                ns.addAttribute(.font, value: sized, range: subrange)
            }
        }
        return AttributedString(ns)
    }

    private static func wrapHTML(_ body: String, fontPoints: Double) -> String {
        let px = Int(fontPoints.rounded())
        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <style>
          :root { color-scheme: light dark; }
          body { font: -apple-system-body; font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                 font-size: \(px)px;
                 margin: 0; padding: 0; line-height: 1.45; word-wrap: break-word; }
          img { max-width: 100%; height: auto; }
          a { color: #0a84ff; }
        </style>
        </head><body>\(body)</body></html>
        """
    }
}

private struct SimpleHTMLWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}
