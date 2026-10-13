import AppKit
import Observation
import ImageIO
import AllegeCore

/// Etat de la fenetre : la file d'images, le prereglage, le dossier de sortie.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    private(set) var items: [ImageItem] = []
    var preset: ExportPreset {
        didSet { UserDefaults.standard.set(preset.id, forKey: Brand.key("Preset")) }
    }
    /// Format choisi par-dessus le prereglage (nil : celui du prereglage).
    var formatOverride: OutputFormat? {
        didSet { UserDefaults.standard.set(formatOverride?.rawValue, forKey: Brand.key("Format")) }
    }
    /// nil : a cote de l'original.
    var outputFolder: URL? {
        didSet { UserDefaults.standard.set(outputFolder?.path, forKey: Brand.key("OutputFolder")) }
    }
    private(set) var isProcessing = false
    private(set) var completed = 0
    private(set) var total = 0

    private init() {
        let savedPreset = UserDefaults.standard.string(forKey: Brand.key("Preset"))
        preset = ExportPreset.all.first { $0.id == savedPreset } ?? .mail
        formatOverride = UserDefaults.standard.string(forKey: Brand.key("Format")).flatMap(OutputFormat.init(rawValue:))
        if let path = UserDefaults.standard.string(forKey: Brand.key("OutputFolder")), FileManager.default.fileExists(atPath: path) {
            outputFolder = URL(fileURLWithPath: path)
        }
    }

    /// Le prereglage reellement applique.
    var effectivePreset: ExportPreset {
        var p = preset
        if let formatOverride { p.format = formatOverride }
        return p
    }

    var pendingCount: Int { items.filter(\.isPending).count }
    var doneResults: [ProcessResult] { items.compactMap(\.result) }

    /// Poids total avant / estime ou mesure apres.
    var summary: (before: Int, after: Int, estimated: Bool) {
        var before = 0, after = 0, estimated = false
        let p = effectivePreset
        for item in items {
            guard let info = item.info else { continue }
            before += info.bytes
            if let r = item.result {
                after += r.outputBytes
            } else {
                let planned = ImageProcessor.plannedSize(width: info.width, height: info.height, maxDimension: p.maxDimension)
                after += ImageProcessor.estimateBytes(width: planned.width, height: planned.height, format: p.format, quality: p.quality)
                estimated = true
            }
        }
        return (before, after, estimated)
    }

    // MARK: File d'attente

    func add(_ urls: [URL]) {
        let known = Set(items.map(\.url.standardizedFileURL.path))
        let fresh = ImageFiles.collect(from: urls).filter { !known.contains($0.standardizedFileURL.path) }
        guard !fresh.isEmpty else { return }
        let newItems = fresh.map { ImageItem(url: $0) }
        items.append(contentsOf: newItems)
        for item in newItems {
            Task.detached(priority: .userInitiated) { [id = item.id, url = item.url] in
                let info = try? ImageProcessor.info(of: url)
                let thumb = Self.thumbnail(of: url)
                await MainActor.run { AppState.shared.attach(info: info, thumbnail: thumb, to: id) }
            }
        }
    }

    private func attach(info: ImageInfo?, thumbnail: CGImage?, to id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].info = info
        items[index].thumbnail = thumbnail
        if info == nil { items[index].state = .failed("Image illisible") }
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    func clear() {
        guard !isProcessing else { return }
        items.removeAll()
    }

    /// Repart de zero sur les images deja traitees (pour un autre prereglage).
    func resetDone() {
        for index in items.indices where items[index].result != nil { items[index].state = .pending }
    }

    nonisolated private static func thumbnail(of url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 128,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: Traitement

    func processAll() {
        guard !isProcessing else { return }
        let jobs = items.filter(\.isPending).map { ($0.id, $0.url) }
        guard !jobs.isEmpty else { return }
        isProcessing = true
        completed = 0
        total = jobs.count
        let preset = effectivePreset
        let folder = outputFolder
        for (id, _) in jobs { mark(id, .processing) }

        Task {
            let width = max(2, min(4, ProcessInfo.processInfo.activeProcessorCount / 2))
            var next = 0
            await withTaskGroup(of: (UUID, Result<ProcessResult, Error>).self) { group in
                func launch() {
                    guard next < jobs.count else { return }
                    let (id, url) = jobs[next]
                    next += 1
                    group.addTask {
                        (id, Result { try ImageProcessor.process(url, preset: preset, into: folder) })
                    }
                }
                for _ in 0..<min(width, jobs.count) { launch() }
                while let (id, result) = await group.next() {
                    switch result {
                    case .success(let r): mark(id, .done(r))
                    case .failure(let e): mark(id, .failed(e.localizedDescription))
                    }
                    completed += 1
                    launch()
                }
            }
            isProcessing = false
        }
    }

    private func mark(_ id: UUID, _ state: ImageItem.State) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = state
    }

    // MARK: Finder

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .folder]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.message = "Choisissez des images ou des dossiers d'images."
        panel.prompt = "Ajouter"
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Les images allégées seront écrites dans ce dossier."
        panel.prompt = "Choisir"
        if panel.runModal() == .OK { outputFolder = panel.url }
    }

    func revealResults() {
        let urls = doneResults.map(\.output)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}
