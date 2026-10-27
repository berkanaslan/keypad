import AppKit

extension NSScreen {
    /// The display that contains the pointer, or the main display when the pointer is on no display.
    static var underPointer: NSScreen? {
        let pointer = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? main
    }
}
