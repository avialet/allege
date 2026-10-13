import SwiftUI
import VialetKit
import AllegeCore

/// Colonne de droite : comment, dans quel format, ou, et le bouton.
struct PresetPanel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 16) {
            section("Comment ?") {
                VStack(spacing: 6) {
                    ForEach(ExportPreset.all) { preset in
                        PresetCard(preset: preset, selected: state.preset.id == preset.id) {
                            state.preset = preset
                            state.resetDone()
                        }
                    }
                }
            }

            section("Quel format ?") {
                Picker("", selection: $state.formatOverride) {
                    Text("Comme le préréglage").tag(OutputFormat?.none)
                    ForEach(OutputFormat.writable) { f in Text(f.label).tag(OutputFormat?.some(f)) }
                }
                .labelsHidden()
                .onChange(of: state.formatOverride) { _, _ in state.resetDone() }
                Text(state.effectivePreset.format.hint)
                    .font(Theme.ui(11.5)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }

            section("Où ?") {
                HStack(spacing: 8) {
                    Picker("", selection: Binding(
                        get: { state.outputFolder == nil ? 0 : 1 },
                        set: { if $0 == 0 { state.outputFolder = nil } else { state.chooseOutputFolder() } })) {
                        Text("À côté de l'original").tag(0)
                        Text(state.outputFolder.map { "Dossier « \($0.lastPathComponent) »" } ?? "Dans un dossier…").tag(1)
                    }
                    .labelsHidden()
                    if state.outputFolder != nil {
                        Button("Changer…") { state.chooseOutputFolder() }.controlSize(.small)
                    }
                }
                Text("Les originaux ne sont jamais écrasés : « photo-\(state.effectivePreset.suffix ?? "2").\(state.effectivePreset.format.fileExtension) ».")
                    .font(Theme.ui(11.5)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            footer
        }
        .padding(20)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title)
            content()
        }
    }

    @ViewBuilder
    private var footer: some View {
        let s = state.summary
        VStack(alignment: .leading, spacing: 10) {
            if !state.items.isEmpty, s.before > 0 {
                let pct = Int(((1 - Double(s.after) / Double(s.before)) * 100).rounded())
                Text("\(state.items.count) image\(state.items.count > 1 ? "s" : "") · \(s.before.fileSizeLabel) → \(s.estimated ? "environ " : "")\(s.after.fileSizeLabel) (\(pct >= 0 ? "−" : "+")\(abs(pct)) %)")
                    .font(Theme.ui(12.5, weight: .semibold)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if state.isProcessing {
                ProgressView(value: Double(state.completed), total: Double(max(1, state.total))) {
                    Text("\(state.completed) / \(state.total)").font(Theme.ui(11.5)).foregroundStyle(Theme.inkSoft)
                }
                .tint(Theme.accent)
            } else if state.pendingCount > 0 {
                Button {
                    state.processAll()
                } label: {
                    Text("Alléger \(state.pendingCount) image\(state.pendingCount > 1 ? "s" : "")")
                        .font(Theme.ui(14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if !state.doneResults.isEmpty {
                HStack(spacing: 8) {
                    Button("Afficher dans le Finder") { state.revealResults() }.controlSize(.large)
                    Button("Recommencer") { state.resetDone() }.controlSize(.large)
                }
                Text("Glissez une ligne vers le Finder, un mail ou un message pour emporter le fichier allégé.")
                    .font(Theme.ui(11.5)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Déposez des images à gauche.").font(Theme.ui(12)).foregroundStyle(Theme.inkFaint)
            }
        }
    }
}

struct PresetCard: View {
    let preset: ExportPreset
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: preset.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(selected ? Color.white : Theme.accent)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(Theme.accentSelection)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name).font(Theme.ui(12.5, weight: .bold)).foregroundStyle(Theme.ink)
                    if selected {
                        Text(preset.detail).font(Theme.ui(11)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                    Text(preset.summary).font(Theme.ui(10.5, weight: .semibold)).foregroundStyle(selected ? Theme.accent : Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Theme.card : (hovering ? Theme.card.opacity(0.7) : .clear)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? Theme.accent.opacity(0.6) : Theme.line.opacity(hovering ? 1 : 0), lineWidth: 1.2))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}

/// Bouton principal aux teintes de l'affiche, comme sur le site : fond `deep` et texte blanc
/// en clair, fond `background` et texte `deep` en sombre.
private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 5)
            .foregroundStyle(Theme.accentPrimaryButtonForeground)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(Theme.accentPrimaryButtonBackground))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.5)
    }
}
