import AppKit

final class QuickOpenController: NSWindowController {
    var onOpen: ((URL) -> Void)?

    private let searchField = FindSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")

    private let allItems: [FileIndexItem]
    private var visibleItems: [FileIndexItem] = []

    init(items: [FileIndexItem]) {
        self.allItems = items

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 430),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Quick Open"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true

        super.init(window: panel)
        buildUI()
        updateResults()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(attachedTo parent: NSWindow) {
        guard let window else { return }
        parent.beginSheet(window) { _ in }
        window.makeFirstResponder(searchField)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = CodeLightTheme.elevatedBackground.cgColor

        searchField.placeholderString = "Open file by name or path"
        searchField.sendsSearchStringImmediately = true
        searchField.font = .systemFont(ofSize: 16)
        searchField.onEnter = { [weak self] in self?.openSelected() }
        searchField.onEscape = { [weak self] in self?.closeSheet() }
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)

        let column = NSTableColumn(identifier: .quickOpenColumn)
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.backgroundColor = CodeLightTheme.elevatedBackground
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClicked(_:))

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = CodeLightTheme.elevatedBackground
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = CodeLightTheme.textMuted
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            searchField.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 12),
            searchField.heightAnchor.constraint(equalToConstant: 34),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        updateResults()
    }

    @objc private func doubleClicked(_ sender: Any?) {
        openSelected()
    }

    private func updateResults() {
        visibleItems = FileIndex.matches(searchField.stringValue, in: allItems)
        tableView.reloadData()
        if !visibleItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        statusLabel.stringValue = "\(visibleItems.count) shown from \(allItems.count) files - Enter opens, Esc closes"
    }

    private func openSelected() {
        let selected = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        guard visibleItems.indices.contains(selected) else { return }
        let url = visibleItems[selected].url
        closeSheet()
        onOpen?(url)
    }

    private func closeSheet() {
        guard let window, let sheetParent = window.sheetParent else {
            close()
            return
        }
        sheetParent.endSheet(window)
    }
}

extension QuickOpenController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard visibleItems.indices.contains(row) else { return nil }
        let item = visibleItems[row]
        let identifier = NSUserInterfaceItemIdentifier("QuickOpenCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? QuickOpenCell ?? QuickOpenCell()
        cell.identifier = identifier
        cell.configure(with: item)
        return cell
    }
}

private final class QuickOpenCell: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = CodeLightTheme.textSecondary
        addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = CodeLightTheme.textPrimary
        titleLabel.lineBreakMode = .byTruncatingMiddle

        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = CodeLightTheme.textMuted
        pathLabel.lineBreakMode = .byTruncatingMiddle

        let stack = NSStackView(views: [titleLabel, pathLabel])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            stack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: FileIndexItem) {
        iconView.image = NSWorkspace.shared.icon(forFile: item.url.path)
        titleLabel.stringValue = item.fileName
        pathLabel.stringValue = item.relativePath
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let quickOpenColumn = NSUserInterfaceItemIdentifier("QuickOpenColumn")
}
