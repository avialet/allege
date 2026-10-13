import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AllegeCore

// MARK: Outils : images de test fabriquees en memoire.

private func makeImage(width: Int, height: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.setFillColor(CGColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
    return ctx.makeImage()!
}

private func tempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("allege-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@discardableResult
private func write(_ image: CGImage, to url: URL, type: UTType, properties: [CFString: Any] = [:]) throws -> URL {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw TestFailure(description: "ecriture impossible : \(url.lastPathComponent)") }
    return url
}

private func properties(of url: URL) -> [CFString: Any] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return [:] }
    return props
}

private func pixelSize(of url: URL) -> (Int, Int) {
    let p = properties(of: url)
    return (p[kCGImagePropertyPixelWidth] as? Int ?? 0, p[kCGImagePropertyPixelHeight] as? Int ?? 0)
}

private func exifSample() -> [CFString: Any] { [
    kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "secret", kCGImagePropertyExifLensModel: "Objectif test"],
    kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 48.85, kCGImagePropertyGPSLongitude: 2.35],
] }

// MARK: Tests

let imageTests: (String, [Test]) = ("Image", [
    Test("collectKeepsImagesAndRecursesFolders") {
        let dir = try tempDir()
        try write(makeImage(width: 10, height: 10), to: dir.appendingPathComponent("a.png"), type: .png)
        try "texte".write(to: dir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let sub = dir.appendingPathComponent("sous")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try write(makeImage(width: 10, height: 10), to: sub.appendingPathComponent("c.jpg"), type: .jpeg)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("d.jpg"), withIntermediateDirectories: true)
        let found = ImageFiles.collect(from: [dir]).map(\.lastPathComponent)
        expectEqual(found, ["a.png", "c.jpg"])
        expectEqual(ImageFiles.collect(from: [sub.appendingPathComponent("c.jpg"), dir.appendingPathComponent("b.txt")]).count, 1)
    },
    Test("uniqueDestinationNeverOverwrites") {
        let dir = try tempDir()
        let source = dir.appendingPathComponent("photo.png")
        try write(makeImage(width: 4, height: 4), to: source, type: .png)
        let first = ImageProcessor.uniqueDestination(for: source, format: .jpeg, suffix: "mail", in: nil)
        expectEqual(first.lastPathComponent, "photo-mail.jpg")
        try "x".write(to: first, atomically: true, encoding: .utf8)
        let second = ImageProcessor.uniqueDestination(for: source, format: .jpeg, suffix: "mail", in: nil)
        expectEqual(second.lastPathComponent, "photo-mail-2.jpg")
        // Meme format, sans suffixe : ne jamais retomber sur la source.
        let same = ImageProcessor.uniqueDestination(for: source, format: .png, suffix: nil, in: nil)
        expectEqual(same.lastPathComponent, "photo-2.png")
        let elsewhere = ImageProcessor.uniqueDestination(for: source, format: .png, suffix: nil, in: dir.appendingPathComponent("sortie"))
        expectEqual(elsewhere.lastPathComponent, "photo.png")
        expectEqual(elsewhere.deletingLastPathComponent().lastPathComponent, "sortie")
    },
    Test("resizeKeepsAspectRatioWithinMaxDimension") {
        let dir = try tempDir()
        let source = try write(makeImage(width: 800, height: 400), to: dir.appendingPathComponent("large.png"), type: .png)
        var preset = ExportPreset.web
        preset.maxDimension = 400
        let result = try ImageProcessor.process(source, preset: preset)
        expectEqual(result.outputWidth, 400)
        expectEqual(result.outputHeight, 200)
        let (w, h) = pixelSize(of: result.output)
        expectEqual(w, 400); expectEqual(h, 200)
        expectEqual(result.inputWidth, 800)
        expect(result.outputBytes > 0 && result.inputBytes > 0)
    },
    Test("smallImagesAreNeverUpscaled") {
        let dir = try tempDir()
        let source = try write(makeImage(width: 300, height: 200), to: dir.appendingPathComponent("petite.png"), type: .png)
        let result = try ImageProcessor.process(source, preset: .mail)
        expectEqual((result.outputWidth, result.outputHeight) == (300, 200), true)
    },
    Test("strippedOutputHasNoExifNorGPS") {
        let dir = try tempDir()
        let source = try write(makeImage(width: 64, height: 64), to: dir.appendingPathComponent("exif.jpg"), type: .jpeg, properties: exifSample())
        expect(properties(of: source)[kCGImagePropertyGPSDictionary] != nil, "la source doit porter du GPS")
        let result = try ImageProcessor.process(source, preset: .mail)
        let props = properties(of: result.output)
        expect(props[kCGImagePropertyGPSDictionary] == nil, "GPS present")
        // ImageIO ecrit toujours les dimensions en pixels dans l'Exif d'un JPEG : rien d'autre ne doit y rester.
        let exifKeys = Set(((props[kCGImagePropertyExifDictionary] as? [CFString: Any]) ?? [:]).keys.map { $0 as String })
        let harmless: Set<String> = [kCGImagePropertyExifPixelXDimension as String, kCGImagePropertyExifPixelYDimension as String,
                                     kCGImagePropertyExifColorSpace as String]
        expect(exifKeys.isSubset(of: harmless), "Exif conserve : \(exifKeys.subtracting(harmless))")
        let tiff = (props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
        for key in [kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel, kCGImagePropertyTIFFSoftware, kCGImagePropertyTIFFDateTime] {
            expect(tiff[key] == nil, "TIFF conserve \(key)")
        }
    },
    Test("keptMetadataSurvivesConversion") {
        let dir = try tempDir()
        let source = try write(makeImage(width: 64, height: 64), to: dir.appendingPathComponent("exif.jpg"), type: .jpeg, properties: exifSample())
        var preset = ExportPreset.convert
        preset.format = .jpeg
        preset.stripMetadata = false
        let result = try ImageProcessor.process(source, preset: preset)
        let exif = properties(of: result.output)[kCGImagePropertyExifDictionary] as? [CFString: Any]
        expectEqual(exif?[kCGImagePropertyExifLensModel] as? String, "Objectif test")
    },
    Test("orientationIsBakedIntoPixels") {
        let dir = try tempDir()
        // 800x400 stockes, orientation 6 (tourne de 90 degres) : s'affiche en 400x800.
        let source = try write(makeImage(width: 800, height: 400), to: dir.appendingPathComponent("tourne.jpg"), type: .jpeg,
                               properties: [kCGImagePropertyOrientation: 6])
        var preset = ExportPreset.convert
        preset.format = .jpeg
        preset.stripMetadata = false
        let result = try ImageProcessor.process(source, preset: preset)
        let (w, h) = pixelSize(of: result.output)
        expectEqual(w, 400); expectEqual(h, 800)
        let orientation = properties(of: result.output)[kCGImagePropertyOrientation] as? Int ?? 1
        expectEqual(orientation, 1)
    },
    Test("everyFormatWritesAndReadsBack") {
        let dir = try tempDir()
        let source = try write(makeImage(width: 120, height: 80), to: dir.appendingPathComponent("src.png"), type: .png)
        for format in OutputFormat.allCases {
            var preset = ExportPreset.convert
            preset.format = format
            let result = try ImageProcessor.process(source, preset: preset)
            expectEqual(result.output.pathExtension, format.fileExtension, format.label)
            let (w, h) = pixelSize(of: result.output)
            expectEqual(w, 120, format.label); expectEqual(h, 80, format.label)
        }
        expectEqual(OutputFormat.writable, OutputFormat.allCases)
    },
    Test("infoReadsDimensionsAndBytes") {
        let dir = try tempDir()
        let source = try write(makeImage(width: 33, height: 21), to: dir.appendingPathComponent("i.png"), type: .png)
        let info = try ImageProcessor.info(of: source)
        expectEqual(info.width, 33); expectEqual(info.height, 21)
        expect(info.bytes > 0)
        expectThrows { _ = try ImageProcessor.info(of: dir.appendingPathComponent("absent.png")) }
    },
    Test("presetsReadAsSentences") {
        expectEqual(ExportPreset.all.map(\.id), ["mail", "web", "impression", "convertir"])
        for p in ExportPreset.all {
            expect(!p.summary.isEmpty && !p.name.isEmpty, p.id)
        }
        expectEqual(ExportPreset.mail.summary, "1600 px de côté au plus · JPEG 80 % · sans métadonnées")
        expectEqual(ExportPreset.convert.maxDimension, nil)
        expect(ExportPreset.convert.suffix == nil && ExportPreset.mail.suffix == "mail")
    },
    Test("estimateFollowsQualityAndFormat") {
        let jpeg80 = ImageProcessor.estimateBytes(width: 1600, height: 1200, format: .jpeg, quality: 0.8)
        let jpeg50 = ImageProcessor.estimateBytes(width: 1600, height: 1200, format: .jpeg, quality: 0.5)
        let heic80 = ImageProcessor.estimateBytes(width: 1600, height: 1200, format: .heic, quality: 0.8)
        expect(jpeg50 < jpeg80, "qualite plus basse, fichier plus petit")
        expect(heic80 < jpeg80, "HEIC plus compact que JPEG")
        expect(jpeg80 > 200_000 && jpeg80 < 1_500_000, "ordre de grandeur plausible : \(jpeg80)")
        expectEqual(ImageProcessor.estimateBytes(width: 0, height: 0, format: .png, quality: 1), 0)
    },
])
