import Foundation
import UniformTypeIdentifiers

/// Trouve les images parmi des fichiers et des dossiers deposes.
public enum ImageFiles {
    public static func isImage(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
        guard values?.isRegularFile == true else { return false }
        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        return type?.conforms(to: .image) == true
    }

    /// Images parmi `urls` ; les dossiers sont parcourus (fichiers caches et
    /// paquets ignores). Ordre : celui du depot, puis alphabetique dans un dossier.
    public static func collect(from urls: [URL]) -> [URL] {
        var out: [URL] = []
        var seen = Set<String>()
        let fm = FileManager.default
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                guard let walker = fm.enumerator(at: url, includingPropertiesForKeys: [.contentTypeKey, .isRegularFileKey],
                                                 options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
                var inside: [URL] = []
                for case let file as URL in walker where isImage(file) { inside.append(file) }
                inside.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                for file in inside where seen.insert(file.path).inserted { out.append(file) }
            } else if isImage(url), seen.insert(url.path).inserted {
                out.append(url)
            }
        }
        return out
    }
}
