import AppKit
import Carbon.HIToolbox
import Combine
import ServiceManagement

/// A key plus modifiers, stored with Carbon modifier flags (what RegisterEventHotKey expects).
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + key
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }

    static func keyName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1...kVK_F12:
            let fKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12]
            return "F\((fKeys.firstIndex(of: Int(event.keyCode)) ?? 0) + 1)"
        default:
            return (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}

enum HotkeyAction: String, CaseIterable, Identifiable {
    case quickPad, editor
    var id: String { rawValue }
    var label: String {
        switch self {
        case .quickPad: return "Show Quick Pad"
        case .editor: return "Open ZenPad"
        }
    }
    var defaultCombo: KeyCombo {
        let mods = UInt32(controlKey | optionKey)
        switch self {
        case .quickPad: return KeyCombo(keyCode: UInt32(kVK_ANSI_N), modifiers: mods, key: "N")
        case .editor: return KeyCombo(keyCode: UInt32(kVK_ANSI_Z), modifiers: mods, key: "Z")
        }
    }
    var signatureID: UInt32 { self == .quickPad ? 1 : 2 }
}

/// System-wide shortcuts via Carbon hot keys. These don't need Accessibility permission.
final class HotkeyCenter: ObservableObject {
    static let shared = HotkeyCenter()

    @Published private(set) var combos: [HotkeyAction: KeyCombo] = [:]
    var handler: ((HotkeyAction) -> Void)?

    private var refs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private let store = Prefs.shared.store

    private init() {
        for action in HotkeyAction.allCases {
            let key = "hotkey.\(action.rawValue)"
            if let data = store.data(forKey: key) {
                if let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) { combos[action] = combo }
            } else {
                combos[action] = action.defaultCombo
            }
        }
    }

    func start() {
        installHandler()
        registerAll()
    }

    func set(_ combo: KeyCombo?, for action: HotkeyAction) {
        combos[action] = combo
        let key = "hotkey.\(action.rawValue)"
        if let combo, let data = try? JSONEncoder().encode(combo) {
            store.set(data, forKey: key)
        } else {
            store.set(Data(), forKey: key)
        }
        registerAll()
    }

    func resetToDefaults() {
        for action in HotkeyAction.allCases { set(action.defaultCombo, for: action) }
    }

    /// Pauses hot keys while the shortcut recorder listens, so pressing an existing combo records it.
    func suspend() { unregisterAll() }
    func resume() { registerAll() }

    private func installHandler() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            let raw = id.id
            MainActor.assumeIsolated {
                if let action = HotkeyAction.allCases.first(where: { $0.signatureID == raw }) {
                    HotkeyCenter.shared.handler?(action)
                }
            }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }

    private func registerAll() {
        unregisterAll()
        for (action, combo) in combos {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x5A50_4144), id: action.signatureID) // "ZPAD"
            let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs[action] = ref }
        }
    }

    private func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
    }
}

/// Launch at login via SMAppService.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("ZenPad: login item change failed: \(error.localizedDescription)")
        }
    }

    /// True when macOS started ZenPad as a login item (so it should stay quiet).
    static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
