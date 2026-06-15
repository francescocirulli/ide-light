import AppKit

final class FileTreeViewController: NSViewController {
    var onFileSelected: ((URL) -> Void)?
    var onRootChanged: ((URL) -> Void)?

    private let rootLabel = NSTextField(labelWithString: "No Folder")
    private let filterField = NSSearchField()
    private let collapseButton = NSButton()
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()

    private var rootNode: FileSystemNode?
    private(set) var showsHiddenAndIgnored = false

    var rootURL: URL? {
        rootNode?.url
    }

    var selectedFileURL: URL? {
        guard
            let item = outlineView.item(atRow: outlineView.selectedRow) as? FileSystemNode,
            !item.isDirectory
        else {
            return nil
        }
        return item.url
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = CodeLightTheme.sidebarBackground.cgColor

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false

        rootLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        rootLabel.textColor = CodeLightTheme.textSecondary
        rootLabel.lineBreakMode = .byTruncatingMiddle
        rootLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rootLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        configureHeaderButton(
            collapseButton,
            symbol: "rectangle.compress.vertical",
            toolTip: "Collapse all folders in sidebar",
            action: #selector(collapseButtonClicked(_:))
        )

        header.addArrangedSubview(rootLabel)
        header.addArrangedSubview(collapseButton)
        view.addSubview(header)

        filterField.placeholderString = "Filter files"
        filterField.sendsSearchStringImmediately = true
        filterField.target = self
        filterField.action = #selector(filterChanged(_:))
        filterField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterField)

        let column = NSTableColumn(identifier: .fileTreeColumn)
        column.title = "Files"
        column.resizingMask = .autoresizingMask

        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .small
        outlineView.style = .sourceList
        outlineView.backgroundColor = CodeLightTheme.sidebarBackground
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.doubleAction = #selector(doubleClickedRow(_:))

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = outlineView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.heightAnchor.constraint(equalToConstant: 28),

            collapseButton.widthAnchor.constraint(equalToConstant: 24),
            collapseButton.heightAnchor.constraint(equalToConstant: 24),

            filterField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            filterField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            filterField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            filterField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: filterField.bottomAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setRoot(_ url: URL) {
        rootNode = FileSystemNode(url: url, showsHiddenAndIgnored: showsHiddenAndIgnored)
        rootLabel.stringValue = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        outlineView.reloadData()
        onRootChanged?(url)
    }

    func setShowsHiddenAndIgnored(_ value: Bool) {
        showsHiddenAndIgnored = value
        rootNode?.resetVisibility(value)
        outlineView.reloadData()
    }

    func collapseAll() {
        guard outlineView.numberOfRows > 0 else { return }

        for row in stride(from: outlineView.numberOfRows - 1, through: 0, by: -1) {
            guard let item = outlineView.item(atRow: row), outlineView.isItemExpanded(item) else { continue }
            outlineView.collapseItem(item, collapseChildren: true)
        }
    }

    @objc private func doubleClickedRow(_ sender: Any?) {
        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FileSystemNode else { return }

        if node.isDirectory {
            outlineView.isItemExpanded(node) ? outlineView.collapseItem(node) : outlineView.expandItem(node)
        } else {
            onFileSelected?(node.url)
        }
    }

    @objc private func filterChanged(_ sender: NSSearchField) {
        reloadForFilter()
    }

    @objc private func collapseButtonClicked(_ sender: Any?) {
        collapseAll()
    }

    private func reloadForFilter() {
        outlineView.reloadData()
        if !filterQuery.isEmpty {
            outlineView.expandItem(nil, expandChildren: true)
        }
    }

    private var filterQuery: String {
        filterField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func displayedChildren(for item: Any?) -> [FileSystemNode] {
        guard let node = (item as? FileSystemNode) ?? rootNode else {
            return []
        }
        node.loadChildrenIfNeeded()
        return node.children.filter { shouldDisplay($0) }
    }

    private func shouldDisplay(_ node: FileSystemNode) -> Bool {
        let query = filterQuery

        guard !query.isEmpty else {
            return true
        }

        if node.name.lowercased().contains(query) || node.url.path.lowercased().contains(query) {
            return true
        }

        guard node.isDirectory else {
            return false
        }

        node.loadChildrenIfNeeded()
        return node.children.contains { shouldDisplay($0) }
    }

    private func configureHeaderButton(_ button: NSButton, symbol: String, toolTip: String, action: Selector) {
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip)
        button.toolTip = toolTip
        button.contentTintColor = CodeLightTheme.textSecondary
        button.target = self
        button.action = action
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
    }
}

extension FileTreeViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        displayedChildren(for: item).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        displayedChildren(for: item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileSystemNode)?.isDirectory == true
    }
}

extension FileTreeViewController: NSOutlineViewDelegate {
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard
            let node = outlineView.item(atRow: outlineView.selectedRow) as? FileSystemNode,
            !node.isDirectory
        else {
            return
        }
        onFileSelected?(node.url)
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        guard let node = item as? FileSystemNode else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("FileTreeCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? FileTreeCell ?? FileTreeCell()
        cell.identifier = identifier
        cell.configure(with: node)
        return cell
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        shouldSelectItem item: Any
    ) -> Bool {
        true
    }
}

private final class FileTreeCell: NSTableCellView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor
        addSubview(iconView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = CodeLightTheme.textPrimary
        label.lineBreakMode = .byTruncatingMiddle
        addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with node: FileSystemNode) {
        imageView = iconView
        textField = label
        label.stringValue = node.name
        iconView.image = node.isDirectory
            ? NSImage(systemSymbolName: "folder", accessibilityDescription: "Folder")
            : NSWorkspace.shared.icon(forFile: node.url.path)
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let fileTreeColumn = NSUserInterfaceItemIdentifier("FileTreeColumn")
}
