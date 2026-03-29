import Foundation

#if os(macOS)
import CoreServices

/// Watches a directory tree for file changes using FSEvents (macOS only).
final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let callback: () -> Void
    private let debounceInterval: TimeInterval

    private var debounceWorkItem: DispatchWorkItem?

    init(debounceInterval: TimeInterval = 0.5, callback: @escaping () -> Void) {
        self.debounceInterval = debounceInterval
        self.callback = callback
    }

    deinit {
        stop()
    }

    func watch(directory: URL) {
        stop()

        let path = directory.path as CFString
        var context = FSEventStreamContext()

        // Store a raw pointer to self for the C callback
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latency in seconds
            flags
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    fileprivate func handleEvent() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.callback()
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}

private func fsEventCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientInfo else { return }
    let watcher = Unmanaged<FileWatcher>.fromOpaque(clientInfo).takeUnretainedValue()

    // Only trigger on .md file changes
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
    let hasMdChange = paths.contains { $0.hasSuffix(".md") }
    if hasMdChange {
        watcher.handleEvent()
    }
}

#else

/// No-op file watcher for platforms without FSEvents (iOS, visionOS).
final class FileWatcher {
    init(debounceInterval: TimeInterval = 0.5, callback: @escaping () -> Void) {}
    func watch(directory: URL) {}
    func stop() {}
}

#endif
