import Carbon
import os

@MainActor
public final class CarbonHotkey {
    public var onPress: (@MainActor () -> Void)?

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let logger = Logger(subsystem: "io.berkan.keypad", category: "input")
    private var handler: EventHandlerRef?
    private var hotkey: EventHotKeyRef?

    public init(keyCode: UInt32 = UInt32(kVK_ANSI_K), modifiers: UInt32 = UInt32(controlKey | optionKey)) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    isolated deinit {
        unregister()
    }

    /// Registers the system-wide shortcut, replacing an earlier registration. Returns `false` when macOS refuses it.
    @discardableResult
    public func register() -> Bool {
        unregister()

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotkey = Unmanaged<CarbonHotkey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotkey.onPress?() }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard installStatus == noErr else {
            logger.error("Hotkey handler installation failed with status \(installStatus)")
            unregister()
            return false
        }

        let id = EventHotKeyID(signature: OSType(0x4B50_4144), id: 1)
        let registerStatus = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotkey)
        guard registerStatus == noErr else {
            logger.error("Hotkey registration failed with status \(registerStatus)")
            unregister()
            return false
        }
        return true
    }

    public func unregister() {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
        hotkey = nil
        handler = nil
    }
}
