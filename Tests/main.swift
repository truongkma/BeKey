// Self-check for Engine: run via ./build.sh (fails the build on any mismatch).
import Foundation
let telex = Engine(method: .telex)
let vni = Engine(method: .vni)
var failed = 0
func check(_ e: Engine, _ input: String, _ want: String) {
    let got = e.convert(input)
    if got != want { failed += 1; print("FAIL [\(e.method)] \(input) -> \(got), want \(want)") }
}

for (i, o) in [
    ("vieejt", "việt"), ("tieengs", "tiếng"), ("nguwowif", "người"), ("dduwowngf", "đường"),
    ("hoaf", "hoà"), ("khoer", "khoẻ"), ("thuys", "thuý"), ("toans", "toán"), ("quas", "quá"),
    ("giaf", "già"), ("gif", "gì"), ("khoais", "khoái"), ("tw", "tư"), ("aw", "ă"), ("muaf", "mùa"),
    ("Vieejt", "Việt"), ("DDaay", "Đây"), ("ass", "as"), ("tesst", "test"), ("Tesst", "Test"), ("classs", "class"), ("aaa", "aa"), ("ddd", "dd"),
    ("telex", "telex"), ("thuowr", "thuở"), ("khoeo", "khoeo"), ("hoawcj", "hoặc"), ("giuwowngf", "giường"), ("quoocs", "quốc"),
    ("hoafz", "hoa"), ("hoaz", "hoaz"), ("html", "html"), ("class", "clas"), ("nexxt", "next"), ("cars", "cá"),
] { check(telex, i, o) }

for (i, o) in [
    ("vie65t", "việt"), ("tie61ng", "tiếng"), ("ngu7o72i", "người"), ("d9u7o7ng2", "đường"),
    ("hoa2", "hoà"), ("a8", "ă"), ("a11", "a1"), ("qua1", "quá"), ("Vie65t", "Việt"),
] { check(vni, i, o) }

var classic = telex; classic.modernTone = false
check(classic, "hoaf", "hòa")

print(failed == 0 ? "engine: all tests passed" : "engine: \(failed) failed")
if failed > 0 { exit(1) }

// Round-trip every syllable of the Vietnamese hunspell dictionary (LibreOffice, new tone style):
// encode the word into keystrokes several ways people actually type, convert back, compare.
let toneKeys: [Character: (telex: Character, vni: Character)] =
    ["\u{301}": ("s", "1"), "\u{300}": ("f", "2"), "\u{309}": ("r", "3"), "\u{303}": ("x", "4"), "\u{323}": ("j", "5")]

/// toneEarly: put the tone key right after its vowel instead of at the end of the word.
func encode(_ word: String, vni: Bool, toneEarly: Bool, uoShort: Bool = false) -> String {
    var out = "", tone = ""
    for ch in word {
        if ch == "đ" { out += vni ? "d9" : "dd"; continue }
        let scalars = Array(String(ch).decomposedStringWithCanonicalMapping.unicodeScalars)
        let base = Character(scalars[0])
        var keys = String(base), t = ""
        for m in scalars.dropFirst() {
            switch m {
            case "\u{302}": keys += vni ? "6" : String(base)
            case "\u{306}": keys += vni ? "8" : "w"
            case "\u{31B}": keys += vni ? "7" : "w"
            default: let k = toneKeys[Character(m)]!; t = String(vni ? k.vni : k.telex)
            }
        }
        // Telex: a 2nd plain a/e/o right after the same letter must be typed 3x ("booong" -> boong)
        if !vni, !scalars.contains("\u{302}"), "aeo".contains(base), out.last == base { keys += String(base) }
        out += keys
        if toneEarly { out += t } else if !t.isEmpty { tone = t }
    }
    if uoShort { out = out.replacingOccurrences(of: "uwow", with: "uow") }   // "nguowif" style
    return out + tone
}

let words = (try? String(contentsOfFile: "Tests/syllables.txt", encoding: .utf8))?.split(separator: "\n").map(String.init) ?? []
var corpusFails = 0
for word in words {
    var cases = [(telex, encode(word, vni: false, toneEarly: false)), (telex, encode(word, vni: false, toneEarly: true)),
                 (vni, encode(word, vni: true, toneEarly: false)), (vni, encode(word, vni: true, toneEarly: true))]
    if word.contains("ươ") { cases.append((telex, encode(word, vni: false, toneEarly: false, uoShort: true))) }
    for (e, keys) in cases {
        let got = e.convert(keys)
        if got != word { corpusFails += 1; if corpusFails <= 40 { print("CORPUS FAIL [\(e.method)] \(keys) -> \(got), want \(word)") } }
    }
    // Capitalised words must work too.
    let cap = word.prefix(1).uppercased() + word.dropFirst()
    let got = telex.convert(encode(cap, vni: false, toneEarly: false).replacingOccurrences(of: "DD", with: "Dd"))
    if got != cap { corpusFails += 1; if corpusFails <= 40 { print("CORPUS FAIL [cap] \(cap) -> \(got)") } }
}
print("corpus: \(words.count) syllables, \(corpusFails) failures")
if words.isEmpty || corpusFails > 0 { exit(1) }
