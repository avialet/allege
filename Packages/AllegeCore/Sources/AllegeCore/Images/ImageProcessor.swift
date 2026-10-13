import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ImageInfo: Sendable, Equatable {
    /// Dimensions telles qu'affichees (orientation EXIF appliquee).
    public let width: Int
    public let height: Int
    public let bytes: Int
    public let typeIdentifier: String?
}

public struct ProcessResult: Sendable, Equatable {
    public let source: URL
    public let output: URL
    public let inputBytes: Int
    public let outputBytes: Int
    public let inputWidth: Int
    public let inputHeight: Int
    public let outputWidth: Int
    public let outputHeight: Int

    /// Part du poids gagnee, entre -inf et 1.
    public var savings: Double { inputBytes > 0 ? 1 - Double(outputBytes) / Double(inputBytes) : 0 }
}

public struct ProcessingError: LocalizedError, Sendable {
    public let message: String
    init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// Lecture, redimensionnement, conversion et ecriture via ImageIO. Tout se
/// passe sur le Mac ; la source n'est jamais modifiee ni ecrasee.
public enum ImageProcessor {
    public static func info(of url: URL) throws -> ImageInfo {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            throw ProcessingError("Image illisible : \(url.lastPathComponent)")
        }
        let orientation = props[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let rotated = (5...8).contains(orientation)
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ImageInfo(width: rotated ? height : width, height: rotated ? width : height, bytes: bytes,
                         typeIdentifier: CGImageSourceGetType(source) as String?)
    }

    /// `photo-mail.jpg` a cote de la source (ou dans `directory`), jamais un
    /// fichier existant, jamais la source elle-meme : `-2`, `-3`... au besoin.
    public static func uniqueDestination(for source: URL, format: OutputFormat, suffix: String?, in directory: URL?) -> URL {
        let folder = directory ?? source.deletingLastPathComponent()
        let base = source.deletingPathExtension().lastPathComponent
        let stem = suffix.map { "\(base)-\($0)" } ?? base
        let sourcePath = source.standardizedFileURL.path
        var candidate = folder.appendingPathComponent(stem).appendingPathExtension(format.fileExtension)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) || candidate.standardizedFileURL.path == sourcePath {
            candidate = folder.appendingPathComponent("\(stem)-\(n)").appendingPathExtension(format.fileExtension)
            n += 1
        }
        return candidate
    }

    public static func process(_ source: URL, preset: ExportPreset, into directory: URL? = nil) throws -> ProcessResult {
        let input = try info(of: source)
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ProcessingError("Image illisible : \(source.lastPathComponent)")
        }
        let longest = max(input.width, input.height)
        let target = min(longest, preset.maxDimension ?? longest)
        // Le "thumbnail" d'ImageIO decode, applique l'orientation EXIF et reduit en une passe.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: target,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ProcessingError("Décodage impossible : \(source.lastPathComponent)")
        }

        let output = uniqueDestination(for: source, format: preset.format, suffix: preset.suffix, in: directory)
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, preset.format.utType.identifier as CFString, 1, nil) else {
            throw ProcessingError("Format d'écriture indisponible : \(preset.format.label)")
        }

        var props: [CFString: Any] = [:]
        if preset.format.supportsQuality { props[kCGImageDestinationLossyCompressionQuality] = preset.quality }
        if !preset.stripMetadata, var kept = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
            // L'orientation est desormais dans les pixels ; les dimensions ont pu changer.
            kept[kCGImagePropertyOrientation] = 1
            kept[kCGImagePropertyPixelWidth] = image.width
            kept[kCGImagePropertyPixelHeight] = image.height
            if var tiff = kept[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                tiff[kCGImagePropertyTIFFOrientation] = 1
                kept[kCGImagePropertyTIFFDictionary] = tiff
            }
            if var exif = kept[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                exif[kCGImagePropertyExifPixelXDimension] = image.width
                exif[kCGImagePropertyExifPixelYDimension] = image.height
                kept[kCGImagePropertyExifDictionary] = exif
            }
            props.merge(kept) { current, _ in current }
        }
        CGImageDestinationAddImage(destination, image, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: output)
            throw ProcessingError("Écriture impossible : \(output.lastPathComponent)")
        }
        let outputBytes = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ProcessResult(source: source, output: output, inputBytes: input.bytes, outputBytes: outputBytes,
                             inputWidth: input.width, inputHeight: input.height,
                             outputWidth: image.width, outputHeight: image.height)
    }

    /// Ordre de grandeur du poids de sortie, avant traitement (octets par pixel
    /// typiques d'une photo). Affiche avec un « environ ».
    public static func estimateBytes(width: Int, height: Int, format: OutputFormat, quality: Double) -> Int {
        let pixels = Double(max(0, width)) * Double(max(0, height))
        guard pixels > 0 else { return 0 }
        let q = min(max(quality, 0), 1)
        let jpeg = 0.03 + 0.28 * q * q * q
        let bytesPerPixel: Double = switch format {
        case .jpeg: jpeg
        case .heic: jpeg * 0.55
        case .avif: jpeg * 0.45
        case .png: 2.2
        }
        return Int(pixels * bytesPerPixel)
    }

    /// Taille de sortie prevue pour une image (cote max applique, sans agrandir).
    public static func plannedSize(width: Int, height: Int, maxDimension: Int?) -> (width: Int, height: Int) {
        let longest = max(width, height)
        guard let maxDimension, longest > maxDimension, longest > 0 else { return (width, height) }
        let scale = Double(maxDimension) / Double(longest)
        return (Int((Double(width) * scale).rounded()), Int((Double(height) * scale).rounded()))
    }
}
