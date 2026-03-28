import SwiftUI

/// Renders a string as inline markdown using SwiftUI's built-in AttributedString.
/// Supports **bold**, *italic*, `code`, ~~strikethrough~~, and [links](url).
/// Falls back to plain text if markdown parsing fails.
struct MarkdownText: View {
    @Environment(\.colorScheme) private var colorScheme
    let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    private var content: AttributedString {
        Self.parse(markdown, colorScheme: colorScheme)
    }

    /// Converts Obsidian-style `[[Page|text]]` or `[[Page]]` links into standard markdown links
    /// pointing at `obsidian://open?vault=SecondBrain&file=Page`.
    private static func convertObsidianLinks(_ text: String) -> String {
        // Matches [[Target|Display]] or [[Target]]
        let pattern = #"\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsRange = NSRange(text.startIndex..., in: text)
        var result = text
        // Replace from end to start so ranges stay valid
        let matches = regex.matches(in: text, range: nsRange)
        for match in matches.reversed() {
            guard let targetRange = Range(match.range(at: 1), in: text) else { continue }
            let target = String(text[targetRange])
            let display: String
            if match.range(at: 2).location != NSNotFound, let displayRange = Range(match.range(at: 2), in: text) {
                display = String(text[displayRange])
            } else {
                display = target
            }
            let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target
            let mdLink = "[\(display)](obsidian://open?vault=SecondBrain&file=\(encoded))"
            let fullRange = Range(match.range, in: result)!
            result.replaceSubrange(fullRange, with: mdLink)
        }
        return result
    }

    private static func parse(_ markdown: String, colorScheme: ColorScheme) -> AttributedString {
        let processed = convertObsidianLinks(markdown)
        var result: AttributedString
        if let attributed = try? AttributedString(markdown: processed, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            result = attributed
        } else {
            result = AttributedString(markdown)
        }
        return Self.applyHighlights(to: result, colorScheme: colorScheme)
    }

    /// Finds `==text==` markers in the attributed string, removes them,
    /// and applies a yellow background to the enclosed text.
    private static func applyHighlights(to input: AttributedString, colorScheme: ColorScheme) -> AttributedString {
        var result = input
        while let openRange = result.range(of: "==") {
            let afterOpen = openRange.upperBound
            guard let closeRange = result[afterOpen...].range(of: "==") else { break }
            let beforeClose = closeRange.lowerBound

            // Apply highlight to the text between the markers
            let highlightColor: Color = colorScheme == .dark
                ? Color(red: 0.55, green: 0.5, blue: 0.0)
                : .yellow
            result[afterOpen..<beforeClose].backgroundColor = highlightColor

            // Remove closing marker first (so opening range stays valid)
            result.removeSubrange(closeRange)
            // Remove opening marker
            result.removeSubrange(openRange)
        }
        return result
    }

    var body: some View {
        Text(content)
    }
}
