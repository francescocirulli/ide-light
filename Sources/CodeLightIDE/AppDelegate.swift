import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var pendingOpenRequests: [OpenRequest] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        configureMenus()

        let controller = MainWindowController()
        mainWindowController = controller
        controller.showWindow(nil)

        if pendingOpenRequests.isEmpty {
            openLaunchArgumentIfPresent()
        } else {
            openRequests(pendingOpenRequests)
            pendingOpenRequests.removeAll()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openRequests([OpenRequest(url: URL(fileURLWithPath: filename))])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        openRequests(filenames.map { OpenRequest(url: URL(fileURLWithPath: $0)) })
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let requests = urls.compactMap { url -> OpenRequest? in
            if url.scheme == "code-light" {
                return OpenRequest.parseCustomURL(url)
            }
            return OpenRequest(url: url)
        }
        openRequests(requests)
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

    @objc private func copyFileReference(_ sender: Any?) {
        mainWindowController?.copyFileReference()
    }

    @objc private func copySelectionAsAgentContext(_ sender: Any?) {
        mainWindowController?.copySelectionAsAgentContext()
    }

    @objc private func copyWorkspaceContext(_ sender: Any?) {
        mainWindowController?.copyWorkspaceContext()
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard
            let value = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: value),
            let request = OpenRequest.parseCustomURL(url)
        else {
            return
        }
        openRequests([request])
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

        editMenu.addItem(.separator())

        let copyFileReference = NSMenuItem(
            title: "Copy File Reference",
            action: #selector(copyFileReference(_:)),
            keyEquivalent: "c"
        )
        copyFileReference.keyEquivalentModifierMask = [.command, .option]
        copyFileReference.target = self
        editMenu.addItem(copyFileReference)

        let copySelectionContext = NSMenuItem(
            title: "Copy Selection as Agent Context",
            action: #selector(copySelectionAsAgentContext(_:)),
            keyEquivalent: "c"
        )
        copySelectionContext.keyEquivalentModifierMask = [.command, .shift]
        copySelectionContext.target = self
        editMenu.addItem(copySelectionContext)

        let copyWorkspaceContext = NSMenuItem(
            title: "Copy Workspace Context",
            action: #selector(copyWorkspaceContext(_:)),
            keyEquivalent: "c"
        )
        copyWorkspaceContext.keyEquivalentModifierMask = [.command, .shift, .option]
        copyWorkspaceContext.target = self
        editMenu.addItem(copyWorkspaceContext)

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
        let requests = CommandLine.arguments.dropFirst().compactMap(OpenRequest.parse)
        openRequests(requests)
    }

    private func openRequests(_ requests: [OpenRequest]) {
        guard let firstRequest = requests.first else { return }

        guard mainWindowController != nil else {
            pendingOpenRequests.append(contentsOf: requests)
            return
        }

        var isDirectory: ObjCBool = false
        let path = firstRequest.url.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return }

        if isDirectory.boolValue {
            mainWindowController?.openWorkspace(firstRequest.url)
        } else {
            mainWindowController?.openWorkspace(
                firstRequest.url.deletingLastPathComponent(),
                selectedFile: firstRequest.url,
                selectedLine: firstRequest.line
            )
        }
    }
}
