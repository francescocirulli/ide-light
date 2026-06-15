import AppKit

final class CodeViewerController: NSViewController {
    private let titleLabel = NSTextField(labelWithString: "Open a folder to begin")
    private let pathLabel = NSTextField(labelWithString: "Read-only, fast-loading source browser")
    private let metadataLabel = NSTextField(labelWithString: "")
    private let languageBadge = NSTextField(labelWithString: "")
    private let copyPathButton = NSButton()
    private let searchField = FindSearchField()
    private let matchCountLabel = NSTextField(labelWithString: "")
    private let previousMatchButton = NSButton()
    private let nextMatchButton = NSButton()
    private let closeFindButton = NSButton()
    private let recentStack = NSStackView()
    private var workspaceURL: URL?
    private let scrollView: NSScrollView
    private let textView: NSTextView
    private let emptyState = NSTextField(labelWithString: "Open a folder, then select a file.")

    private let loadQueue = DispatchQueue(label: "CodeLight.FileLoad", qos: .userInitiated)
    private var currentLoadID = UUID()
    private var currentURL: URL?
    private var currentLanguage: Language = .plain
    private var currentText = ""
    private var searchMatches: [NSRange] = []
    private var selectedSearchMatch = -1
    private var recentFiles: [URL] = []

    init() {
        let editor = Self.makeScrollableTextView()
        scrollView = editor.scrollView
        textView = editor.textView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = CodeLightTheme.editorBackground.cgColor

        let header = NSView()
        header.wantsLayer = true
        header.layer?.backgroundColor = CodeLightTheme.headerBackground.cgColor
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = CodeLightTheme.textPrimary
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = CodeLightTheme.textMuted
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        metadataLabel.font = .systemFont(ofSize: 11)
        metadataLabel.textColor = CodeLightTheme.textSecondary
        metadataLabel.lineBreakMode = .byTruncatingMiddle
        metadataLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        languageBadge.font = .systemFont(ofSize: 10, weight: .semibold)
        languageBadge.textColor = CodeLightTheme.textPrimary
        languageBadge.alignment = .center
        languageBadge.wantsLayer = true
        languageBadge.layer?.cornerRadius = 4
        languageBadge.layer?.backgroundColor = CodeLightTheme.border.cgColor
        languageBadge.isHidden = true

        copyPathButton.bezelStyle = .texturedRounded
        copyPathButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy Path")
        copyPathButton.toolTip = "Copy file path"
        copyPathButton.target = self
        copyPathButton.action = #selector(copyCurrentPath(_:))
        copyPathButton.isBordered = false

        let labelStack = NSStackView(views: [titleLabel, pathLabel, metadataLabel])
        labelStack.orientation = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .leading
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(labelStack)

        searchField.placeholderString = "Find"
        searchField.sendsSearchStringImmediately = true
        searchField.onEnter = { [weak self] in self?.goToNextMatch() }
        searchField.onShiftEnter = { [weak self] in self?.goToPreviousMatch() }
        searchField.onEscape = { [weak self] in self?.closeFind() }
        searchField.target = self
        searchField.action = #selector(searchTextChanged(_:))
        searchField.translatesAutoresizingMaskIntoConstraints = false

        matchCountLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        matchCountLabel.textColor = CodeLightTheme.textMuted
        matchCountLabel.alignment = .right
        matchCountLabel.setContentHuggingPriority(.required, for: .horizontal)

        configureIconButton(previousMatchButton, symbol: "chevron.up", toolTip: "Previous match", action: #selector(previousMatch(_:)))
        configureIconButton(nextMatchButton, symbol: "chevron.down", toolTip: "Next match", action: #selector(nextMatch(_:)))
        configureIconButton(closeFindButton, symbol: "xmark", toolTip: "Clear find", action: #selector(clearFind(_:)))

        let findStack = NSStackView(views: [
            searchField,
            matchCountLabel,
            previousMatchButton,
            nextMatchButton,
            closeFindButton
        ])
        findStack.orientation = .horizontal
        findStack.alignment = .centerY
        findStack.spacing = 6
        findStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(findStack)

        let utilityStack = NSStackView(views: [languageBadge, copyPathButton])
        utilityStack.orientation = .horizontal
        utilityStack.alignment = .centerY
        utilityStack.spacing = 8
        utilityStack.setContentHuggingPriority(.required, for: .horizontal)
        utilityStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        utilityStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(utilityStack)

        recentStack.orientation = .horizontal
        recentStack.spacing = 6
        recentStack.alignment = .centerY
        recentStack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        recentStack.distribution = .gravityAreas
        recentStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(recentStack)

        textView.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.usesFindPanel = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = CodeLightTheme.textPrimary
        textView.backgroundColor = CodeLightTheme.editorBackground
        textView.drawsBackground = true
        textView.insertionPointColor = .clear
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = CodeLightTheme.editorBackground
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let lineRuler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = lineRuler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        view.addSubview(scrollView)

        emptyState.font = .systemFont(ofSize: 15, weight: .medium)
        emptyState.textColor = CodeLightTheme.textMuted
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyState)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidScrollOrChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 108),

            labelStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            labelStack.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            labelStack.trailingAnchor.constraint(equalTo: utilityStack.leadingAnchor, constant: -12),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: findStack.leadingAnchor, constant: -16),
            labelStack.bottomAnchor.constraint(lessThanOrEqualTo: recentStack.topAnchor, constant: -8),

            utilityStack.trailingAnchor.constraint(equalTo: findStack.leadingAnchor, constant: -14),
            utilityStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            findStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -14),
            findStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 220),
            matchCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 58),
            languageBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),
            languageBadge.heightAnchor.constraint(equalToConstant: 20),
            copyPathButton.widthAnchor.constraint(equalToConstant: 24),
            copyPathButton.heightAnchor.constraint(equalToConstant: 24),

            recentStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            recentStack.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -14),
            recentStack.topAnchor.constraint(equalTo: header.topAnchor, constant: 72),
            recentStack.heightAnchor.constraint(equalToConstant: 28),
            recentStack.bottomAnchor.constraint(lessThanOrEqualTo: header.bottomAnchor, constant: -8),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        scrollView.isHidden = true
    }

    func showWorkspaceReady(_ url: URL) {
        workspaceURL = url
        currentURL = nil
        currentText = ""
        currentLoadID = UUID()
        titleLabel.stringValue = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        pathLabel.stringValue = "Select a file from the sidebar"
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        scrollView.isHidden = true
        emptyState.isHidden = false
        emptyState.stringValue = "Select a file from the sidebar."
        pathLabel.stringValue = url.path
        metadataLabel.stringValue = ""
        languageBadge.isHidden = true
        searchField.stringValue = ""
        clearFindState()
    }

    func open(_ url: URL, line: Int? = nil) {
        currentURL = url
        workspaceURL = workspaceURL ?? url.deletingLastPathComponent()
        currentLoadID = UUID()
        let loadID = currentLoadID
        let language = Language.detect(from: url)
        currentLanguage = language
        let highlighter = SyntaxHighlighter()

        titleLabel.stringValue = url.lastPathComponent
        pathLabel.stringValue = compactPath(url)
        metadataLabel.stringValue = "Loading..."
        languageBadge.stringValue = language.displayName
        languageBadge.isHidden = false
        emptyState.isHidden = true
        scrollView.isHidden = false
        searchField.stringValue = ""
        clearFindState()
        addRecentFile(url)

        loadQueue.async { [weak self] in
            let result = FileLoader.load(url)
            guard let self else { return }

            let attributed: NSAttributedString
            switch result {
            case .success(let loaded):
                if loaded.shouldHighlight {
                    attributed = highlighter.highlight(loaded.text, as: language)
                } else {
                    attributed = highlighter.plain(loaded.text)
                }

                DispatchQueue.main.async {
                    guard self.currentLoadID == loadID else { return }
                    self.currentText = loaded.text
                    self.textView.textStorage?.setAttributedString(attributed)
                    if let line {
                        self.selectAndScrollToLine(line)
                    } else {
                        self.textView.scrollToBeginningOfDocument(nil)
                    }
                    self.metadataLabel.stringValue = self.detailText(
                        language: language,
                        bytes: loaded.byteCount,
                        lineCount: loaded.lineCount,
                        highlighted: loaded.shouldHighlight
                    )
                    self.invalidateLineNumbers()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    guard self.currentLoadID == loadID else { return }
                    self.currentText = ""
                    self.textView.textStorage?.setAttributedString(highlighter.plain(error.localizedDescription))
                    self.metadataLabel.stringValue = "Unable to read file"
                    self.invalidateLineNumbers()
                }
            }
        }
    }

    func focusFind() {
        view.window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    func copyFileReference() {
        guard let reference = currentFileReference() else { return }
        copyToPasteboard(reference)
    }

    func copySelectionAsAgentContext() {
        guard let currentURL else { return }

        let range = normalizedSelectedRange()
        let lineRange = lineRangeDescription(for: range)
        let relativePath = displayPath(for: currentURL)
        let selectedText = range.length > 0
            ? (currentText as NSString).substring(with: range)
            : ""

        let context: String
        if selectedText.isEmpty {
            context = """
            File: \(relativePath)
            Lines: \(lineRange)

            No code selected.
            """
        } else {
            context = """
            File: \(relativePath)
            Lines: \(lineRange)

            ```\(currentLanguage.fenceIdentifier)
            \(selectedText)
            ```
            """
        }

        copyToPasteboard(context)
    }

    func copyWorkspaceContext() {
        guard let workspaceURL else { return }

        var lines: [String] = [
            "Workspace: \(workspaceURL.path)"
        ]

        if let reference = currentFileReference() {
            lines.append("Current file: \(reference)")
        }

        if !recentFiles.isEmpty {
            lines.append("")
            lines.append("Recent files:")
            lines.append(contentsOf: recentFiles.map { "- \(displayPath(for: $0))" })
        }

        let files = FileIndex.files(under: workspaceURL, showsHiddenAndIgnored: false)
        if !files.isEmpty {
            lines.append("")
            lines.append("Workspace files (first \(min(files.count, 120)) of \(files.count)):")
            lines.append(contentsOf: files.prefix(120).map { "- \($0.relativePath)" })
        }

        copyToPasteboard(lines.joined(separator: "\n"))
    }

    @objc private func searchTextChanged(_ sender: NSSearchField) {
        updateSearch(sender.stringValue)
    }

    @objc private func textDidScrollOrChange(_ notification: Notification) {
        invalidateLineNumbers()
    }

    @objc private func previousMatch(_ sender: Any?) {
        goToPreviousMatch()
    }

    @objc private func nextMatch(_ sender: Any?) {
        goToNextMatch()
    }

    @objc private func clearFind(_ sender: Any?) {
        closeFind()
    }

    @objc private func copyCurrentPath(_ sender: Any?) {
        guard let currentURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentURL.path, forType: .string)
    }

    private func updateSearch(_ query: String) {
        clearSearchHighlights()
        searchMatches.removeAll()
        selectedSearchMatch = -1
        updateFindStatus()

        guard !query.isEmpty, !currentText.isEmpty else {
            return
        }

        let text = currentText as NSString
        var searchRange = NSRange(location: 0, length: text.length)

        while searchRange.length > 0 {
            let match = text.range(of: query, options: [.caseInsensitive], range: searchRange)
            guard match.location != NSNotFound else { break }

            searchMatches.append(match)

            let nextLocation = match.location + max(match.length, 1)
            guard nextLocation < text.length else { break }
            searchRange = NSRange(location: nextLocation, length: text.length - nextLocation)

            if searchMatches.count > 1000 {
                break
            }
        }

        guard !searchMatches.isEmpty else { updateFindStatus(); return }

        selectedSearchMatch = 0
        applySearchHighlights()
        scrollToSelectedMatch()
        updateFindStatus()
    }

    private func clearSearchHighlights() {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
    }

    private func applySearchHighlights() {
        guard let storage = textView.textStorage else { return }
        searchMatches.enumerated().forEach { index, range in
            let color = index == selectedSearchMatch
                ? CodeLightTheme.activeSearchHighlight
                : CodeLightTheme.searchHighlight
            storage.addAttribute(.backgroundColor, value: color, range: range)
        }
    }

    private func goToNextMatch() {
        guard !searchMatches.isEmpty else { return }
        selectedSearchMatch = (selectedSearchMatch + 1) % searchMatches.count
        clearSearchHighlights()
        applySearchHighlights()
        scrollToSelectedMatch()
        updateFindStatus()
    }

    private func goToPreviousMatch() {
        guard !searchMatches.isEmpty else { return }
        selectedSearchMatch = selectedSearchMatch <= 0 ? searchMatches.count - 1 : selectedSearchMatch - 1
        clearSearchHighlights()
        applySearchHighlights()
        scrollToSelectedMatch()
        updateFindStatus()
    }

    private func scrollToSelectedMatch() {
        guard searchMatches.indices.contains(selectedSearchMatch) else { return }
        textView.scrollRangeToVisible(searchMatches[selectedSearchMatch])
    }

    private func closeFind() {
        searchField.stringValue = ""
        clearFindState()
        view.window?.makeFirstResponder(textView)
    }

    private func clearFindState() {
        clearSearchHighlights()
        searchMatches.removeAll()
        selectedSearchMatch = -1
        updateFindStatus()
    }

    private func updateFindStatus() {
        if searchField.stringValue.isEmpty {
            matchCountLabel.stringValue = ""
        } else if searchMatches.isEmpty {
            matchCountLabel.stringValue = "0"
        } else {
            matchCountLabel.stringValue = "\(selectedSearchMatch + 1) of \(searchMatches.count)"
        }

        let hasMatches = !searchMatches.isEmpty
        previousMatchButton.isEnabled = hasMatches
        nextMatchButton.isEnabled = hasMatches
    }

    private func invalidateLineNumbers() {
        scrollView.verticalRulerView?.needsDisplay = true
    }

    private func selectAndScrollToLine(_ line: Int) {
        let range = characterRange(forLine: line)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
    }

    private func detailText(language: Language, bytes: Int, lineCount: Int, highlighted: Bool) -> String {
        let byteText = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        let highlightText = highlighted ? "highlighted" : "plain for speed"
        return "\(lineCount) lines - \(byteText) - \(highlightText)"
    }

    private func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > 8 {
            recentFiles.removeLast(recentFiles.count - 8)
        }
        renderRecentFiles()
    }

    private func renderRecentFiles() {
        recentStack.arrangedSubviews.forEach {
            recentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        recentFiles.forEach { url in
            let tab = FileTabView(url: url, isActive: url == currentURL)
            tab.openButton.target = self
            tab.openButton.action = #selector(openRecentFile(_:))
            tab.closeButton.target = self
            tab.closeButton.action = #selector(closeRecentFile(_:))
            recentStack.addArrangedSubview(tab)
        }
    }

    @objc private func openRecentFile(_ sender: FileTabButton) {
        guard let url = sender.fileURL else { return }
        open(url)
    }

    @objc private func closeRecentFile(_ sender: FileTabButton) {
        guard let url = sender.fileURL else { return }
        closeFile(url)
    }

    private func closeFile(_ url: URL) {
        let wasCurrent = currentURL == url
        recentFiles.removeAll { $0 == url }

        if wasCurrent {
            if let nextURL = recentFiles.first {
                open(nextURL)
            } else {
                showNoOpenFile()
            }
        } else {
            renderRecentFiles()
        }
    }

    private func showNoOpenFile() {
        currentURL = nil
        currentText = ""
        currentLoadID = UUID()
        titleLabel.stringValue = workspaceURL?.lastPathComponent ?? "No file open"
        pathLabel.stringValue = workspaceURL?.path ?? "Select a file from the sidebar"
        metadataLabel.stringValue = ""
        languageBadge.isHidden = true
        searchField.stringValue = ""
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        clearFindState()
        scrollView.isHidden = true
        emptyState.isHidden = false
        emptyState.stringValue = "No file open."
        renderRecentFiles()
    }

    private func compactPath(_ url: URL) -> String {
        url.deletingLastPathComponent().path
    }

    private func currentFileReference() -> String? {
        guard let currentURL else { return nil }
        let range = normalizedSelectedRange()
        let lineRange = lineRangeDescription(for: range)
        return "\(displayPath(for: currentURL)):\(lineRange)"
    }

    private func displayPath(for url: URL) -> String {
        guard let workspaceURL else { return url.path }
        return FileIndex.relativePath(for: url, root: workspaceURL)
    }

    private func normalizedSelectedRange() -> NSRange {
        let selected = textView.selectedRange()
        let textLength = (currentText as NSString).length
        guard selected.location != NSNotFound, selected.location <= textLength else {
            return NSRange(location: 0, length: 0)
        }
        return NSRange(location: selected.location, length: min(selected.length, textLength - selected.location))
    }

    private func lineRangeDescription(for range: NSRange) -> String {
        let startLine = lineNumber(at: range.location)
        guard range.length > 0 else { return "\(startLine)" }

        let endLocation = max(range.location, range.location + range.length - 1)
        let endLine = lineNumber(at: endLocation)
        return startLine == endLine ? "\(startLine)" : "\(startLine)-\(endLine)"
    }

    private func lineNumber(at location: Int) -> Int {
        let text = currentText as NSString
        let clamped = min(max(location, 0), text.length)
        guard clamped > 0 else { return 1 }
        return text.substring(to: clamped).reduce(1) { count, character in
            character == "\n" ? count + 1 : count
        }
    }

    private func characterRange(forLine requestedLine: Int) -> NSRange {
        let text = currentText as NSString
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }

        let targetLine = max(requestedLine, 1)
        var currentLine = 1
        var lineStart = 0

        while lineStart < text.length, currentLine < targetLine {
            let searchRange = NSRange(location: lineStart, length: text.length - lineStart)
            let newlineRange = text.range(of: "\n", options: [], range: searchRange)
            guard newlineRange.location != NSNotFound else {
                return NSRange(location: text.length, length: 0)
            }
            lineStart = newlineRange.location + 1
            currentLine += 1
        }

        let remainder = NSRange(location: lineStart, length: text.length - lineStart)
        let newlineRange = text.range(of: "\n", options: [], range: remainder)
        let lineEnd = newlineRange.location == NSNotFound ? text.length : newlineRange.location
        return NSRange(location: lineStart, length: max(lineEnd - lineStart, 0))
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func configureIconButton(_ button: NSButton, symbol: String, toolTip: String, action: Selector) {
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip)
        button.toolTip = toolTip
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    private static func makeScrollableTextView() -> (scrollView: NSScrollView, textView: NSTextView) {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("NSTextView.scrollableTextView did not create an NSTextView document view.")
        }
        return (scrollView, textView)
    }
}

private final class FileTabButton: NSButton {
    var fileURL: URL?
}

private final class FileTabView: NSView {
    let openButton = FileTabButton()
    let closeButton = FileTabButton()

    init(url: URL, isActive: Bool) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        layer?.borderColor = (isActive ? CodeLightTheme.border : CodeLightTheme.border.withAlphaComponent(0.7)).cgColor
        layer?.backgroundColor = (isActive ? CodeLightTheme.elevatedBackground : CodeLightTheme.headerBackground).cgColor

        openButton.title = url.lastPathComponent
        openButton.fileURL = url
        openButton.bezelStyle = .texturedRounded
        openButton.isBordered = false
        openButton.font = .systemFont(ofSize: 11, weight: isActive ? .semibold : .regular)
        openButton.contentTintColor = isActive ? CodeLightTheme.textPrimary : CodeLightTheme.textSecondary
        openButton.toolTip = url.path

        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close file")
        closeButton.fileURL = url
        closeButton.bezelStyle = .texturedRounded
        closeButton.isBordered = false
        closeButton.contentTintColor = CodeLightTheme.textMuted
        closeButton.toolTip = "Close \(url.lastPathComponent)"

        let stack = NSStackView(views: [openButton, closeButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 1
        stack.edgeInsets = NSEdgeInsets(top: 1, left: 6, bottom: 1, right: 4)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),
            heightAnchor.constraint(equalToConstant: 26),
            widthAnchor.constraint(lessThanOrEqualToConstant: 180)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private enum FileLoader {
    struct LoadedFile {
        let text: String
        let byteCount: Int
        let lineCount: Int
        let shouldHighlight: Bool
    }

    static func load(_ url: URL) -> Result<LoadedFile, Error> {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let byteCount = values.fileSize ?? 0

            if byteCount > 30 * 1024 * 1024 {
                return .failure(FileLoadError.tooLarge(byteCount))
            }

            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let text = decode(data)
            let lineCount = text.reduce(1) { count, character in
                character == "\n" ? count + 1 : count
            }

            return .success(
                LoadedFile(
                    text: text,
                    byteCount: data.count,
                    lineCount: lineCount,
                    shouldHighlight: data.count <= 2 * 1024 * 1024
                )
            )
        } catch {
            return .failure(error)
        }
    }

    private static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
            ?? data.map { $0 == 0 ? 32 : $0 }.withUnsafeBufferPointer { buffer in
                String(decoding: buffer, as: UTF8.self)
            }
    }
}

private enum FileLoadError: LocalizedError {
    case tooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .tooLarge(let bytes):
            let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            return "This file is \(size). Code Light skips files over 30 MB to keep the app responsive."
        }
    }
}
