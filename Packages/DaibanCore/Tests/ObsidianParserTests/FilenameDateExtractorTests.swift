import Foundation
import Testing

@testable import ObsidianParser

@Suite("FilenameDateExtractor")
struct FilenameDateExtractorTests {

    private func utcComponents(from date: Date) -> DateComponents {
        Calendar.current.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
    }

    // MARK: - ISO format (YYYY-MM-DD)

    @Test("Extracts date from YYYY-MM-DD filename")
    func isoFormat() {
        let extractor = FilenameDateExtractor()
        let date = extractor.dateFromFilePath("2026-03-28.md")!
        let c = utcComponents(from: date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 28)
    }

    @Test("Extracts date from YYYY-MM-DD filename in subfolder")
    func isoFormatInFolder() {
        let extractor = FilenameDateExtractor()
        let date = extractor.dateFromFilePath("Daily Notes/2026-03-28.md")!
        let c = utcComponents(from: date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 28)
    }

    // MARK: - Compact format (YYYYMMDD)

    @Test("Extracts date from YYYYMMDD filename")
    func compactFormat() {
        let extractor = FilenameDateExtractor()
        let date = extractor.dateFromFilePath("20260328.md")!
        let c = utcComponents(from: date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 28)
    }

    @Test("YYYYMMDD only matches exact filename")
    func compactFormatExactOnly() {
        let extractor = FilenameDateExtractor()
        #expect(extractor.dateFromFilePath("1202603281.md") == nil)
        #expect(extractor.dateFromFilePath("notes-20260328.md") == nil)
    }

    // MARK: - Additional format

    @Test("Extracts date using additional Moment.js format")
    func additionalFormat() {
        let extractor = FilenameDateExtractor(additionalFormat: "DD-MM-YYYY")
        let date = extractor.dateFromFilePath("28-03-2026.md")!
        let c = utcComponents(from: date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 28)
    }

    @Test("ISO format takes precedence over additional format")
    func isoTakesPrecedence() {
        let extractor = FilenameDateExtractor(additionalFormat: "DD-MM-YYYY")
        let date = extractor.dateFromFilePath("2026-03-28.md")!
        let c = utcComponents(from: date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 28)
    }

    // MARK: - Folder filtering

    @Test("Restricts to specified folders")
    func folderRestriction() {
        let extractor = FilenameDateExtractor(folders: ["Daily Notes"])
        #expect(extractor.dateFromFilePath("Daily Notes/2026-03-28.md") != nil)
        #expect(extractor.dateFromFilePath("Projects/2026-03-28.md") == nil)
        #expect(extractor.dateFromFilePath("2026-03-28.md") == nil)
    }

    @Test("Empty folders allows all")
    func emptyFoldersAllowsAll() {
        let extractor = FilenameDateExtractor(folders: [])
        #expect(extractor.dateFromFilePath("Daily Notes/2026-03-28.md") != nil)
        #expect(extractor.dateFromFilePath("Projects/2026-03-28.md") != nil)
        #expect(extractor.dateFromFilePath("2026-03-28.md") != nil)
    }

    @Test("Supports nested folder paths")
    func nestedFolderPath() {
        let extractor = FilenameDateExtractor(folders: ["Notes/Daily"])
        #expect(extractor.dateFromFilePath("Notes/Daily/2026-03-28.md") != nil)
        #expect(extractor.dateFromFilePath("Notes/2026-03-28.md") == nil)
    }

    // MARK: - No match

    @Test("Returns nil for non-date filename")
    func noDateInFilename() {
        let extractor = FilenameDateExtractor()
        #expect(extractor.dateFromFilePath("meeting-notes.md") == nil)
    }

    @Test("Returns nil for invalid date values")
    func invalidDateValues() {
        let extractor = FilenameDateExtractor()
        #expect(extractor.dateFromFilePath("2026-13-28.md") == nil)
        #expect(extractor.dateFromFilePath("2026-03-32.md") == nil)
    }
}
