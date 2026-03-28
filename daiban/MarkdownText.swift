import SwiftUI

/// Renders a string as inline markdown using SwiftUI's built-in AttributedString.
/// Supports **bold**, *italic*, `code`, ~~strikethrough~~, and [links](url).
/// Falls back to plain text if markdown parsing fails.
struct MarkdownText: View {
    let content: AttributedString

    init(_ markdown: String) {
        if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            self.content = attributed
        } else {
            self.content = AttributedString(markdown)
        }
    }

    var body: some View {
        Text(content)
    }
}
