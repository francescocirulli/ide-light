import AppKit

final class FindSearchField: NSSearchField {
    var onEnter: (() -> Void)?
    var onShiftEnter: (() -> Void)?
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            if event.modifierFlags.contains(.shift) {
                onShiftEnter?()
            } else {
                onEnter?()
            }
        case 53:
            onEscape?()
        case 125:
            onEnter?()
        case 126:
            onShiftEnter?()
        default:
            super.keyDown(with: event)
        }
    }
}
