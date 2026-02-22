import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private let monitor = ClipboardMonitor()
    private var isActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let iconURL = Bundle.main.url(forResource: "ez-paste", withExtension: "png"),
               let icon = NSImage(contentsOf: iconURL) {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            } else {
                button.title = "EP"
            }
        }

        let menu = NSMenu()

        toggleItem = NSMenuItem(title: "Monitoring", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let openFolderItem = NSMenuItem(title: "Open Screenshots Folder", action: #selector(openScreenshotsFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit EzPaste", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu

        startMonitoring()
    }

    @objc private func toggle() {
        if isActive { stopMonitoring() } else { startMonitoring() }
    }

    @objc private func openScreenshotsFolder() {
        NSWorkspace.shared.open(monitor.screenshotDir)
    }

    private func startMonitoring() {
        isActive = true
        toggleItem.state = .on
        monitor.start()
    }

    private func stopMonitoring() {
        isActive = false
        toggleItem.state = .off
        monitor.stop()
    }
}

// MARK: - Clipboard Monitor

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    let screenshotDir: URL

    var onSave: ((URL) -> Void)?

    init() {
        let pictures = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
            .appendingPathComponent("ClipboardScreenshots")
        screenshotDir = pictures
        try? FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        let current = pb.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        let types = pb.types ?? []
        let hasImage = types.contains(.tiff) || types.contains(.png)
        let hasFileURL = types.contains(.fileURL)

        if hasImage && !hasFileURL {
            convertToFile()
        }
    }

    private func convertToFile() {
        let pb = NSPasteboard.general

        guard let tiffData = pb.data(forType: .tiff),
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let filename = "screenshot_\(formatter.string(from: Date())).png"
        let fileURL = screenshotDir.appendingPathComponent(filename)

        do {
            try pngData.write(to: fileURL)
        } catch {
            NSLog("EzPaste: failed to save – \(error)")
            return
        }

        writeFileToClipboard(fileURL: fileURL, tiffData: tiffData)

        let url = fileURL
        let tiff = tiffData
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.verifyAndRewrite(fileURL: url, tiffData: tiff)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.verifyAndRewrite(fileURL: url, tiffData: tiff)
        }

        NSLog("EzPaste: saved %@", fileURL.path)
    }

    private func writeFileToClipboard(fileURL: URL, tiffData: Data) {
        let pb = NSPasteboard.general
        let filenameType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

        pb.clearContents()
        pb.declareTypes([.string, .fileURL, filenameType, .tiff], owner: nil)
        pb.setString(fileURL.path, forType: .string)
        pb.setString(fileURL.absoluteString, forType: .fileURL)
        pb.setPropertyList([fileURL.path], forType: filenameType)
        pb.setData(tiffData, forType: .tiff)

        lastChangeCount = pb.changeCount
        NSLog("EzPaste: wrote clipboard (changeCount=%d)", pb.changeCount)
    }

    private func verifyAndRewrite(fileURL: URL, tiffData: Data) {
        let pb = NSPasteboard.general
        let types = pb.types ?? []

        if !types.contains(.fileURL) {
            NSLog("EzPaste: clipboard was overwritten, rewriting")
            writeFileToClipboard(fileURL: fileURL, tiffData: tiffData)
        } else {
            lastChangeCount = pb.changeCount
        }
    }
}
