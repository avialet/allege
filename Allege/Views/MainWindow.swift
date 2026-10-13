import SwiftUI
import VialetKit
import AllegeCore

struct MainWindow: View {
    @Environment(AppState.self) private var state
    @State private var targeted = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                UpdateNotice(updater: .shared)
                queue
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AmbientBackground())
            PresetPanel()
                .frame(width: 340)
                .background(Theme.sidebar)
        }
        .dropDestination(for: URL.self) { urls, _ in
            state.add(urls)
            return true
        } isTargeted: { targeted = $0 }
    }

    private var queue: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Wordmark(Brand.displayName)
                Spacer()
                if !state.items.isEmpty {
                    Button("Ajouter…") { state.chooseFiles() }.controlSize(.small)
                    Button("Vider") { state.clear() }.controlSize(.small).disabled(state.isProcessing)
                }
            }
            if state.items.isEmpty {
                DropZone(targeted: targeted)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(state.items) { item in
                            ItemRow(item: item)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .overlay {
                    if targeted {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accent.opacity(0.06)))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 20)
    }
}

/// Grande zone de depot, quand la liste est vide.
struct DropZone: View {
    @Environment(AppState.self) private var state
    let targeted: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(targeted ? Theme.accent : Theme.inkFaint)
                .symbolEffect(.bounce, value: targeted)
            Text("Déposez des images ou des dossiers")
                .font(Theme.ui(17, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Rien ne quitte votre Mac. Les originaux ne sont jamais modifiés.")
                .font(Theme.ui(12.5)).foregroundStyle(Theme.inkSoft)
            Button("Choisir des images…") { state.chooseFiles() }
                .controlSize(.large)
                .padding(.top, 6)
            Text("JPEG, PNG, HEIC, TIFF, WebP, AVIF, RAW…")
                .font(Theme.ui(11)).foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(targeted ? Theme.accent.opacity(0.08) : Theme.card.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(targeted ? Theme.accent : Theme.line, style: StrokeStyle(lineWidth: targeted ? 2 : 1.2, dash: [9, 7]))
        )
        .animation(.easeOut(duration: 0.15), value: targeted)
    }
}

/// Une image de la file : vignette, nom, avant / apres, etat.
struct ItemRow: View {
    @Environment(AppState.self) private var state
    let item: ImageItem

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(Theme.ui(13, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(detail).font(Theme.ui(11.5)).foregroundStyle(Theme.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 8)
            status
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .contextMenu {
            if let result = item.result {
                Button("Afficher le résultat dans le Finder") { NSWorkspace.shared.activateFileViewerSelecting([result.output]) }
            }
            Button("Afficher l'original dans le Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Divider()
            Button("Retirer de la liste") { state.remove(item.id) }.disabled(state.isProcessing)
        }
        .modifier(DragOut(url: item.result?.output))
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.ink.opacity(0.06))
            if let cg = item.thumbnail {
                Image(decorative: cg, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "photo").foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(width: 46, height: 46)
    }

    private var detail: String {
        guard let info = item.info else { return "Lecture…" }
        let before = "\(info.width) × \(info.height) · \(info.bytes.fileSizeLabel)"
        if let r = item.result {
            return "\(before)  →  \(r.outputWidth) × \(r.outputHeight) · \(r.outputBytes.fileSizeLabel) · \(r.output.lastPathComponent)"
        }
        let p = state.effectivePreset
        let planned = ImageProcessor.plannedSize(width: info.width, height: info.height, maxDimension: p.maxDimension)
        let estimate = ImageProcessor.estimateBytes(width: planned.width, height: planned.height, format: p.format, quality: p.quality)
        return "\(before)  →  \(planned.width) × \(planned.height) · environ \(estimate.fileSizeLabel)"
    }

    @ViewBuilder
    private var status: some View {
        switch item.state {
        case .pending:
            EmptyView()
        case .processing:
            ProgressView().controlSize(.small)
        case .done(let r):
            let pct = Int((r.savings * 100).rounded())
            Chip(pct >= 0 ? "−\(pct) %" : "+\(-pct) %", icon: "checkmark", color: pct > 0 ? Theme.pine : Theme.stone, filled: true)
        case .failed(let message):
            Chip(message, icon: "exclamationmark.triangle", color: Theme.danger)
        }
    }
}

/// Rend une ligne glissable vers le Finder une fois le resultat ecrit.
private struct DragOut: ViewModifier {
    let url: URL?
    func body(content: Content) -> some View {
        if let url { content.draggable(url) } else { content }
    }
}
