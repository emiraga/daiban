import Testing
import Foundation
@testable import ObsidianParser

@Suite("TaskParser")
struct TaskParserTests {
    let parser = TaskParser()

    private func date(_ string: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: string)!
    }

    @Test("Parses a simple todo task")
    func simpleTodo() {
        let line = "- [ ] Buy groceries"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task != nil)
        #expect(task?.description == "Buy groceries")
        #expect(task?.status == .todo)
        #expect(task?.filePath == "notes.md")
        #expect(task?.lineNumber == 0)
        #expect(task?.rawLine == line)
    }

    @Test("Parses a completed task")
    func completedTask() {
        let line = "- [x] Buy groceries"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.status == .done)
        #expect(task?.status.isComplete == true)
    }

    @Test("Parses cancelled task")
    func cancelledTask() {
        let line = "- [-] Cancelled thing"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.status == .cancelled)
        #expect(task?.status.isComplete == true)
    }

    @Test("Parses in-progress task")
    func inProgressTask() {
        let line = "- [/] Working on this"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.status == .inProgress)
        #expect(task?.status.isComplete == false)
    }

    @Test("Parses due date")
    func dueDate() {
        let line = "- [ ] Submit report \u{1F4C5} 2026-03-28"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.dueDate == date("2026-03-28"))
        #expect(task?.description == "Submit report")
    }

    @Test("Parses scheduled date")
    func scheduledDate() {
        let line = "- [ ] Review PR \u{23F3} 2026-03-27"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.scheduledDate == date("2026-03-27"))
    }

    @Test("Parses start date")
    func startDate() {
        let line = "- [ ] Start project \u{1F6EB} 2026-03-25"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.startDate == date("2026-03-25"))
    }

    @Test("Parses created date")
    func createdDate() {
        let line = "- [ ] New task \u{2795} 2026-03-20"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.createdDate == date("2026-03-20"))
    }

    @Test("Parses done date")
    func doneDate() {
        let line = "- [x] Finished task \u{2705} 2026-03-28"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.doneDate == date("2026-03-28"))
    }

    @Test("Parses priorities", arguments: [
        ("\u{1F53A}", TaskPriority.highest),
        ("\u{23EB}", TaskPriority.high),
        ("\u{1F53C}", TaskPriority.medium),
        ("\u{1F53D}", TaskPriority.low),
        ("\u{23EC}", TaskPriority.lowest),
    ])
    func priorities(emoji: String, expected: TaskPriority) {
        let line = "- [ ] Task \(emoji)"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.priority == expected)
    }

    @Test("Parses recurrence")
    func recurrence() {
        let line = "- [ ] Water plants \u{1F501} every week \u{1F4C5} 2026-03-28"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.recurrence?.rule == "every week")
    }

    @Test("Parses tags")
    func tags() {
        let line = "- [ ] Fix bug #work #urgent"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task?.tags == ["work", "urgent"])
    }

    @Test("Parses full task with all fields")
    func fullTask() {
        let line = "- [ ] Important meeting \u{23EB} \u{1F4C5} 2026-04-01 \u{23F3} 2026-03-30 \u{1F6EB} 2026-03-28 \u{1F501} every month \u{2795} 2026-03-20 #work"
        let task = parser.parseLine(line, filePath: "daily/2026-03-28.md", lineNumber: 5)

        #expect(task?.description == "Important meeting")
        #expect(task?.status == .todo)
        #expect(task?.priority == .high)
        #expect(task?.dueDate == date("2026-04-01"))
        #expect(task?.scheduledDate == date("2026-03-30"))
        #expect(task?.startDate == date("2026-03-28"))
        #expect(task?.createdDate == date("2026-03-20"))
        #expect(task?.recurrence?.rule == "every month")
        #expect(task?.tags == ["work"])
        #expect(task?.filePath == "daily/2026-03-28.md")
        #expect(task?.lineNumber == 5)
    }

    @Test("Ignores non-task lines")
    func nonTaskLines() {
        #expect(parser.parseLine("Regular text", filePath: "f.md", lineNumber: 0) == nil)
        #expect(parser.parseLine("- Not a task", filePath: "f.md", lineNumber: 0) == nil)
        #expect(parser.parseLine("# Heading", filePath: "f.md", lineNumber: 0) == nil)
        #expect(parser.parseLine("  ", filePath: "f.md", lineNumber: 0) == nil)
    }

    @Test("Parses indented tasks")
    func indentedTask() {
        let line = "    - [ ] Sub-task"
        let task = parser.parseLine(line, filePath: "notes.md", lineNumber: 0)

        #expect(task != nil)
        #expect(task?.indentation == 4)
        #expect(task?.description == "Sub-task")
    }

    @Test("Parses multiple tasks from file content")
    func parseFile() {
        let content = """
        # My Tasks

        - [ ] First task
        - [x] Done task
        - Not a task
        - [ ] Third task \u{1F4C5} 2026-04-01
        """

        let tasks = parser.parseFile(content: content, filePath: "tasks.md")

        #expect(tasks.count == 3)
        #expect(tasks[0].description == "First task")
        #expect(tasks[1].status == .done)
        #expect(tasks[2].dueDate == date("2026-04-01"))
    }
}
