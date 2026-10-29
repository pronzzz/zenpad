import AppKit
import SwiftUI

/// ZenPad's small palette. Everything adapts to light and dark appearance.
enum Palette {
    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    /// Warm paper in light mode, soft graphite in dark mode.
    static let paper = dynamic(light: NSColor(srgbRed: 0.992, green: 0.990, blue: 0.982, alpha: 1),
                               dark: NSColor(srgbRed: 0.110, green: 0.110, blue: 0.118, alpha: 1))
    static let ink = dynamic(light: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1),
                             dark: NSColor(srgbRed: 0.90, green: 0.90, blue: 0.89, alpha: 1))
    static let markup = dynamic(light: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 0.30),
                                dark: NSColor(srgbRed: 0.90, green: 0.90, blue: 0.89, alpha: 0.30))
    static let muted = dynamic(light: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 0.58),
                               dark: NSColor(srgbRed: 0.90, green: 0.90, blue: 0.89, alpha: 0.58))
    static let dimmed = dynamic(light: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 0.24),
                                dark: NSColor(srgbRed: 0.90, green: 0.90, blue: 0.89, alpha: 0.22))
    static let codeFill = dynamic(light: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 0.045),
                                  dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.06))
    static let hairline = dynamic(light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
                                  dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08))
    static var accent: NSColor { .controlAccentColor }
}

extension Color {
    static let zenPaper = Color(nsColor: Palette.paper)
    static let zenInk = Color(nsColor: Palette.ink)
    static let zenMuted = Color(nsColor: Palette.muted)
    static let zenHairline = Color(nsColor: Palette.hairline)
}

/// Everything the editor needs to draw text, derived from preferences.
struct EditorTheme: Equatable {
    var font: NSFont
    var codeFont: NSFont
    var lineHeightMultiple: CGFloat
    var maxLineWidth: CGFloat?
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat

    static func main(from prefs: Prefs) -> EditorTheme {
        let size = CGFloat(prefs.fontSize)
        return EditorTheme(
            font: FontCatalog.font(for: prefs.fontID, size: size),
            codeFont: FontCatalog.font(for: prefs.codeFontID, size: size * 0.88),
            lineHeightMultiple: CGFloat(prefs.lineHeight),
            maxLineWidth: prefs.lineWidth.points,
            horizontalPadding: 40,
            verticalPadding: 28
        )
    }

    static func quickPad(from prefs: Prefs) -> EditorTheme {
        let size: CGFloat = 14.5
        return EditorTheme(
            font: FontCatalog.font(for: prefs.fontID, size: size),
            codeFont: FontCatalog.font(for: prefs.codeFontID, size: size * 0.88),
            lineHeightMultiple: 1.35,
            maxLineWidth: nil,
            horizontalPadding: 14,
            verticalPadding: 10
        )
    }
}

/// Shared animation curves so motion feels consistent across the app.
extension Animation {
    static let zenSpring = Animation.spring(response: 0.36, dampingFraction: 0.86)
    static let zenSnappy = Animation.spring(response: 0.26, dampingFraction: 0.9)
    static let zenFade = Animation.easeOut(duration: 0.2)
}
