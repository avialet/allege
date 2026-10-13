import SwiftUI
import VialetKit

@main
struct AllegeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState.shared
    @AppStorage(Brand.key("MenuBar")) private var menuBarVisible = true

    /// Teintes de l'app avant le premier rendu (et police Bricolage Grotesque des titres).
    init() { Theme.configure(Brand.palette) }

    var body: some Scene {
        Window(Brand.displayName, id: "main") {
            MainWindow()
                .environment(state)
                .fontDesign(.rounded)
                .frame(minWidth: 840, minHeight: 620)
                .onAppear { AppearanceChoice.current(defaultsKey: Brand.key("Appearance")).apply(defaultsKey: Brand.key("Appearance")) }
                .captureOpenWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 1000, height: 720)
        .commands {
            AboutCommands(identity: Brand.identity)
            UpdateCommands(updater: .shared)
            AllegeCommands(state: state)
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra(isInserted: $menuBarVisible) {
            MenuBarContent().environment(state)
        } label: {
            MenuBarIcon(glyph: Brand.glyph)
        }
    }
}

struct AllegeCommands: Commands {
    let state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Ajouter des images…") { state.chooseFiles() }.keyboardShortcut("o")
        }
        CommandMenu("Images") {
            Button("Alléger") { state.processAll() }.keyboardShortcut(.return, modifiers: .command)
                .disabled(state.pendingCount == 0 || state.isProcessing)
            Button("Afficher les résultats dans le Finder") { state.revealResults() }.keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(state.doneResults.isEmpty)
            Divider()
            Button("Vider la liste") { state.clear() }.keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(state.items.isEmpty || state.isProcessing)
        }
    }
}
