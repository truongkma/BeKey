import Cocoa
import Carbon

/// A focused password field turns on secure input, and macOS then forces an ASCII keyboard layout (ABC).
/// Leaving the field normally gives BeKey back, but closing its tab or window (or a login page moving on)
/// does not: BeKey stays off, and picking it while secure input is still on is refused. So remember that
/// BeKey was pushed out by secure input, and select it again once secure input is off.
enum SecureInput {
    private static var wasSelected = false, pushedOut = false
    private static var timer: Timer?

    static func watch() {
        wasSelected = beKeySelected()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), nil, { _, _, _, _, _ in
            DispatchQueue.main.async { SecureInput.sourceChanged() }
        }, kTISNotifySelectedKeyboardInputSourceChanged, nil, .deliverImmediately)
    }

    private static func sourceChanged() {
        let selected = beKeySelected()
        if wasSelected, !selected, IsSecureEventInputEnabled() { pushedOut = true }
        // shortcut: a deliberate switch to ABC while secure input is on is undone too; rare, ignore until reported.
        if selected { pushedOut = false }
        wasSelected = selected
        guard pushedOut, timer == nil else { return }
        // No notification says secure input ended: check twice a second, only while BeKey waits for it.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
            guard !IsSecureEventInputEnabled() else { return }
            t.invalidate(); timer = nil
            if pushedOut, !beKeySelected(), let me = beKey() { TISSelectInputSource(me) }
            pushedOut = false
        }
    }

    private static func beKey() -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: Bundle.main.bundleIdentifier ?? ""] as CFDictionary
        return (TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource])?.first
    }

    private static func beKeySelected() -> Bool {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let id = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) else { return false }
        return Unmanaged<CFString>.fromOpaque(id).takeUnretainedValue() as String == Bundle.main.bundleIdentifier
    }
}
