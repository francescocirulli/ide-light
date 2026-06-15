import AppKit

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
        .foregroundColor: CodeLightTheme.textMuted
    ]

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer,
            let scrollView = textView.enclosingScrollView
        else {
            return
        }

        CodeLightTheme.editorBackground.setFill()
        bounds.fill()

        let visibleRect = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )

        guard glyphRange.length > 0 else { return }

        let text = textView.string as NSString
        let visibleCharacterRange = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )

        var lineNumber = 1
        if visibleCharacterRange.location > 0 {
            let prefix = text.substring(to: min(visibleCharacterRange.location, text.length))
            lineNumber += prefix.reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        }

        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &effectiveRange,
                withoutAdditionalLayout: true
            )

            let y = lineRect.minY + textView.textContainerInset.height - visibleRect.minY
            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: textAttributes)
            label.draw(
                at: NSPoint(x: ruleThickness - labelSize.width - 8, y: y + 1),
                withAttributes: textAttributes
            )

            glyphIndex = NSMaxRange(effectiveRange)
            lineNumber += 1
        }
    }
}
