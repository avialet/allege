import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom.
enum Brand {
    static let name = "Allege"
    static let displayName = "Allège"
    static let accent = Color(hex: 0x2E9D6E)
    /// Teintes de l'affiche (sites, plaques, DMG), calculees par scripts/teintes.py : texte `deep` sur `background`.
    static let background: UInt32 = 0x2E9D6E
    static let deep: UInt32 = 0x012B1A
    static let pale: UInt32 = 0xE1F8EB
    static let night: UInt32 = 0x032114
    static let nightInk: UInt32 = 0xB6E4CB
    /// Pictogramme de la plaque : sous-ensemble SVG absolu (M L H V C Q Z), boite 0-100, trait non rempli.
    static let glyph = "M 50 16 L 50 60 M 32 42 L 50 60 L 68 42 M 24 82 L 76 82"
    static let updater = UpdaterConfiguration(repository: "avialet/allege", appName: name,
                                              bundleIdentifier: "fr.vialet.allege", displayName: displayName)

    /// Cles UserDefaults, prefixees par le nom de l'app.
    static func key(_ suffix: String) -> String { name + suffix }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    /// ⌃⌥⌘Espace par defaut : chaque app vialet.app a son propre raccourci (Pico garde ⇧⌘Espace).
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName,
                                         initial: .space([.control, .option, .command]))
}
