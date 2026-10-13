import AppKit
import VialetKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Mode capture : ni raccourci global, ni reseau.
        if runSnapshotIfRequested() { return }
        if writeHubManifestIfRequested() { return }
        #endif
        AppActions.shared.publish()
        HotKeyController.shared.start { WindowSummoner.toggle() }
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
        }
    }

    /// « Ouvrir avec Allège » dans le Finder, ou glisser sur l'icone du Dock ; liens `allege://`
    /// (`allege://ouvrir-images` choisit des images, `allege://update` verifie les mises a jour).
    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty {
            AppState.shared.add(files)
            WindowSummoner.show()
        }
        let links = urls.filter { !$0.isFileURL }
        for url in links where !AppActions.shared.handle(url) { WindowSummoner.show() }
    }

    /// L'app reste disponible (raccourci global, barre des menus) fenetre fermee.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowSummoner.show() }
        return true
    }
}

#if DEBUG
extension AppDelegate {
    /// `Allege -AllegeHubManifest <dossier>` : ecrit la fiche pour Vialet dans le dossier (sans la condition
    /// du dossier Applications, sans prevenir Vialet), imprime son chemin et quitte.
    func writeHubManifestIfRequested() -> Bool {
        guard let path = UserDefaults.standard.string(forKey: Brand.key("HubManifest")) else { return false }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        do {
            try AppActions.shared.manifest().write(to: directory)
            print("fiche : \(HubManifest.fileURL(bundleIdentifier: Brand.identity.bundleIdentifier, in: directory).path)")
        } catch {
            print("fiche non ecrite : \(error)")
        }
        exit(0)
    }
}

/// Mode capture sans ecran (voir SnapshotRunner) : `Allege -AllegeSnapshot <dossier>
/// [-AllegeSnapshotFiles "a.jpg,b.png"] [-AllegeSnapshotProcess 1] [-AllegeOutputFolder <dossier>]
/// [-AllegeSnapshotAppearance dark] [-AllegeSnapshotOnly a,b] [-AllegeSnapshotSize 1000x720]`.
/// Ajoute les fichiers (images d'exemple neutres, voir brand/exemples du depot vialetapps), ecrit
/// `mainWindow` (file d'attente et estimations), `settings`, `about` puis, avec SnapshotProcess,
/// `resultats` (apres traitement), `actionOuvrirImages` (action rapide `allege://ouvrir-images`) ;
/// `-sombre` en sombre. Quitte ensuite.
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
        // Action rapide de Vialet, par son URL : la fenetre de choix des images (modale, hors processus,
        // donc non capturee) est signalee puis fermee par une minuterie qui tourne pendant la boucle
        // modale ; capture de la fenetre principale.
        scenarios.append(SnapshotScenario("actionOuvrirImages") {
            let check = Timer(timeInterval: 2, repeats: false) { _ in
                MainActor.assumeIsolated {
                    let panel = NSApp.windows.contains { $0 is NSOpenPanel && $0.isVisible }
                    print("actionOuvrirImages : fenetre de choix \(panel ? "ouverte" : "absente")")
                    NSApp.abortModal()
                }
            }
            RunLoop.main.add(check, forMode: .common)
            AppActions.shared.handle(URL(string: "allege://ouvrir-images")!)
            try await Task.sleep(for: .seconds(3))
            return WindowSummoner.mainWindow
        })
        return SnapshotRunner.runIfRequested(prefix: Brand.name, scenarios: scenarios)
    }
}
#endif
