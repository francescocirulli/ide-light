import AppKit

final class MainWindowController: NSWindowController {
    private let fileTreeController = FileTreeViewController()
    private let codeViewerController = CodeViewerController()
    private var quickOpenController: QuickOpenController?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Code Light"
        window.minSize = NSSize(width: 860, height: 540)
        window.isReleasedWhenClosed = false

        super.init(window: window)

        let splitController = NSSplitViewController()
        splitController.splitView.isVertical = true
        splitController.splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: fileTreeController)
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 420
        sidebarItem.canCollapse = false

        let codeItem = NSSplitViewItem(viewController: codeViewerController)
        codeItem.minimumThickness = 520

        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(codeItem)

        window.contentViewController = splitController
        window.toolbar = buildToolbar()
        window.center()

        fileTreeController.onFileSelected = { [weak self] url in
            self?.codeViewerController.open(url)
        }
        fileTreeController.onRootChanged = { [weak self] url in
            self?.window?.subtitle = url.path
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.title = "Open Folder"
        panel.prompt = "Open"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        guard let window else { return }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openWorkspace(url)
        }
    }

    func openWorkspace(_ url: URL, selectedFile: URL? = nil, selectedLine: Int? = nil) {
        fileTreeController.setRoot(url)
        window?.subtitle = url.path

        if let selectedFile {
            codeViewerController.open(selectedFile, line: selectedLine)
        } else {
            codeViewerController.showWorkspaceReady(url)
        }
    }

    func reloadSelection() {
        if let selectedFile = fileTreeController.selectedFileURL {
            codeViewerController.open(selectedFile)
        } else if let root = fileTreeController.rootURL {
            fileTreeController.setRoot(root)
        }
    }

    func focusFind() {
        codeViewerController.focusFind()
    }

    func quickOpen() {
        guard let root = fileTreeController.rootURL, let window else {
            openFolder()
            return
        }

        let items = FileIndex.files(
            under: root,
            showsHiddenAndIgnored: fileTreeController.showsHiddenAndIgnored
        )

        let controller = QuickOpenController(items: items)
        quickOpenController = controller
        controller.onOpen = { [weak self] url in
            self?.codeViewerController.open(url)
        }
        controller.show(attachedTo: window)
    }

    func collapseSidebar() {
        fileTreeController.collapseAll()
    }

    func setShowsHiddenAndIgnored(_ value: Bool) {
        fileTreeController.setShowsHiddenAndIgnored(value)
    }

    func copyFileReference() {
        codeViewerController.copyFileReference()
    }

    func copySelectionAsAgentContext() {
        codeViewerController.copySelectionAsAgentContext()
    }

    func copyWorkspaceContext() {
        codeViewerController.copyWorkspaceContext()
    }

    @objc private func openFolderFromToolbar(_ sender: Any?) {
        openFolder()
    }

    @objc private func reloadFromToolbar(_ sender: Any?) {
        reloadSelection()
    }

    private func buildToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "CodeLightToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.delegate = self
        return toolbar
    }
}

extension MainWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.openFolder, .quickOpen, .reloadSelection, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.openFolder, .quickOpen, .reloadSelection, .flexibleSpace]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .openFolder:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Open Folder"
            item.paletteLabel = "Open Folder"
            item.toolTip = "Open a project folder"
            item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open Folder")
            item.target = self
            item.action = #selector(openFolderFromToolbar(_:))
            return item
        case .reloadSelection:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Reload"
            item.paletteLabel = "Reload"
            item.toolTip = "Reload the selected file or folder"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
            item.target = self
            item.action = #selector(reloadFromToolbar(_:))
            return item
        case .quickOpen:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Quick Open"
            item.paletteLabel = "Quick Open"
            item.toolTip = "Quick open a file"
            item.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Quick Open")
            item.target = self
            item.action = #selector(quickOpenFromToolbar(_:))
            return item
        default:
            return nil
        }
    }

    @objc private func quickOpenFromToolbar(_ sender: Any?) {
        quickOpen()
    }
}

private extension NSToolbarItem.Identifier {
    static let openFolder = NSToolbarItem.Identifier("OpenFolder")
    static let quickOpen = NSToolbarItem.Identifier("QuickOpen")
    static let reloadSelection = NSToolbarItem.Identifier("ReloadSelection")
}
