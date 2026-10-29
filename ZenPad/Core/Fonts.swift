import AppKit

/// A font the editor can use. IDs are either a built-in design ("system", "serif", "mono", "rounded")
/// or "family:<Family Name>" for any installed font family.
struct FontChoice: Identifiable, Hashable {
    enum Kind: String { case sans = "Sans Serif", serif = "Serif", mono = "Monospaced" }
    let id: String
    let name: String
    let kind: Kind
}

enum FontCatalog {
    static let defaultFontID = "serif"

    /// The four system designs, always available.
    static let designs: [FontChoice] = [
        FontChoice(id: "serif", name: "New York", kind: .serif),
        FontChoice(id: "system", name: "SF Pro", kind: .sans),
        FontChoice(id: "rounded", name: "SF Pro Rounded", kind: .sans),
        FontChoice(id: "mono", name: "SF Mono", kind: .mono),
    ]

    /// Hand-picked writing fonts that ship with macOS; only installed ones are offered.
    private static let curated: [(String, FontChoice.Kind)] = [
        ("Charter", .serif), ("Iowan Old Style", .serif), ("Georgia", .serif), ("Palatino", .serif),
        ("Baskerville", .serif), ("Hoefler Text", .serif), ("Athelas", .serif),
        ("Avenir Next", .sans), ("Helvetica Neue", .sans), ("Gill Sans", .sans), ("Optima", .sans), ("Futura", .sans),
        ("Menlo", .mono), ("Courier New", .mono), ("American Typewriter", .serif),
    ]

    static let curatedFamilies: [FontChoice] = {
        let installed = Set(NSFontManager.shared.availableFontFamilies)
        return curated.filter { installed.contains($0.0) }.map { FontChoice(id: "family:\($0.0)", name: $0.0, kind: $0.1) }
    }()

    static var allFamilies: [String] { NSFontManager.shared.availableFontFamilies.sorted() }

    static let monoChoices: [FontChoice] = {
        var list = [designs[3]]
        list += curatedFamilies.filter { $0.kind == .mono }
        return list
    }()

    static func displayName(for id: String) -> String {
        if let design = designs.first(where: { $0.id == id }) { return design.name }
        if id.hasPrefix("family:") { return String(id.dropFirst(7)) }
        return "New York"
    }

    static func font(for id: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        switch id {
        case "system":
            return base
        case "serif":
            return base.withDesign(.serif)
        case "rounded":
            return base.withDesign(.rounded)
        case "mono":
            return .monospacedSystemFont(ofSize: size, weight: weight)
        default:
            if id.hasPrefix("family:") {
                let family = String(id.dropFirst(7))
                let nsWeight = weight == .regular ? 5 : (weight == .bold ? 9 : 6)
                if let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: nsWeight, size: size) {
                    return font
                }
            }
            return base.withDesign(.serif)
        }
    }

    /// CSS font-family stack matching the editor font, for the preview and exports.
    static func css(for id: String) -> String {
        switch id {
        case "system": return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif"
        case "serif": return "ui-serif, 'New York', Georgia, serif"
        case "rounded": return "ui-rounded, 'SF Pro Rounded', -apple-system, sans-serif"
        case "mono": return "ui-monospace, 'SF Mono', Menlo, monospace"
        default:
            if id.hasPrefix("family:") {
                let family = String(id.dropFirst(7)).replacingOccurrences(of: "'", with: "")
                return "'\(family)', -apple-system, sans-serif"
            }
            return "ui-serif, Georgia, serif"
        }
    }
}

extension NSFont {
    func withDesign(_ design: NSFontDescriptor.SystemDesign) -> NSFont {
        guard let descriptor = fontDescriptor.withDesign(design) else { return self }
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }

    /// The same font with bold and/or italic traits, falling back gracefully when a family lacks them.
    func with(bold: Bool = false, italic: Bool = false) -> NSFont {
        guard bold || italic else { return self }
        var traits = fontDescriptor.symbolicTraits
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        if let font = NSFont(descriptor: descriptor, size: pointSize),
           font.fontDescriptor.symbolicTraits.contains(traits) {
            return font
        }
        var result = self
        if bold { result = NSFontManager.shared.convert(result, toHaveTrait: .boldFontMask) }
        if italic { result = NSFontManager.shared.convert(result, toHaveTrait: .italicFontMask) }
        return result
    }

    func sized(_ size: CGFloat) -> NSFont {
        NSFont(descriptor: fontDescriptor, size: size) ?? self
    }
}
