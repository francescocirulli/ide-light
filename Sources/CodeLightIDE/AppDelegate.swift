import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var pendingOpenURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenus()

        let controller = MainWindowController()
        mainWindowController = controller
        controller.showWindow(nil)

        if pendingOpenURLs.isEmpty {
            openLaunchArgumentIfPresent()
        } else {
            openURLs(pendingOpenURLs)
            pendingOpenURLs.removeAll()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openURLs([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        openURLs(filenames.map(URL.init(fileURLWithPath:)))
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openURLs(urls)
    }

    @objc private func openFolder(_ sender: Any?) {
        mainWindowController?.openFolder()
    }

    @objc private func reloadSelection(_ sender: Any?) {
        mainWindowController?.reloadSelection()
    }

    @objc private func focusFind(_ sender: Any?) {
        mainWindowController?.focusFind()
    }

    @objc private func quickOpen(_ sender: Any?) {
        mainWindowController?.quickOpen()
    }

    @objc private func collapseAll(_ sender: Any?) {
        mainWindowController?.collapseSidebar()
    }

    @objc private func toggleHiddenFiles(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        mainWindowController?.setShowsHiddenAndIgnored(sender.state == .on)
    }

    private func configureMenus() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About Code Light",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Code Light",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)

        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let open = NSMenuItem(
            title: "Open Folder...",
            action: #selector(openFolder(_:)),
            keyEquivalent: "o"
        )
        open.target = self
        fileMenu.addItem(open)

        let quickOpen = NSMenuItem(
            title: "Quick Open...",
            action: #selector(quickOpen(_:)),
            keyEquivalent: "p"
        )
        quickOpen.target = self
        fileMenu.addItem(quickOpen)

        let reload = NSMenuItem(
            title: "Reload Selected File",
            action: #selector(reloadSelection(_:)),
            keyEquivalent: "r"
        )
        reload.target = self
        fileMenu.addItem(reload)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(
            withTitle: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        let find = NSMenuItem(
            title: "Find",
            action: #selector(focusFind(_:)),
            keyEquivalent: "f"
        )
        find.target = self
        editMenu.addItem(find)

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)

        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let showHidden = NSMenuItem(
            title: "Show Hidden and Vendor Folders",
            action: #selector(toggleHiddenFiles(_:)),
            keyEquivalent: "."
        )
        showHidden.target = self
        viewMenu.addItem(showHidden)

        let collapseAll = NSMenuItem(
            title: "Collapse Sidebar",
            action: #selector(collapseAll(_:)),
            keyEquivalent: ""
        )
        collapseAll.target = self
        viewMenu.addItem(collapseAll)
    }

    private func openLaunchArgumentIfPresent() {
        guard let argument = CommandLine.arguments.dropFirst().first else { return }

        var isDirectory: ObjCBool = false
        let expandedPath = NSString(string: argument).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else { return }

        let url = URL(fileURLWithPath: expandedPath)
        if isDirectory.boolValue {
            mainWindowController?.openWorkspace(url)
        } else {
            mainWindowController?.openWorkspace(url.deletingLastPathComponent(), selectedFile: url)
        }
    }

    private func openURLs(_ urls: [URL]) {
        guard let firstURL = urls.first else { return }

        guard mainWindowController != nil else {
            pendingOpenURLs.append(contentsOf: urls)
            return
        }

        var isDirectory: ObjCBool = false
        let path = firstURL.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return }

        if isDirectory.boolValue {
            mainWindowController?.openWorkspace(firstURL)
        } else {
            mainWindowController?.openWorkspace(firstURL.deletingLastPathComponent(), selectedFile: firstURL)
        }
    }
}
