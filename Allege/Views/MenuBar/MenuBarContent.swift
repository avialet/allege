import SwiftUI
import VialetKit

struct MenuBarContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Button("Ouvrir \(Brand.displayName)") { WindowSummoner.show() }
        Button("Ajouter des images…") { WindowSummoner.show(); state.chooseFiles() }
        Divider()
        SettingsLink { Text("Réglages…") }
        Button("Quitter") { NSApp.terminate(nil) }
    }
}
