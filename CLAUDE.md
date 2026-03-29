# Daiban - Obsidian Task Viewer

## Project Overview
macOS (later iOS/watchOS) app that parses Obsidian vault markdown files and displays tasks. Uses Obsidian Tasks plugin format.

## Architecture
- **Xcode project**: `daiban/daiban.xcodeproj` (multiplatform: macOS, iOS, visionOS)
- **Shared Swift Package**: `daiban/Packages/DaibanCore/`
  - `ObsidianParser` module: models, parser, writer, vault scanner
- **App code**: `daiban/daiban/` (SwiftUI views, VaultStore)
- Uses `@Observable` (macOS 14+ / iOS 17+), Swift Testing for tests
- No SwiftData yet — in-memory parsing, will add later for widgets/watchOS

## Key Files
- `ObsidianTask.swift` - TaskStatus, TaskPriority, RecurrenceRule, ObsidianTask models
- `TaskParser.swift` - Parses markdown lines into ObsidianTask (emoji-based fields)
- `TaskWriter.swift` - Toggle completion, write back to .md files
- `VaultScanner.swift` - Walks vault directory, parses all .md files
- `VaultStore.swift` - @Observable store, folder picker (NSOpenPanel), bookmark persistence
- `ContentView.swift` - Main UI with sidebar, grouping, search, task list
- `TaskRowView.swift` - Individual task row with completion toggle

## Obsidian Tasks Plugin Format
Emojis: 📅 due, ⏳ scheduled, 🛫 start, ➕ created, ✅ done, 🔁 recurrence
Priority: 🔺 highest, ⏫ high, 🔼 medium, normal, 🔽 low, ⏬ lowest
Status: [ ] todo, [x] done, [-] cancelled, [/] in-progress

## Build
- `xcodebuild -scheme daiban -destination 'platform=macOS' build`
- Package tests: `cd daiban/Packages/DaibanCore && swift test`
- Regex literals use `#/.../#` extended delimiters (emojis break bare `/.../ `)

## Naming
- App struct renamed to `DaibanApp` (was lowercase `daibanApp` from Xcode template)
