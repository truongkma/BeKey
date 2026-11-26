// InputController against a fake text field whose caret reports lag behind (Chrome/Slack when typing fast).
import Cocoa
import InputMethodKit

final class Mock: NSObject, IMKTextInput {
    var text: [unichar] = []; var pos = 0; var history: [Int] = [0]; let lag: Int; let app: String
    init(lag: Int, app: String = "com.google.Chrome") { self.lag = lag; self.app = app }
    func record() { history.append(pos) }
    func reported() -> Int { history[max(0, history.count - 1 - lag)] }
    /// Apps with xterm.js terminals next to ordinary fields. Measured in VS Code and Orca: a replaced range
    /// wrecks the terminal (resent or dropped) and DEL wrecks the editor (shown as a box), and the two kinds
    /// of field look the same to an input method. So there, only marked text is allowed, ever.
    var composeOnly: Bool { ["com.stablyai.orca", "com.microsoft.VSCode"].contains(app) }
    var mark: NSRange? = nil, broke = ""
    func insertText(_ string: Any!, replacementRange r: NSRange) {
        let s = Array(((string as? NSAttributedString)?.string ?? string as! String).utf16)
        if composeOnly, s.contains(0x7f) { broke = "DEL sent to \(app)" }
        if composeOnly, r.location != NSNotFound { broke = "replacement range sent to \(app)" }
        let range = r.location != NSNotFound ? r : mark ?? NSRange(location: pos, length: 0)   // commits the composition
        mark = nil
        text.replaceSubrange(range.location..<range.location + range.length, with: s)
        pos = range.location + s.count; record()
    }
    func typeByApp(_ c: String) { insertText(c, replacementRange: NSRange(location: NSNotFound, length: 0)) }
    func backspaceByApp() { if pos > 0 { text.remove(at: pos - 1); pos -= 1; record() } }
    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {
        let s = Array(((string as? NSAttributedString)?.string ?? string as! String).utf16)
        let range = mark ?? NSRange(location: pos, length: 0)
        text.replaceSubrange(range.location..<range.location + range.length, with: s)
        mark = s.isEmpty ? nil : NSRange(location: range.location, length: s.count)
        pos = range.location + s.count; record()
    }
    func selectedRange() -> NSRange {
        if staleOnce { staleOnce = false; return NSRange(location: oncePos, length: 0) }
        return NSRange(location: reported(), length: 0)
    }
    func markedRange() -> NSRange { mark ?? NSRange(location: NSNotFound, length: 0) }
    func attributedSubstring(from range: NSRange) -> NSAttributedString! { nil }
    func length() -> Int { text.count }
    func characterIndex(for point: NSPoint, tracking mappingMode: IMKLocationToOffsetMappingMode, inMarkedRange: UnsafeMutablePointer<ObjCBool>!) -> Int { 0 }
    func attributes(forCharacterIndex index: Int, lineHeightRectangle: UnsafeMutablePointer<NSRect>!) -> [AnyHashable: Any]! { [:] }
    func validAttributesForMarkedText() -> [Any]! { [] }
    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {}
    func selectMode(_ modeIdentifier: String!) {}
    func supportsUnicode() -> Bool { true }
    func bundleIdentifier() -> String! { app }
    func windowLevel() -> CGWindowLevel { 0 }
    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { false }
    func uniqueClientIdentifierString() -> String! { "mock" }
    func string(from range: NSRange, actualRange: NSRangePointer!) -> String! { nil }
    func firstRect(forCharacterRange aRange: NSRange, actualRange: NSRangePointer!) -> NSRect { .zero }
    var staleOnce = false, oncePos = 0
    var str: String { String(utf16CodeUnits: text, count: text.count) }
}

var clock: TimeInterval = 100
func key(_ c: Character, _ code: UInt16 = 0) -> NSEvent {
    clock += 0.08
    return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: clock, windowNumber: 0, context: nil,
                     characters: String(c), charactersIgnoringModifiers: String(c), isARepeat: false, keyCode: code)!
}
UserDefaults.standard.set("telex", forKey: "method")   // test process's own defaults domain
var fails = 0
func run(_ typed: String, _ want: String, lag: Int, prefix: String = "", app: String = "com.google.Chrome") {
    let m = Mock(lag: lag, app: app); for c in prefix { m.typeByApp(String(c)) }
    for _ in 0..<lag { m.record() }   // a pause: the app's report catches up
    clock += 5
    let ic = InputController()
    for c in typed {
        if c == "|" {   // pause, then click at the start of the text
            if m.mark != nil { ic.commitComposition(m) }   // apps end the composition on a click
            clock += 2; m.pos = 0; for _ in 0...lag { m.record() }
        } else if c == "<" {   // backspace
            if !ic.handle(key("\u{7f}", 51), client: m) { m.backspaceByApp() }
        } else if !ic.handle(key(c), client: m) { m.typeByApp(String(c)) }
    }
    ic.commitComposition(m)
    let ok = m.str == prefix + want && m.broke.isEmpty && m.mark == nil
    if !ok { fails += 1 }
    if !ok { print("FAIL lag=\(lag) \(app)", typed, "->", m.str, m.broke, m.mark == nil ? "" : "composition left open") }
}
for lag in 0...2 {
    run("ddaay tooi ddaay nguwowif ", "đây tôi đây người ", lag: lag)
    run("Vieejt Nam hoawcj tieengs ", "Việt Nam hoặc tiếng ", lag: lag, prefix: "xin ")
    run("ddaaay<<y ", "đây ", lag: lag)
    run("tesst ", "test ", lag: lag)
    run("ddi|ddaay ", "đây đi", lag: lag)
    run("ddi <ddaay ", "điđây ", lag: lag)
    if lag == 0 { run("ddi\rddaay ", "đi\rđây ", lag: lag) }
    run("toi ddi. ddaay, ok ", "toi đi. đây, ok ", lag: lag)
    for app in ["com.stablyai.orca", "com.microsoft.VSCode"] {   // terminal or not: always composed
        run("tooi ddang test gox thuwr nhuwng khoong bij thieeus daaus ", "tôi đang tét gõ thử nhưng không bị thiếu dấu ", lag: lag, app: app)
        run("ddi ddaay Vieejt Nam nguwowif hoawcj tieengs ", "đi đây Việt Nam người hoặc tiếng ", lag: lag, prefix: "xin ", app: app)
        run("ddaaay<<y tesst ddi|ddaay ", "đây đây test đi", lag: lag, app: app)
        run("ddi<<<<tooi\rddi ", "tôi\rđi ", lag: lag, app: app)
    }
}
do {   // realistic: right after Enter the first report is late once, the next key sees the truth
    let m = Mock(lag: 0); let ic = InputController(); clock += 5
    for c in "ddi" { _ = ic.handle(key(c), client: m) }
    _ = ic.handle(key("\r", 36), client: m); let p = m.pos; m.typeByApp("\r"); m.staleOnce = true; m.oncePos = p
    for c in "ddaay " { if !ic.handle(key(c), client: m) { m.typeByApp(String(c)) } }
    let ok = m.str == "đi\rđây "; if !ok { fails += 1 }; if !ok { print("FAIL late-once after Enter ->", m.str) }
}
print(fails == 0 ? "controller: all tests passed" : "controller: \(fails) FAILED")
if fails > 0 { exit(1) }
