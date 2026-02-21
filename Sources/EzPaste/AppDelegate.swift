import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var directoryWatcher: DirectoryWatcher?
    private var knownFiles: Set<String> = []
    private var screenshotDirectory: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestNotificationPermission()
        setupMenuBar()
        setupWatcher()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let iconURL = Bundle.main.url(forResource: "ez-paste", withExtension: "png"),
               let icon = NSImage(contentsOf: iconURL) {
                icon.size = NSSize(width: 20, height: 20)
                icon.isTemplate = true
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "ez-paste")
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "ez-paste", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let watchingItem = NSMenuItem(title: "Watching: ...", action: nil, keyEquivalent: "")
        watchingItem.tag = 1
        menu.addItem(watchingItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")

        statusItem.menu = menu
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - File Watching

    private func getScreenshotDirectory() -> String {
        let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        let expanded = custom.map { NSString(string: $0).expandingTildeInPath }
        return expanded ?? (NSHomeDirectory() + "/Desktop")
    }

    private func setupWatcher() {
        screenshotDirectory = getScreenshotDirectory()

        if let menu = statusItem.menu, let item = menu.item(withTag: 1) {
            let shortPath = screenshotDirectory.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            item.title = "Watching: \(shortPath)"
        }

        knownFiles = currentFiles()

        directoryWatcher = DirectoryWatcher(path: screenshotDirectory) { [weak self] in
            self?.checkForNewScreenshots()
        }
    }

    private func currentFiles() -> Set<String> {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: screenshotDirectory)) ?? []
        return Set(files)
    }

    private func checkForNewScreenshots() {
        let current = currentFiles()
        let added = current.subtracting(knownFiles)
        knownFiles = current

        let screenshotPaths = added
            .filter { name in
                let lower = name.lowercased()
                return lower.hasSuffix(".png") && (
                    lower.hasPrefix("screenshot") ||
                    lower.hasPrefix("screen shot")
                )
            }
            .map { screenshotDirectory + "/" + $0 }
            .sorted { a, b in
                let aDate = (try? FileManager.default.attributesOfItem(atPath: a))?[.creationDate] as? Date ?? .distantPast
                let bDate = (try? FileManager.default.attributesOfItem(atPath: b))?[.creationDate] as? Date ?? .distantPast
                return aDate > bDate
            }

        guard let latestPath = screenshotPaths.first else { return }

        // Small delay to ensure the file is fully written to disk
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.copyImageToClipboard(at: latestPath)
        }
    }

    private func copyImageToClipboard(at path: String) {
        guard let image = NSImage(contentsOfFile: path) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        flashStatusIcon()
        sendNotification()
    }

    // MARK: - Feedback

    private func flashStatusIcon() {
        guard let button = statusItem.button else { return }
        let original = button.image
        button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            button.image = original
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Screenshot copied"
        content.body = "Ready to paste into Claude Code"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Directory Watcher

class DirectoryWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let fd: Int32

    init?(path: String, onChange: @escaping () -> Void) {
        fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        source?.setEventHandler(handler: onChange)
        source?.setCancelHandler { [fd] in close(fd) }
        source?.resume()
    }

    deinit {
        source?.cancel()
    }
}
