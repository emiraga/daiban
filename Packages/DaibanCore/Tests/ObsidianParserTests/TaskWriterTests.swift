import Testing
import Foundation
@testable import ObsidianParser

@Suite("TaskWriter")
struct TaskWriterTests {
    let parser = TaskParser()
    let writer = TaskWriter()

    @Test("Completes a todo task")
    func completeTodo() {
        let line = "- [ ] Buy groceries"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)!

        let result = writer.toggleCompletion(task)

        #expect(result.hasPrefix("- [x] Buy groceries"))
        #expect(result.contains("\u{2705}"))
    }

    @Test("Uncompletes a done task")
    func uncompleteDone() {
        let line = "- [x] Buy groceries \u{2705} 2026-03-28"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)!

        let result = writer.toggleCompletion(task)

        #expect(result == "- [ ] Buy groceries")
        #expect(!result.contains("\u{2705}"))
    }

    @Test("Replaces line in file content")
    func replaceLine() {
        let content = "Line 0\nLine 1\nLine 2"
        let result = writer.replaceLine(in: content, at: 1, with: "Modified")

        #expect(result == "Line 0\nModified\nLine 2")
    }
}
