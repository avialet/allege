import AppKit
import VialetKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyController.shared.start { WindowSummoner.toggle() }
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
        }
        #if DEBUG
        runSnapshotIfRequested()
        #endif
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
/// Mode de verification sans ecran : `Allege -AllegeSnapshot /chemin/base -AllegeSnapshotFiles "a.jpg,b.png" -AllegeSnapshotProcess 1`
/// ajoute les fichiers, capture la fenetre (`base-1.png`), traite, capture (`base-2.png`), quitte.
extension AppDelegate {
    func runSnapshotIfRequested() {
        let defaults = UserDefaults.standard
        guard let base = defaults.string(forKey: "AllegeSnapshot") else { return }
        let files = (defaults.string(forKey: "AllegeSnapshotFiles") ?? "").split(separator: ",").map { URL(fileURLWithPath: String($0)) }
        let process = defaults.bool(forKey: "AllegeSnapshotProcess")
        Task { @MainActor in
            if !files.isEmpty { AppState.shared.add(files) }
            try? await Task.sleep(for: .seconds(2))
            if let window = WindowSummoner.mainWindow { try? WindowSnapshot.write(window, to: URL(fileURLWithPath: base + "-1.png")) }
            if process {
                AppState.shared.processAll()
                while AppState.shared.isProcessing { try? await Task.sleep(for: .milliseconds(200)) }
                try? await Task.sleep(for: .seconds(1))
                if let window = WindowSummoner.mainWindow { try? WindowSnapshot.write(window, to: URL(fileURLWithPath: base + "-2.png")) }
                for item in AppState.shared.items {
                    print("\(item.name): \(item.state)")
                }
            }
            NSApp.terminate(nil)
        }
    }
}
#endif
