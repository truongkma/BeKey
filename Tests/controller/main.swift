// InputController against a fake text field whose caret reports lag behind (Chrome/Slack when typing fast).
import Cocoa
import InputMethodKit

final class Mock: NSObject, IMKTextInput {
    var text: [unichar] = []; var pos = 0; var history: [Int] = [0]; let lag: Int; let app: String
    init(lag: Int, app: String = "com.google.Chrome") { self.lag = lag; self.app = app }
    func record() { history.append(pos) }
    func reported() -> Int { history[max(0, history.count - 1 - lag)] }
    var xterm = false   // Orca's xterm.js: drops inserts that replace text, DEL = Backspace, caret report stays ~1
    func insertText(_ string: Any!, replacementRange r: NSRange) {
        let all = Array(((string as? NSAttributedString)?.string ?? string as! String).utf16)
        if xterm {
            if r.location != NSNotFound { return }
            for u in all { if u == 0x7f { if !text.isEmpty { text.removeLast() } } else { text.append(u) } }
            return
        }
        let s = all.filter { $0 != 0x7f }   // ordinary fields drop DEL
        let range = r.location == NSNotFound ? NSRange(location: pos, length: 0) : r
        text.replaceSubrange(range.location..<range.location + range.length, with: s)
        pos = range.location + s.count; record()
    }
    func typeByApp(_ c: String) { insertText(c, replacementRange: NSRange(location: NSNotFound, length: 0)) }
    func backspaceByApp() { if pos > 0 { text.remove(at: pos - 1); pos -= 1; record() } }
    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) { fatalError("marked") }
    func selectedRange() -> NSRange {
        if xterm { return NSRange(location: 1, length: 0) }
        if staleOnce { staleOnce = false; return NSRange(location: oncePos, length: 0) }
        return NSRange(location: reported(), length: 0)
    }
    func markedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }
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
func run(_ typed: String, _ want: String, lag: Int, prefix: String = "", app: String = "com.google.Chrome", xterm: Bool = false) {
    let m = Mock(lag: lag, app: app); m.xterm = xterm; for c in prefix { m.typeByApp(String(c)) }
    for _ in 0..<lag { m.record() }   // a pause: the app's report catches up
    clock += 5
    let ic = InputController()
    for c in typed {
        if c == "|" {   // pause, then click at the start of the text
            clock += 2; m.pos = 0; for _ in 0...lag { m.record() }
        } else if c == "<" {   // backspace
            if !ic.handle(key("\u{7f}", 51), client: m) { m.backspaceByApp() }
        } else if !ic.handle(key(c), client: m) { m.typeByApp(String(c)) }
    }
    ic.commitComposition(m)
    let ok = m.str == prefix + want
    if !ok { fails += 1 }
    if !ok { print("FAIL lag=\(lag)", typed, "->", m.str) }
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
    if lag < 2 { run("bij thieeus daaus ", "bị thiếu dấu ", lag: lag, app: "com.stablyai.orca") }   // Orca non-terminal field
}
run("ddi tooi ddaay nguwowif ", "đi tôi đây người ", lag: 0, app: "com.stablyai.orca", xterm: true)   // Orca terminal
run("bij thieeus ", "bị thiếu ", lag: 0, app: "com.stablyai.orca", xterm: true)
run("tet thuwr gox nhuwng khoong onr tooi ", "tet thử gõ nhưng không ỏn tôi ", lag: 0, app: "com.stablyai.orca", xterm: true)
run("ddi ", "đi ", lag: 0, app: "com.stablyai.orca", xterm: true)
do {   // realistic: right after Enter the first report is late once, the next key sees the truth
    let m = Mock(lag: 0); let ic = InputController(); clock += 5
    for c in "ddi" { _ = ic.handle(key(c), client: m) }
    _ = ic.handle(key("\r", 36), client: m); let p = m.pos; m.typeByApp("\r"); m.staleOnce = true; m.oncePos = p
    for c in "ddaay " { if !ic.handle(key(c), client: m) { m.typeByApp(String(c)) } }
    let ok = m.str == "đi\rđây "; if !ok { fails += 1 }; if !ok { print("FAIL late-once after Enter ->", m.str) }
}
print(fails == 0 ? "controller: all tests passed" : "controller: \(fails) FAILED")
if fails > 0 { exit(1) }
