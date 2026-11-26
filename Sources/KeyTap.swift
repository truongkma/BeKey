import Cocoa
import Carbon

/// The word being typed, as keystrokes and as shown, for apps where BeKey types with real key events.
/// Pure logic, so it is tested without a keyboard (Tests/controller).
struct Composer {
    enum Action: Equatable {
        case pass                              // let the key through unchanged
        case replace(back: Int, text: String)  // swallow it: that many Backspaces, then this text
    }
    private(set) var keys = "", shown = ""

    mutating func reset() { keys = ""; shown = "" }

    /// A letter (or a VNI tone digit inside a word).
    mutating func type(_ ch: Character, method: TypingMethod) -> Action {
        // No syllable is this long (held key, gibberish): stop composing so work and memory stay bounded.
        guard keys.count < 24 else { reset(); return .pass }
        keys.append(ch)
        return show(Engine(method: method).convert(keys), typed: ch)
    }

    /// Backspace removes one character as shown ("tôi" -> "tô" -> "t"), not one keystroke ("tô" -> "to"):
    /// drop keystrokes until the word is a character shorter.
    mutating func backspace(method: TypingMethod) -> Action {
        guard !keys.isEmpty else { return .pass }   // nothing composed: an ordinary Backspace
        let engine = Engine(method: method), target = shown.count - 1
        var text = ""
        repeat {
            keys.removeLast()
            text = keys.isEmpty ? "" : engine.convert(keys)
        } while !keys.isEmpty && text.count > target
        return show(text, typed: nil)
    }

    /// Change the screen from `shown` to `text` with the fewest Backspaces. If the key itself does exactly
    /// that (a plain letter appended, a Backspace removing the last character), let it through.
    private mutating func show(_ text: String, typed: Character?) -> Action {
        let old = Array(shown), new = Array(text)
        var common = 0
        while common < old.count, common < new.count, old[common] == new[common] { common += 1 }
        let back = old.count - common, tail = String(new[common...])
        shown = text
        if keys.isEmpty { keys = ""; shown = "" }
        if let typed, back == 0, tail == String(typed) { return .pass }
        if typed == nil, back == 1, tail.isEmpty { return .pass }
        return .replace(back: back, text: tail)
    }
}

/// BeKey types like a keyboard: an event tap swallows the key and injects real Backspaces + the fixed text
/// in its place (tapPostEvent keeps them ahead of keys already queued, so fast typing can't reorder them).
/// Every app handles real keys the same way, so nothing depends on how a field reports its caret or text.
/// Measured, the input-method paths each broke somewhere: a replaced range in xterm.js terminals (resent
/// or dropped), DEL in editors (a box), the caret after a Backspace mid-word in Chrome, and marked text is
/// underlined. The input method itself stays out of the way while the tap types (Chromium drops a key's
/// text if the input method inserts anything while handling it), and only takes over when Accessibility
/// is not granted. It is still what tells the tap a text field is focused (activate/deactivate).
final class KeyTap {
    static let shared = KeyTap()
    private static let mark: Int64 = 0x42654B6579   // "BeKey": events we inject, so the tap lets them pass

    private var tap: CFMachPort?
    private var composer = Composer()
    /// The app of the text field BeKey is active in (set by the input method), nil when none.
    private var client: String?
    private weak var owner: AnyObject?

    /// True when the tap types for this field (always, once Accessibility is granted), so the input method
    /// must pass every key through.
    var enabled = true   // tests turn it off: they must never install a real event tap

    func owns(_ app: String?) -> Bool {
        guard enabled, app != nil else { return false }
        if tap == nil { start() }
        return tap != nil
    }

    /// The input method became active in a field of `app`.
    func activate(_ app: String?, by controller: AnyObject, keepWord: Bool = false) {
        if !keepWord || owner !== controller || client != app { composer.reset() }
        client = app; owner = controller
    }

    func deactivate(by controller: AnyObject) {
        guard owner === controller else { return }   // a newer field already took over
        client = nil; owner = nil; composer.reset()
    }

    private func start() {
        guard AXIsProcessTrusted() else { return }
        let mask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { proxy, type, event, _ in
                                              KeyTap.shared.handle(proxy, type, event)
                                          }, userInfo: nil) else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
    }

    private func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            composer.reset()
            return pass
        }
        guard client != nil else { return pass }
        guard type == .keyDown else { composer.reset(); return pass }   // a click may move the caret
        guard event.getIntegerValueField(.eventSourceUserData) != Self.mark else { return pass }
        if !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            composer.reset()   // shortcuts belong to the app
            return pass
        }
        let action: Composer.Action
        if event.getIntegerValueField(.keyboardEventKeycode) == 51 {
            action = composer.backspace(method: Settings.method)
        } else if let ch = character(of: event), ch.isASCII,
                  ch.isLetter || (ch.isNumber && !composer.keys.isEmpty && Settings.method == .vni) {
            action = composer.type(ch, method: Settings.method)
        } else {
            composer.reset()   // space, Enter, punctuation, arrows…: the word is done
            return pass
        }
        guard case let .replace(back, text) = action else { return pass }
        for _ in 0..<back { inject(proxy, key: 51, text: nil) }
        for ch in text { inject(proxy, key: 0, text: String(ch)) }
        return nil
    }

    private func inject(_ proxy: CGEventTapProxy, key: CGKeyCode, text: String?) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down) else { continue }
            if let text { let u = Array(text.utf16); e.keyboardSetUnicodeString(stringLength: u.count, unicodeString: u) }
            e.flags = []
            e.setIntegerValueField(.eventSourceUserData, value: Self.mark)
            e.tapPostEvent(proxy)
        }
    }

    /// The character a key types. Key events can come without their string (synthesized ones): then
    /// translate the key code with the current ASCII keyboard layout.
    private func character(of event: CGEvent) -> Character? {
        var len = 0
        var buf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &buf)
        if len > 0 { return String(utf16CodeUnits: buf, count: len).first }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var mods: UInt32 = 0
        if event.flags.contains(.maskShift) { mods |= UInt32(shiftKey >> 8) }
        if event.flags.contains(.maskAlphaShift) { mods |= UInt32(alphaLock >> 8) }
        var dead: UInt32 = 0, n = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                                    UInt16(kUCKeyActionDown), mods, UInt32(LMGetKbdType()),
                                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &n, &chars)
        return status == noErr && n > 0 ? String(utf16CodeUnits: chars, count: n).first : nil
    }
}
