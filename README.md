待辦 - To be done

## Features

- loading of inline tasks
 - daily note automatic due/scheduled date inference
 - ignore completed tasks (ignore older than a week, ignore undated tasks)
- reload on changes (macos)
- write mode
 - read only, immediate, batched

### Planned features:

- macos, ios, iwatch, app
- widgets everywhere, any kind of supported widget
- counter of pending tasks

## Build

```
xcodebuild -scheme daiban -destination 'platform=macOS' build
```

## Todo
For widgets perhaps we have to use SwiftData
