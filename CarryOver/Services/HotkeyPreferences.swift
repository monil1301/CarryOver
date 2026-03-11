//
//  HotkeyPreferences.swift
//  CarryOver
//
//  Created by Monil Shah on 06/03/26.
//

import Foundation
import AppKit
import HotKey

struct HotkeyService {
    static let keyName = "hotkey.keyName"
    static let useCommand = "hotkey.mod.cmd"
    static let useOption  = "hotkey.mod.opt"
    static let useControl = "hotkey.mod.ctrl"
    static let useShift   = "hotkey.mod.shift"

    // Default: Ctrl + Opt + Space
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            keyName: "space",
            useCommand: false,
            useOption: true,
            useControl: true,
            useShift: false
        ])
    }

    static func load() -> (key: Key, modifiers: NSEvent.ModifierFlags) {
        let name = UserDefaults.standard.string(forKey: keyName) ?? "space"
        let key = keyFromName(name) ?? .space

        var mods: NSEvent.ModifierFlags = []
        if UserDefaults.standard.bool(forKey: useCommand) { mods.insert(.command) }
        if UserDefaults.standard.bool(forKey: useOption)  { mods.insert(.option) }
        if UserDefaults.standard.bool(forKey: useControl) { mods.insert(.control) }
        if UserDefaults.standard.bool(forKey: useShift)   { mods.insert(.shift) }

        if mods.isEmpty { mods = [.control, .option] } // safety

        return (key, mods)
    }

    static func save(keyName name: String, modifiers: NSEvent.ModifierFlags) {
        UserDefaults.standard.set(name, forKey: keyName)
        UserDefaults.standard.set(modifiers.contains(.command), forKey: useCommand)
        UserDefaults.standard.set(modifiers.contains(.option),  forKey: useOption)
        UserDefaults.standard.set(modifiers.contains(.control), forKey: useControl)
        UserDefaults.standard.set(modifiers.contains(.shift),   forKey: useShift)
    }

    // MARK: - Key mapping we control (no rawValue needed)

    static let availableKeys: [(name: String, key: Key)] = [
        ("space", .space),
        ("return", .return),
        ("tab", .tab),

        ("a", .a), ("b", .b), ("c", .c), ("d", .d), ("e", .e), ("f", .f),
        ("g", .g), ("h", .h), ("i", .i), ("j", .j), ("k", .k), ("l", .l),
        ("m", .m), ("n", .n), ("o", .o), ("p", .p), ("q", .q), ("r", .r),
        ("s", .s), ("t", .t), ("u", .u), ("v", .v), ("w", .w), ("x", .x),
        ("y", .y), ("z", .z)
    ]

    static func keyName(fromKeyCode keyCode: UInt16, characters: String?) -> String? {
        switch keyCode {
        case KeyCode.space: return "space"
        case KeyCode.returnKey, KeyCode.enter: return "return"
        case KeyCode.tab: return "tab"
        default: break
        }
        if let chars = characters?.lowercased(), chars.count == 1,
           let c = chars.first, c >= "a" && c <= "z" {
            return String(c)
        }
        return nil
    }

    static func keyFromName(_ name: String) -> Key? {
        availableKeys.first(where: { $0.name == name })?.key
    }
    
    static func format(keyName: String, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        let keyPart: String
        switch keyName {
        case "space":  keyPart = "Space"
        case "return": keyPart = "Return"
        case "tab":    keyPart = "Tab"
        default:       keyPart = keyName.uppercased()
        }
        parts.append(keyPart)
        return parts.joined()
    }

    static func currentShortcutString() -> String {
        let (key, mods) = load()
        // Convert Key -> name by scanning our mapping
        let name = availableKeys.first(where: { $0.key == key })?.name ?? "space"
        return format(keyName: name, modifiers: mods)
    }
}
