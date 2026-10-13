import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom.
enum Brand {
    static let name = "Allege"
    static let displayName = "Allège"
    static let accent = Color(hex: 0x2E9D6E)
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
