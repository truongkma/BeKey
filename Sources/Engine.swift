import Foundation

enum TypingMethod: String { case telex, vni }

enum Mod { case none, circ, breve, horn, stroke }

struct Letter {
    var ch: Character          // lowercase base letter (or a literal digit)
    var mod: Mod = .none
    var upper = false
}

private let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
// sắc, huyền, hỏi, ngã, nặng
private let toneMarks: [Character] = ["\u{301}", "\u{300}", "\u{309}", "\u{303}", "\u{323}"]
private let finals: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]
private let telexTones: [Character: Int] = ["z": 0, "s": 1, "f": 2, "r": 3, "x": 4, "j": 5]
private let vniTones: [Character: Int] = ["0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5]

/// Stateless: rebuilds the whole word from its raw keystrokes every time,
/// so there is no hidden state that can get out of sync with the screen.
struct Engine {
    var method: TypingMethod = .telex
    var modernTone = true   // true: hoà, khoẻ, thuý — false: hòa, khỏe, thúy

    func convert(_ keys: String) -> String {
        var w: [Letter] = []
        var tone = 0
        for k in keys {
            let c = Character(k.lowercased())
            if !apply(c, &w, &tone) { w.append(Letter(ch: c, upper: k.isUppercase)) }
        }
        // Not one Vietnamese syllable (e.g. "telex", "html") -> keep the raw keys.
        return vowelGroups(w) > 1 || !hasValidFinal(w) ? keys : render(w, tone)
    }

    /// Returns true if key `c` was consumed as a transform, false if it should be appended literally.
    private func apply(_ c: Character, _ w: inout [Letter], _ tone: inout Int) -> Bool {
        let tones = method == .telex ? telexTones : vniTones
        if let t = tones[c] { return setTone(t, w, &tone) }
        switch (method, c) {
        case (.telex, "a"), (.telex, "e"), (.telex, "o"):
            // only the last vowel of the word: "khoeo" stays "khoeo"
            guard let i = w.lastIndex(where: { vowels.contains($0.ch) }), w[i].ch == c else { return false }
            return toggle(&w, .circ) { $0 == c }
        case (.vni, "6"):
            return toggle(&w, .circ) { "aeo".contains($0) }
        case (.telex, "w"):
            if hornUO(&w) { return true }
            // w modifies the last of a/o/u: "hoaw" -> "hoă", "thow" -> "thơ"
            if let i = w.lastIndex(where: { "aou".contains($0.ch) }) {
                let mod: Mod = w[i].ch == "a" ? .breve : .horn
                if w[i].mod == mod { w[i].mod = .none; return false }
                w[i].mod = mod
                return true
            }
            if w.contains(where: { vowels.contains($0.ch) }) { return false }
            w.append(Letter(ch: "u", mod: .horn))   // standalone w -> ư
            return true
        case (.vni, "7"):
            return hornUO(&w) || toggle(&w, .horn) { "ou".contains($0) }
        case (.vni, "8"):
            return toggle(&w, .breve) { $0 == "a" }
        case (.telex, "d"), (.vni, "9"):
            return toggle(&w, .stroke) { $0 == "d" }
        default:
            return false
        }
    }

    private func setTone(_ t: Int, _ w: [Letter], _ tone: inout Int) -> Bool {
        guard w.contains(where: { vowels.contains($0.ch) }) else { return false }
        if t == 0 { defer { tone = 0 }; return tone != 0 }
        if tone == t { tone = 0; return false }   // pressed twice -> undo + literal
        tone = t
        return true
    }

    /// Sets `mod` on the last matching letter; pressing again reverts it (returns false -> literal).
    private func toggle(_ w: inout [Letter], _ mod: Mod, _ match: (Character) -> Bool) -> Bool {
        guard let i = w.lastIndex(where: { match($0.ch) }) else { return false }
        if w[i].mod == mod { w[i].mod = .none; return false }
        w[i].mod = mod
        return true
    }

    /// "uo" -> "ươ" (but not after q: "quo" -> "quơ" is handled by the plain o rule).
    private func hornUO(_ w: inout [Letter]) -> Bool {
        guard let i = w.lastIndex(where: { $0.ch == "o" }), i > 0, w[i - 1].ch == "u",
              !(i > 1 && w[i - 2].ch == "q"), w[i].mod != .horn else { return false }
        w[i - 1].mod = .horn
        w[i].mod = .horn
        return true
    }

    private func hasValidFinal(_ w: [Letter]) -> Bool {
        guard let last = w.lastIndex(where: { vowels.contains($0.ch) }) else { return true }
        return finals.contains(String(w[(last + 1)...].map(\.ch)))
    }

    private func vowelGroups(_ w: [Letter]) -> Int {
        var groups = 0, inGroup = false
        for l in w {
            let v = vowels.contains(l.ch)
            if v && !inGroup { groups += 1 }
            inGroup = v
        }
        return groups
    }

    func tonePosition(_ w: [Letter]) -> Int? {
        var idx = w.indices.filter { vowels.contains(w[$0].ch) }
        guard !idx.isEmpty else { return nil }
        // "qu" and "gi" behave as consonants when another vowel follows: quá, già
        if idx.count > 1, idx[0] == 1,
           (w[0].ch == "q" && w[1].ch == "u") || (w[0].ch == "g" && w[1].ch == "i") {
            idx.removeFirst()
        }
        // A marked vowel always takes the tone; in "ươ" it goes on ơ.
        if let i = idx.last(where: { w[$0].ch == "o" && w[$0].mod == .horn }) ?? idx.last(where: { w[$0].mod != .none }) {
            return i
        }
        if idx.last! < w.count - 1 { return idx.last! }   // has final consonant: toán, tiến
        switch idx.count {
        case 1: return idx[0]
        case 2:
            let pair = String(idx.map { w[$0].ch })
            return modernTone && ["oa", "oe", "uy"].contains(pair) ? idx[1] : idx[0]
        default: return idx[1]                            // khoái, người
        }
    }

    private func render(_ w: [Letter], _ tone: Int) -> String {
        var w = w
        // No syllable ends in "ươ": at the end it's "uơ" (huơ, thuở). Typing on ("ng", "i") restores ươ.
        if w.count >= 2, w[w.count - 1].ch == "o", w[w.count - 1].mod == .horn, w[w.count - 2].ch == "u" {
            w[w.count - 2].mod = .none
        }
        let tp = tone > 0 ? tonePosition(w) : nil
        var out = ""
        for (i, l) in w.enumerated() {
            var s = String(l.ch)
            switch l.mod {
            case .circ: s += "\u{302}"
            case .breve: s += "\u{306}"
            case .horn: s += "\u{31B}"
            case .stroke: s = "đ"
            case .none: break
            }
            if i == tp { s.append(toneMarks[tone - 1]) }
            out += l.upper ? s.uppercased() : s
        }
        return out.precomposedStringWithCanonicalMapping   // NFC: a + ̂ + ́ -> ấ
    }
}
