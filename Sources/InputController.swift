import Cocoa
import InputMethodKit

private let notFound = NSRange(location: NSNotFound, length: NSNotFound)

enum Settings {
    static var method: TypingMethod {
        get { TypingMethod(rawValue: UserDefaults.standard.string(forKey: "method") ?? "") ?? .telex }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "method") }
    }
}

@objc(InputController)
final class InputController: IMKInputController {
    private var keys = ""           // raw keystrokes of the word being composed
    private var shown = ""          // what that word currently looks like on screen
    private var caret = NSNotFound  // where the caret must be if the user hasn't moved it
    private var before = NSNotFound // where the caret was before our last insert
    private var known = NSNotFound  // caret we tracked ourselves while typing fast (kept across spaces)
    private var fast = false        // this key came right after the previous one
    private var lastKey: TimeInterval = 0
    private var guessed = false     // the word's start came from the app's (maybe late) report
    private var start = NSNotFound  // caret the app reported when the word began
    private var sent = ""           // everything we inserted for this word, as an append-only terminal holds it
    private var marked = false      // fallback when the caret is unknown: use marked text
    private var committed = ""      // start of the word already sent before switching to marked text
    private var erase = false       // app can't replace text (terminal): fix the word with DEL + retype

    /// Native terminal emulators ignore replacementRange (iTerm2 even reports a correct caret, so it can't
    /// be detected); DEL is Backspace there, so DEL + retype from the first key, without underline.
    /// Never list apps that also have ordinary text fields (Orca Bots drops DEL -> "toôi"): those are
    /// handled per field by the caret check, falling back to marked text.
    private static let terminals: Set<String> = ["com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable"]
    /// Apps that embed xterm.js terminals next to ordinary fields. A terminal field gives itself away when
    /// the caret snaps back after an insert; only then, and only for that word, fix it with DEL + retype
    /// (DEL even erases the first letter already sent). Never remembered per app: other fields stay normal.
    private static let embeddedTerminalApps: Set<String> = [
        "com.stablyai.orca", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.cmuxterm.app",
        "co.zeit.hyper", "org.tabby",
    ]
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, let client = sender as? IMKTextInput else { return false }
        // Typing fast, apps report the caret a beat late (Chrome, Slack…: "dd" came out "dđ"), and nobody
        // clicks elsewhere between two quick keys: then trust our own caret, after a pause the app's.
        fast = event.timestamp - lastKey < 0.5
        lastKey = event.timestamp

        // Shortcuts (⌘C, ⌃A, ⌥…) belong to the app.
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            commit(client)
            known = NSNotFound
            return false
        }
        if !keys.isEmpty, !marked, !erase {
            let location = client.selectedRange().location
            if stuck(client, at: location) {
                becomeTerminal(client)
            } else if !fast, location != NSNotFound, location != caret {
                reset()   // after a pause the app's caret is reliable: the user clicked / moved it
            } else if guessed, keys.count == 1, location != NSNotFound, location > caret {
                before += location - caret   // that first report was late (e.g. right after Enter)
                caret = location
            }
        }

        if event.keyCode == 51 {   // Delete
            guard !keys.isEmpty else {   // the app deletes one character itself
                known = known > 0 && known != NSNotFound ? known - 1 : NSNotFound
                return false
            }
            keys.removeLast()
            show(client)
            return true
        }
        if let ch = event.characters?.first, ch.isASCII,
           ch.isLetter || (ch.isNumber && !keys.isEmpty && Settings.method == .vni) {
            // No syllable is this long (held key, gibberish): stop composing so work and memory stay bounded.
            if keys.count >= 24 {
                commit(client)
                return false
            }
            if keys.isEmpty {
                let app = client.bundleIdentifier() ?? ""
                start = client.selectedRange().location
                let noCaret = start == NSNotFound
                // A caret-less field inside an app with embedded terminals is a terminal (cmux's Ghostty view).
                erase = Self.terminals.contains(app) || (noCaret && Self.embeddedTerminalApps.contains(app))
                marked = !erase && noCaret
                if erase || marked { known = NSNotFound }   // those modes don't track the caret
            }
            keys.append(ch)
            show(client)
            return true
        }
        // Space, Enter, punctuation, arrows…: finish the word, then let the app handle the key.
        commit(client)
        // Space/punctuation adds one character; Enter, Tab, arrows… may go anywhere.
        let printable = event.characters?.unicodeScalars.count == 1
            && (0x20..<0x7f).contains(event.characters!.unicodeScalars.first!.value)
        known = printable && known != NSNotFound ? known + 1 : NSNotFound
        return false
    }

    override func commitComposition(_ sender: Any!) {
        commit(sender as? IMKTextInput)
    }

    // Switching app/field: never carry a half-typed word into the new client.
    override func activateServer(_ sender: Any!) { reset(); known = NSNotFound }
    override func deactivateServer(_ sender: Any!) { commit(sender as? IMKTextInput); known = NSNotFound }

    private func show(_ client: IMKTextInput) {
        if marked {
            let text = pending()
            client.setMarkedText(text,
                                 selectionRange: NSRange(location: text.utf16.count, length: 0),
                                 replacementRange: notFound)
            return
        }
        let text = keys.isEmpty ? "" : Engine(method: Settings.method).convert(keys)
        // Direct mode: no underline. Replace only the tail that changed ("viê" -> "việ" touches 1 char).
        let old = Array(shown.utf16), new = Array(text.utf16)
        var common = 0
        while common < old.count, common < new.count, old[common] == new[common] { common += 1 }
        let oldTail = old.count - common
        let newTail = String(utf16CodeUnits: Array(new[common...]), count: new.count - common)
        if erase {
            // DEL = Backspace for a terminal; sent with the new text in ONE insert, so no race with keys.
            client.insertText(String(repeating: "\u{7f}", count: oldTail) + newTail, replacementRange: notFound)
            shown = text
            if keys.isEmpty { reset() }
            return
        }
        guessed = shown.isEmpty ? !(fast && known != NSNotFound) : guessed
        before = !shown.isEmpty ? caret : guessed ? client.selectedRange().location : known
        // Client-reported caret: reject unknown/absurd values instead of letting the arithmetic below trap.
        guard before != NSNotFound, before >= oldTail, before <= Int.max - newTail.utf16.count else {
            marked = true
            committed = shown
            return show(client)
        }
        let location = before - oldTail
        client.insertText(newTail, replacementRange: oldTail == 0 ? notFound : NSRange(location: location, length: oldTail))
        shown = text
        sent += newTail
        caret = location + newTail.utf16.count
        known = caret
        if keys.isEmpty { reset() }
    }

    /// The word minus what was already sent before falling back to marked text. shortcut: a later key
    /// changing that sent part (d→đ) can't be fixed; only after a bogus caret report mid-word.
    private func pending() -> String {
        let text = keys.isEmpty ? "" : Engine(method: Settings.method).convert(keys)
        return text.hasPrefix(committed) ? String(text.dropFirst(committed.count)) : text
    }

    /// xterm.js ignores replacementRange and its caret report never moves. A late report (Electron chat boxes
    /// when typing fast) also looks unmoved for a key or two, so only call it a terminal once we sent 3+ chars.
    private func stuck(_ client: IMKTextInput, at location: Int) -> Bool {
        location == start && location != caret && sent.utf16.count >= 3
            && Self.embeddedTerminalApps.contains(client.bundleIdentifier() ?? "")
    }

    /// Switch this word to DEL + retype; the terminal holds everything we appended, so fix it from there.
    private func becomeTerminal(_ client: IMKTextInput) {
        erase = true
        known = NSNotFound   // like the other DEL modes, don't track the caret
        shown = sent
        show(client)
    }

    private func commit(_ client: IMKTextInput?) {
        if let client, !keys.isEmpty, !marked, !erase, stuck(client, at: client.selectedRange().location) {
            becomeTerminal(client)
        }
        if marked, !keys.isEmpty, let client {
            client.insertText(pending(), replacementRange: notFound)
        }
        reset()
    }

    private func reset() {
        keys = ""
        shown = ""
        caret = NSNotFound
        before = NSNotFound
        marked = false
        committed = ""
        erase = false
        start = NSNotFound
        sent = ""
    }

    // MARK: input-menu (the "V" icon in the menu bar)

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        for (title, action, method) in [("Telex", #selector(useTelex), TypingMethod.telex),
                                        ("VNI", #selector(useVNI), .vni)] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.state = Settings.method == method ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func useTelex(_ sender: Any?) { Settings.method = .telex }
    @objc private func useVNI(_ sender: Any?) { Settings.method = .vni }
}
