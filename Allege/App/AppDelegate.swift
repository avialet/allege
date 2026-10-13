import AppKit
import VialetKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Mode capture : ni raccourci global, ni reseau.
        if runSnapshotIfRequested() { return }
        #endif
        HotKeyController.shared.start { WindowSummoner.toggle() }
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
        }
    }

    /// « Ouvrir avec Allège » dans le Finder, ou glisser sur l'icone du Dock.
    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty { AppState.shared.add(files) }
        WindowSummoner.show()
    }

    /// L'app reste disponible (raccourci global, barre des menus) fenetre fermee.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowSummoner.show() }
        return true
    }
}

#if DEBUG
/// Mode capture sans ecran (voir SnapshotRunner) : `Allege -AllegeSnapshot <dossier>
/// [-AllegeSnapshotFiles "a.jpg,b.png"] [-AllegeSnapshotProcess 1] [-AllegeOutputFolder <dossier>]
/// [-AllegeSnapshotAppearance dark] [-AllegeSnapshotOnly a,b] [-AllegeSnapshotSize 1000x720]`.
/// Ajoute les fichiers (images d'exemple neutres, voir brand/exemples du depot vialetapps), ecrit
/// `mainWindow` (file d'attente et estimations), `settings`, `about` puis, avec SnapshotProcess,
/// `resultats` (apres traitement) ; `-sombre` en sombre. Quitte ensuite.
extension AppDelegate {
    func runSnapshotIfRequested() -> Bool {
        guard SnapshotRequest.parse(prefix: Brand.name, arguments: CommandLine.arguments) != nil else { return false }
        let defaults = UserDefaults.standard
        let files = (defaults.string(forKey: Brand.key("SnapshotFiles")) ?? "")
            .split(separator: ",").map { URL(fileURLWithPath: String($0)) }
        if !files.isEmpty { AppState.shared.add(files) }
        let standard = SnapshotRunner.standardScenarios(mainWindow: { WindowSummoner.mainWindow }, identity: Brand.identity)
            .filter { $0.name != "floatingPanel" } // pas de panneau flottant dans Allege
        var scenarios = standard
        if defaults.bool(forKey: Brand.key("SnapshotProcess")) {
            scenarios.append(SnapshotScenario("resultats") {
                let state = AppState.shared
                state.processAll()
                while state.isProcessing { try await Task.sleep(for: .milliseconds(200)) }
                WindowSummoner.show()
                try await Task.sleep(for: .seconds(1))
                return WindowSummoner.mainWindow
            })
        }
        return SnapshotRunner.runIfRequested(prefix: Brand.name, scenarios: scenarios)
    }
}
#endif
