import Foundation

/// Un prereglage par intention : la phrase qui le resume est calculee,
/// pour que l'interface dise toujours exactement ce qui va se passer.
public struct ExportPreset: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    /// Une phrase sur l'intention.
    public var detail: String
    /// Symbole SF.
    public var icon: String
    public var format: OutputFormat
    /// Cote le plus long, en pixels. nil : taille d'origine. Jamais d'agrandissement.
    public var maxDimension: Int?
    /// 0...1, ignore pour PNG.
    public var quality: Double
    public var stripMetadata: Bool
    /// Ajoute au nom du fichier (`photo-mail.jpg`). nil : nom d'origine.
    public var suffix: String?

    public init(id: String, name: String, detail: String, icon: String, format: OutputFormat,
                maxDimension: Int?, quality: Double, stripMetadata: Bool, suffix: String?) {
        self.id = id; self.name = name; self.detail = detail; self.icon = icon; self.format = format
        self.maxDimension = maxDimension; self.quality = quality; self.stripMetadata = stripMetadata; self.suffix = suffix
    }

    /// « 1600 px de côté au plus · JPEG 80 % · sans métadonnées »
    public var summary: String {
        var parts: [String] = []
        parts.append(maxDimension.map { "\($0) px de côté au plus" } ?? "taille d'origine")
        parts.append(format.supportsQuality ? "\(format.label) \(Int((quality * 100).rounded())) %" : format.label)
        parts.append(stripMetadata ? "sans métadonnées" : "métadonnées conservées")
        return parts.joined(separator: " · ")
    }

    public static let mail = ExportPreset(
        id: "mail", name: "Pour un mail",
        detail: "Assez net pour être lu, assez léger pour partir tout de suite.",
        icon: "envelope", format: .jpeg, maxDimension: 1600, quality: 0.8, stripMetadata: true, suffix: "mail")

    public static let web = ExportPreset(
        id: "web", name: "Pour le web",
        detail: "Net sur un écran Retina, rapide à charger, sans position GPS.",
        icon: "globe", format: .jpeg, maxDimension: 2048, quality: 0.78, stripMetadata: true, suffix: "web")

    public static let print = ExportPreset(
        id: "impression", name: "Pour impression",
        detail: "Pleine définition, compression douce, sans métadonnées.",
        icon: "printer", format: .jpeg, maxDimension: nil, quality: 0.92, stripMetadata: true, suffix: "impression")

    public static let convert = ExportPreset(
        id: "convertir", name: "Juste convertir",
        detail: "Change le format, ne touche ni à la taille ni aux métadonnées.",
        icon: "arrow.triangle.2.circlepath", format: .jpeg, maxDimension: nil, quality: 0.9, stripMetadata: false, suffix: nil)

    public static let all: [ExportPreset] = [mail, web, print, convert]
}
