import AppKit
import Carbon
import Foundation

struct LauncherItem {
    let title: String
    let subtitle: String
    let action: () -> Void
}

final class HotKey {
    private var ref: EventHotKeyRef?
    var onPress: (() -> Void)?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            hotKey.onPress?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        let signature = OSType(UInt32(ascii: "SoLi"))
        let id = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(cmdKey), id, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
    }
}

final class AppIndex {
    private static let configURL = URL(fileURLWithPath: NSString(string: "~/.config/sol/config.json").expandingTildeInPath)
    private static let scriptsURL = URL(fileURLWithPath: NSString(string: "~/.config/sol/scripts").expandingTildeInPath)
    private var apps: [LauncherItem] = []

    init() {
        reload()
    }

    func reload() {
        apps = utilityItems() + quickLinkItems() + scriptItems() + applicationItems()
    }

    func search(_ query: String) -> [LauncherItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Array(apps.prefix(30)) }
        let lower = trimmed.lowercased()
        return apps.filter { item in
            item.title.lowercased().contains(lower) || item.subtitle.lowercased().contains(lower)
        }.prefix(30).map { $0 }
    }

    private func applicationItems() -> [LauncherItem] {
        let roots = ["/Applications", "/System/Applications", NSString(string: "~/Applications").expandingTildeInPath]
        let keys: [URLResourceKey] = [.isDirectoryKey, .localizedNameKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

        var items: [LauncherItem] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: keys, options: options) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "app" {
                let values = try? url.resourceValues(forKeys: Set(keys))
                let name = values?.localizedName ?? url.deletingPathExtension().lastPathComponent
                items.append(LauncherItem(title: name, subtitle: url.path) {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                })
            }
        }
        return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func scriptItems() -> [LauncherItem] {
        let scriptsDir = Self.scriptsURL
        guard let urls = try? FileManager.default.contentsOfDirectory(at: scriptsDir, includingPropertiesForKeys: nil) else { return [] }
        return urls.filter { ["sh", "applescript", "scpt"].contains($0.pathExtension) }.map { url in
            let title = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
            return LauncherItem(title: title, subtitle: url.path) {
                if url.pathExtension == "sh" {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    process.arguments = [url.path]
                    try? process.run()
                } else {
                    NSAppleScript(contentsOf: url, error: nil)?.executeAndReturnError(nil)
                }
            }
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func quickLinkItems() -> [LauncherItem] {
        guard let data = try? Data(contentsOf: Self.configURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let shortcutURLs = (object["shortcuts"] as? [String: Any] ?? [:]).keys
        let customURLs = (object["customItems"] as? [[String: Any]] ?? []).compactMap { item in
            item["url"] as? String ?? item["path"] as? String
        }
        return (Array(shortcutURLs) + customURLs).compactMap { raw in
            guard raw.hasPrefix("file://") || raw.hasPrefix("http://") || raw.hasPrefix("https://") else { return nil }
            guard let url = URL(string: raw) else { return nil }
            let title = url.isFileURL ? url.deletingPathExtension().lastPathComponent : (url.host ?? raw)
            return LauncherItem(title: title, subtitle: raw) {
                NSWorkspace.shared.open(url)
            }
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func utilityItems() -> [LauncherItem] {
        [
            LauncherItem(title: "Empty Trash", subtitle: "Permanently empty the Trash") {
                NSAppleScript(source: "tell application \"Finder\" to empty trash")?.executeAndReturnError(nil)
            },
            LauncherItem(title: "Copy Wi-Fi Password", subtitle: "Copy current network password to clipboard") {
                Self.copyCurrentWiFiPassword()
            },
            LauncherItem(title: "Kill Process", subtitle: "Open process killer", action: ProcessKiller.show),
            LauncherItem(title: "Settings", subtitle: Self.configURL.path, action: SettingsWindow.show),
            LauncherItem(title: "Scripts Folder", subtitle: Self.scriptsURL.path) { NSWorkspace.shared.open(Self.scriptsURL) },
            LauncherItem(title: "Reload Index", subtitle: "Refresh apps and scripts") { [weak self] in self?.reload() }
        ]
    }

    private static func copyCurrentWiFiPassword() {
        let network = shell("/usr/sbin/networksetup", ["-getairportnetwork", "en0"])
            .replacingOccurrences(of: "Current Wi-Fi Network: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !network.isEmpty else { return }
        let password = shell("/usr/bin/security", ["find-generic-password", "-wa", network])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !password.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(password, forType: .string)
    }

    private static func shell(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return "" }
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

enum Style {
    static let background = NSColor(calibratedWhite: 0, alpha: 0.86)
    static let row = NSColor(calibratedWhite: 1, alpha: 0.06)
    static let text = NSColor(calibratedWhite: 0.96, alpha: 1)

    static func apply(to window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = background
        window.titlebarAppearsTransparent = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = background.cgColor
        window.contentView?.layer?.cornerRadius = 18
    }
}

final class LauncherPanel: NSWindowController, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let searchField = NSSearchField(frame: .zero)
    private let tableView = NSTableView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)
    private var items: [LauncherItem] = []
    private var eventMonitor: Any?
    var onQuery: ((String) -> [LauncherItem])?
    var onOpen: ((LauncherItem) -> Void)?

    init() {
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 680, height: 420), styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        Style.apply(to: window)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        buildUI()
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func toggle() {
        guard let window else { return }
        if window.isVisible { hide(); return }
        center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        searchField.becomeFirstResponder()
        refresh()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers == .command, event.keyCode == 0 {
                self.searchField.selectText(nil)
                return nil
            }
            if modifiers == .command, event.keyCode == 43 {
                SettingsWindow.show()
                return nil
            }
            switch event.keyCode {
            case 36:
                self.openSelection()
                return nil
            case 53:
                self.hide()
                return nil
            case 125:
                self.moveSelection(by: 1)
                return nil
            case 126:
                self.moveSelection(by: -1)
                return nil
            default:
                return event
            }
        }
    }

    func hide() {
        window?.orderOut(nil)
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        searchField.delegate = self
        searchField.placeholderString = "Search apps, scripts, quick links"
        searchField.textColor = Style.text
        searchField.target = self
        searchField.action = #selector(queryChanged)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.title = "Item"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelection)
        tableView.rowHeight = 44
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        scrollView.drawsBackground = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true

        let stack = NSStackView(views: [searchField, scrollView])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            searchField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func center() {
        guard let window, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = CGPoint(x: frame.midX - window.frame.width / 2, y: frame.maxY - window.frame.height - 90)
        window.setFrameOrigin(origin)
    }

    @objc private func queryChanged() { refresh() }

    private func refresh() {
        items = onQuery?(searchField.stringValue) ?? []
        tableView.reloadData()
        if !items.isEmpty { tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
    }

    @objc private func openSelection() {
        let row = tableView.selectedRow
        guard items.indices.contains(row) else { return }
        onOpen?(items[row])
    }

    private func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let nextRow = min(max(selectedRow + delta, 0), items.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let icon = NSImageView(frame: .zero)
        icon.image = itemIcon(for: items[row])
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: items[row].title)
        title.font = .systemFont(ofSize: 15, weight: .medium)
        title.textColor = Style.text

        let stack = NSStackView(views: [icon, title])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private func itemIcon(for item: LauncherItem) -> NSImage {
        if item.subtitle.hasSuffix(".app") {
            return NSWorkspace.shared.icon(forFile: item.subtitle)
        }
        if item.subtitle.hasSuffix(".sh") || item.subtitle.hasSuffix(".applescript") || item.subtitle.hasSuffix(".scpt") {
            return NSWorkspace.shared.icon(for: .unixExecutable)
        }
        return NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: nil) ?? NSImage()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36: openSelection()
        case 53: hide()
        case 125: moveSelection(by: 1)
        case 126: moveSelection(by: -1)
        default:
            super.keyDown(with: event)
        }
    }
}

final class SettingsWindow: NSObject, NSWindowDelegate {
    private static var current: SettingsWindow?
    private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 180), styleMask: [.titled, .closable], backing: .buffered, defer: false)

    static func show() {
        if let current {
            current.show()
            return
        }
        current = SettingsWindow()
        current?.show()
    }

    private override init() {
        super.init()
        window.title = "Settings"
        window.delegate = self
        Style.apply(to: window)

        let configButton = NSButton(title: "Open config.json", target: self, action: #selector(openConfig))
        let scriptsButton = NSButton(title: "Open scripts folder", target: self, action: #selector(openScripts))
        let stack = NSStackView(views: [configButton, scriptsButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
            ])
        }
    }

    private func show() {
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSString(string: "~/.config/sol/config.json").expandingTildeInPath))
    }

    @objc private func openScripts() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSString(string: "~/.config/sol/scripts").expandingTildeInPath))
    }

    func windowWillClose(_ notification: Notification) { Self.current = nil }
}

final class ProcessKiller: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private static var current: ProcessKiller?
    private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 460), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    private let searchField = NSSearchField(frame: .zero)
    private let tableView = NSTableView(frame: .zero)
    private var eventMonitor: Any?
    private var rows: [(pid: Int32, command: String)] = []
    private var filteredRows: [(pid: Int32, command: String)] = []

    static func show() {
        current = ProcessKiller()
        current?.show()
    }

    private override init() {
        super.init()
        rows = Self.processes()
        filteredRows = rows
        window.title = "Kill Process"
        window.delegate = self
        Style.apply(to: window)

        searchField.delegate = self
        searchField.placeholderString = "Search processes"
        searchField.textColor = Style.text
        searchField.target = self
        searchField.action = #selector(queryChanged)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("process"))
        column.title = "Process"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(killSelection)
        tableView.rowHeight = 44
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular

        let scroll = NSScrollView(frame: .zero)
        scroll.drawsBackground = false
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true

        let stack = NSStackView(views: [searchField, scroll])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
                searchField.heightAnchor.constraint(equalToConstant: 36)
            ])
        }
    }

    private func show() {
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        searchField.becomeFirstResponder()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers == .command, event.keyCode == 0 {
                self.searchField.selectText(nil)
                return nil
            }
            switch event.keyCode {
            case 36:
                self.killSelection()
                return nil
            case 53:
                self.window.close()
                return nil
            case 125:
                self.moveSelection(by: 1)
                return nil
            case 126:
                self.moveSelection(by: -1)
                return nil
            default:
                return event
            }
        }
    }

    private static func processes() -> [(Int32, String)] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,comm="]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let space = trimmed.firstIndex(of: " "), let pid = Int32(trimmed[..<space]) else { return nil }
            let command = String(trimmed[space...]).trimmingCharacters(in: .whitespaces)
            return (pid, command)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { filteredRows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let icon = NSImageView(frame: .zero)
        let process = filteredRows[row]
        icon.image = NSWorkspace.shared.icon(forFile: process.command)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: Self.processName(from: process.command))
        title.font = .systemFont(ofSize: 15, weight: .medium)
        title.textColor = Style.text

        let stack = NSStackView(views: [icon, title])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private static func processName(from command: String) -> String {
        URL(fileURLWithPath: command).deletingPathExtension().lastPathComponent
    }

    @objc private func queryChanged() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        filteredRows = query.isEmpty ? rows : rows.filter { row in
            Self.processName(from: row.command).localizedCaseInsensitiveContains(query)
        }
        tableView.reloadData()
        if !filteredRows.isEmpty { tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
    }

    private func moveSelection(by delta: Int) {
        guard !filteredRows.isEmpty else { return }
        let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let nextRow = min(max(selectedRow + delta, 0), filteredRows.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
    }

    @objc private func killSelection() {
        let row = tableView.selectedRow
        guard filteredRows.indices.contains(row) else { return }
        kill(filteredRows[row].pid, SIGTERM)
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        Self.current = nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKey = HotKey()
    private let panel = LauncherPanel()
    private let index = AppIndex()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hotKey.onPress = { [weak self] in self?.panel.toggle() }
        panel.onQuery = { [weak self] query in self?.index.search(query) ?? [] }
        panel.onOpen = { [weak self] item in item.action(); self?.panel.hide() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        panel.hide()
        return .terminateCancel
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

private extension UInt32 {
    init(ascii: String) {
        self = ascii.utf8.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
