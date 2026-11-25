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
    private var before = NSNotFound // where the app reported the caret before our last insert
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
    /// Browsers host every kind of field (web terminals, Docs canvases, plain inputs): one odd field must
    /// not underline all of them, so they fall back to marked text per word and are never remembered.
    private static let browsers: Set<String> = [
        "com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser", "com.microsoft.edgemac",
        "org.mozilla.firefox", "com.brave.Browser",
    ]
    /// Apps seen with a field that ignores the caret (Slack…): start their words as
    /// marked text so the first letter is never sent early ("dd" -> "dđ"). Worst case is an underline.
    /// Drops multi-field apps remembered by mistake (v1.0.2 Orca, Chrome): they made every field underlined.
    private static var noCaretApps = Set(UserDefaults.standard.stringArray(forKey: "noCaretApps") ?? [])
        .subtracting(embeddedTerminalApps).subtracting(browsers)

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, let client = sender as? IMKTextInput else { return false }

        // Shortcuts (⌘C, ⌃A, ⌥…) belong to the app.
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            commit(client)
            return false
        }
        if !keys.isEmpty, !marked, !erase {
            let location = client.selectedRange().location
            if location == before, location != caret {
                // Caret never moved after our insert: this field ignores replacementRange.
                let app = client.bundleIdentifier() ?? ""
                if Self.embeddedTerminalApps.contains(app) {
                    erase = true   // a terminal pane: DEL + retype for the rest of this word
                } else {           // e.g. Slack: no DEL there; marked text, remembered so words start marked
                    if !Self.browsers.contains(app) {
                        Self.noCaretApps.insert(app)
                        UserDefaults.standard.set(Array(Self.noCaretApps), forKey: "noCaretApps")
                    }
                    marked = true
                    committed = shown
                }
            } else if location != caret {
                reset()   // user clicked / moved the caret: start a fresh word
            }
        }

        if event.keyCode == 51 {   // Delete
            guard !keys.isEmpty else { return false }
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
                let noCaret = client.selectedRange().location == NSNotFound
                // A caret-less field inside an app with embedded terminals is a terminal (cmux's Ghostty view).
                erase = Self.terminals.contains(app) || (noCaret && Self.embeddedTerminalApps.contains(app))
                marked = !erase && (Self.noCaretApps.contains(app) || noCaret)
            }
            keys.append(ch)
            show(client)
            return true
        }
        // Space, Enter, punctuation, arrows…: finish the word, then let the app handle the key.
        commit(client)
        return false
    }

    override func commitComposition(_ sender: Any!) {
        commit(sender as? IMKTextInput)
    }

    // Switching app/field: never carry a half-typed word into the new client.
    override func activateServer(_ sender: Any!) { reset() }
    override func deactivateServer(_ sender: Any!) { commit(sender as? IMKTextInput) }

    private func show(_ client: IMKTextInput) {
        if marked {
            let text = pending()
            client.setMarkedText(text, selectionRange: NSRange(location: text.utf16.count, length: 0),
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
        before = client.selectedRange().location
        // Client-reported caret: reject unknown/absurd values instead of letting the arithmetic below trap.
        guard before != NSNotFound, before >= oldTail, before <= Int.max - newTail.utf16.count else {
            marked = true
            committed = shown
            return show(client)
        }
        let location = before - oldTail
        client.insertText(newTail, replacementRange: oldTail == 0 ? notFound : NSRange(location: location, length: oldTail))
        shown = text
        caret = location + newTail.utf16.count
        if keys.isEmpty { reset() }
    }

    /// The word minus what was already sent. shortcut: if a later key changes that sent part
    /// (d→đ, a→â on the 1st letter) it can't be fixed; happens at most once per newly learned app.
    private func pending() -> String {
        let text = keys.isEmpty ? "" : Engine(method: Settings.method).convert(keys)
        return text.hasPrefix(committed) ? String(text.dropFirst(committed.count)) : text
    }

    private func commit(_ client: IMKTextInput?) {
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
