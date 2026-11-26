import Cocoa
import Carbon
import InputMethodKit

let bundle = Bundle.main

// `BeKey --install`: register + enable this input source without logging out.
if CommandLine.arguments.contains("--install") {
    TISRegisterInputSource(bundle.bundleURL as CFURL)
    let filter = [kTISPropertyBundleID as String: bundle.bundleIdentifier!] as CFDictionary
    let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
    sources.forEach { TISEnableInputSource($0) }
    let enabled = sources.contains { source in
        TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled)
            .map { Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue() == kCFBooleanTrue } ?? false
    }
    // macOS 26 returns noErr but ignores programmatic enabling: the user must add it once.
    print(enabled ? "BeKey: installed and enabled"
                  : "BeKey: installed. First time only: Keyboard > Input Sources > Edit > + > Vietnamese > BeKey")
    if !enabled { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) }
    exit(sources.isEmpty ? 1 : 0)
}

UserDefaults.standard.removeObject(forKey: "noCaretApps")   // per-app memory of v1.0.2–1.0.6
// Typing with real keys (KeyTap) needs Accessibility. The system prompt may not show for a background-only
// app, so also open the Accessibility pane; the prompt call lists BeKey there. Once per version, not per login.
let version = bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
if !AXIsProcessTrusted(), UserDefaults.standard.string(forKey: "askedAccessibility") != version {
    UserDefaults.standard.set(version, forKey: "askedAccessibility")
    _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
}
let server = IMKServer(name: bundle.infoDictionary!["InputMethodConnectionName"] as? String,
                       bundleIdentifier: bundle.bundleIdentifier)
_ = server
NSApplication.shared.run()
