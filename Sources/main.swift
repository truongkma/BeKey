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

let server = IMKServer(name: bundle.infoDictionary!["InputMethodConnectionName"] as? String,
                       bundleIdentifier: bundle.bundleIdentifier)
_ = server
NSApplication.shared.run()
