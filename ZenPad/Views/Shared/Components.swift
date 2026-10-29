import AppKit
import SwiftUI

/// NSVisualEffectView for translucent sidebars and panels.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

/// A quiet, borderless icon button with a soft hover state.
struct IconButton: View {
    let symbol: String
    var help: String = ""
    var isActive = false
    var size: CGFloat = 13
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : (hovering ? Color.primary : Color.secondary))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(hovering ? 0.07 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { h in withAnimation(.zenFade) { hovering = h } }
    }
}

/// Write / Split / Preview switcher with a sliding selection pill.
struct ModePicker: View {
    @Binding var mode: EditorMode
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(EditorMode.allCases) { item in
                Button {
                    withAnimation(.zenSpring) { mode = item }
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(mode == item ? Color.primary : Color.secondary)
                        .frame(width: 30, height: 22)
                        .background {
                            if mode == item {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.12), radius: 1.5, y: 0.5)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.label)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}

/// The ensō with a text caret: ZenPad's mark, drawn as a SwiftUI shape.
struct ZenGlyph: View {
    var lineWidth: CGFloat = 2
    var caretColor: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .trim(from: 0.06, to: 0.92)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-62))
                    .padding(lineWidth / 2)
                Capsule()
                    .fill(caretColor)
                    .frame(width: max(1.5, lineWidth * 0.8), height: s * 0.42)
            }
            .frame(width: s, height: s)
        }
    }
}

enum MenuBarIcon {
    /// A template image of the ensō for the status item.
    static func image() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let path = NSBezierPath()
            path.appendArc(withCenter: center, radius: 6.6, startAngle: 72, endAngle: 72 + 300, clockwise: false)
            path.lineWidth = 1.9
            path.lineCapStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            let caret = NSBezierPath(roundedRect: NSRect(x: center.x - 0.8, y: center.y - 3.4, width: 1.6, height: 6.8), xRadius: 0.8, yRadius: 0.8)
            NSColor.black.setFill()
            caret.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ZenPad"
        return image
    }
}

/// Small rounded "chip" used for keyboard hints.
struct KeyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.07)))
    }
}

extension Date {
    /// "Just now", "5 min ago", "Yesterday", "12 Mar".
    var zenRelative: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }
        if Calendar.current.isDateInToday(self) { return formatted(date: .omitted, time: .shortened) }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        if seconds < 6 * 86400 { return formatted(.dateTime.weekday(.wide)) }
        return formatted(.dateTime.day().month(.abbreviated))
    }
}
