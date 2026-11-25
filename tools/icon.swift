// Generates the menu-bar icon (a "V" template image). Usage: swift tools/icon.swift out.tiff
import AppKit

let size = NSSize(width: 16, height: 16)
let image = NSImage(size: size, flipped: false) { rect in
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: NSColor.black]
    let text = NSAttributedString(string: "V", attributes: attrs)
    let s = text.size()
    text.draw(at: NSPoint(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2))
    return true
}
try! image.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
