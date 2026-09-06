import SwiftUI

enum Palette {
    static let background = Color(red: 0x13 / 255, green: 0x13 / 255, blue: 0x1D / 255)
    static let elevated = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x24 / 255)
    static let selectedRow = Color(red: 0x34 / 255, green: 0x34 / 255, blue: 0x3C / 255)
    static let divider = Color(red: 0x29 / 255, green: 0x29 / 255, blue: 0x31 / 255)
    static let foreground = Color(red: 0xC8 / 255, green: 0xC8 / 255, blue: 0xC8 / 255)
    static let dim = foreground.opacity(0.56)
    static let accent = Color(red: 0x7C / 255, green: 0x7C / 255, blue: 0xA8 / 255)
    static let favorite = Color(red: 0xF2 / 255, green: 0xC9 / 255, blue: 0x4C / 255)
    static let urgent = Color(red: 0xE0 / 255, green: 0x5A / 255, blue: 0x5A / 255)
    static let globePaneBackground = Color(red: 0x09 / 255, green: 0x0A / 255, blue: 0x0C / 255)

    static let monoTitle = Font.system(.title3, design: .monospaced).bold()
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoCaption = Font.system(.caption, design: .monospaced)
}
