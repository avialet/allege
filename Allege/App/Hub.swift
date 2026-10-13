import AppKit
import VialetKit

/// Icone de barre des menus : masquee quand l'app Vialet est installee (reglage Automatique, Toujours, Jamais).
extension MenuBarPresence {
    static let shared = MenuBarPresence(app: Brand.identity)
}

/// Actions rapides (`allege://ouvrir-images`), proposees par l'app Vialet dans son menu.
extension AppActions {
    static let shared: AppActions = {
        let actions = AppActions(Brand.identity, open: { WindowSummoner.show() },
                                 checkForUpdates: { WindowSummoner.show(); Updater.shared.check() })
        actions.register(AppAction("ouvrir-images", title: "Alléger des images", symbol: "photo.stack", shortcut: "⌘O")) {
            WindowSummoner.show()
            // Hors du traitement de l'evenement d'ouverture : la fenetre de choix est modale.
            DispatchQueue.main.async { MainActor.assumeIsolated { AppState.shared.chooseFiles() } }
        }
        return actions
    }()
}
