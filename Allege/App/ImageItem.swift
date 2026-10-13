import AppKit
import AllegeCore

/// Une image deposee, de son arrivee a son resultat.
struct ImageItem: Identifiable {
    enum State: Equatable {
        case pending
        case processing
        case done(ProcessResult)
        case failed(String)
    }

    let id = UUID()
    let url: URL
    var info: ImageInfo?
    var thumbnail: CGImage?
    var state: State = .pending

    var name: String { url.lastPathComponent }
    var result: ProcessResult? {
        if case .done(let r) = state { return r }
        return nil
    }
    var isPending: Bool { state == .pending }
}

extension Int {
    /// « 2,4 Mo », « 410 ko ».
    var fileSizeLabel: String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f.string(fromByteCount: Int64(self))
    }
}
