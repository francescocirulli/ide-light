import AppKit

enum CodeLightTheme {
    static let windowBackground = NSColor(hex: 0x191B1D)
    static let sidebarBackground = NSColor(hex: 0x151617)
    static let editorBackground = NSColor(hex: 0x1E1E1E)
    static let headerBackground = NSColor(hex: 0x202326)
    static let elevatedBackground = NSColor(hex: 0x24282C)
    static let border = NSColor(hex: 0x32363A)
    static let textPrimary = NSColor(hex: 0xE7E7E7)
    static let textSecondary = NSColor(hex: 0xA9AFB6)
    static let textMuted = NSColor(hex: 0x7A8087)
    static let accent = NSColor(hex: 0x0A84FF)
    static let searchHighlight = NSColor(hex: 0xD6A629).withAlphaComponent(0.38)
    static let activeSearchHighlight = NSColor(hex: 0xF2C94C).withAlphaComponent(0.72)

    static let syntaxKeyword = NSColor(hex: 0xC586C0)
    static let syntaxString = NSColor(hex: 0x7AC88B)
    static let syntaxNumber = NSColor(hex: 0xD19A66)
    static let syntaxComment = NSColor(hex: 0x6A9955)
    static let syntaxTag = NSColor(hex: 0x5DADE2)
    static let syntaxAttribute = NSColor(hex: 0x4EC9B0)
}

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

extension NSView {
    func pinToEdges(of parent: NSView, inset: CGFloat = 0) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
        ])
    }
}
