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
    private var marked = false      // fallback for apps that can't report the caret: use marked text

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, let client = sender as? IMKTextInput else { return false }

        // Shortcuts (⌘C, ⌃A, ⌥…) belong to the app.
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            commit(client)
            return false
        }
        // Caret moved (click, arrow handled by app…) since our last edit: start a fresh word.
        if !keys.isEmpty, !marked, client.selectedRange().location != caret { reset() }

        if event.keyCode == 51 {   // Delete
            guard !keys.isEmpty else { return false }
            keys.removeLast()
            show(client)
            return true
        }
        if let ch = event.characters?.first, ch.isASCII,
           ch.isLetter || (ch.isNumber && !keys.isEmpty && Settings.method == .vni) {
            if keys.isEmpty { marked = client.selectedRange().location == NSNotFound }
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

    private func show(_ client: IMKTextInput) {
        let text = keys.isEmpty ? "" : Engine(method: Settings.method).convert(keys)
        if marked {
            client.setMarkedText(text, selectionRange: NSRange(location: text.utf16.count, length: 0),
                                 replacementRange: notFound)
            return
        }
        // Direct mode: no underline. Replace only the tail that changed ("viê" -> "việ" touches 1 char).
        let old = Array(shown.utf16), new = Array(text.utf16)
        var common = 0
        while common < old.count, common < new.count, old[common] == new[common] { common += 1 }
        let oldTail = old.count - common
        let newTail = String(utf16CodeUnits: Array(new[common...]), count: new.count - common)
        let location = client.selectedRange().location - oldTail
        client.insertText(newTail, replacementRange: oldTail == 0 ? notFound : NSRange(location: location, length: oldTail))
        shown = text
        caret = location + newTail.utf16.count
        if keys.isEmpty { reset() }
    }

    private func commit(_ client: IMKTextInput?) {
        if marked, !keys.isEmpty, let client {
            client.insertText(Engine(method: Settings.method).convert(keys), replacementRange: notFound)
        }
        reset()
    }

    private func reset() {
        keys = ""
        shown = ""
        caret = NSNotFound
        marked = false
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
