import Testing
import Foundation
@testable import ObsidianParser

@Suite("DailyNotesConfig")
struct DailyNotesConfigTests {

    @Test("Extracts date from standard daily note path")
    func standardDailyNote() {
        let config = DailyNotesConfig(folder: "Daily Notes", dateFormat: "YYYY-MM-DD")
        let date = config.dateFromFilePath("Daily Notes/2026-03-28.md")

        #expect(date != nil)
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 28)
    }

    @Test("Returns nil for file not in daily notes folder")
    func wrongFolder() {
        let config = DailyNotesConfig(folder: "Daily Notes", dateFormat: "YYYY-MM-DD")
        #expect(config.dateFromFilePath("Projects/2026-03-28.md") == nil)
    }

    @Test("Returns nil for non-matching filename format")
    func wrongFormat() {
        let config = DailyNotesConfig(folder: "Daily Notes", dateFormat: "YYYY-MM-DD")
        #expect(config.dateFromFilePath("Daily Notes/some-note.md") == nil)
    }

    @Test("Handles empty folder (root vault)")
    func emptyFolder() {
        let config = DailyNotesConfig(folder: "", dateFormat: "YYYY-MM-DD")
        let date = config.dateFromFilePath("2026-03-28.md")
        #expect(date != nil)
    }

    @Test("Ignores files in subdirectories of daily notes folder")
    func subdirectory() {
        let config = DailyNotesConfig(folder: "Daily Notes", dateFormat: "YYYY-MM-DD")
        #expect(config.dateFromFilePath("Daily Notes/sub/2026-03-28.md") == nil)
    }

    @Test("Converts Moment.js format to Swift format", arguments: [
        ("YYYY-MM-DD", "yyyy-MM-dd"),
        ("YYYY/MM/DD", "yyyy/MM/dd"),
        ("DD-MM-YYYY", "dd-MM-yyyy"),
        ("MMMM DD, YYYY", "MMMM dd, yyyy"),
    ])
    func momentFormatConversion(moment: String, expected: String) {
        let result = DailyNotesConfig.momentToSwiftDateFormat(moment)
        #expect(result == expected)
    }
}
