import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Formats de sortie : ceux qu'ImageIO sait ecrire, sans bibliotheque embarquee
/// (pas de WebP en sortie sur macOS 26, seulement en entree).
public enum OutputFormat: String, CaseIterable, Sendable, Identifiable {
    case jpeg, png, heic, avif

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .heic: "HEIC"
        case .avif: "AVIF"
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .heic: "heic"
        case .avif: "avif"
        }
    }

    public var utType: UTType {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        case .heic: .heic
        case .avif: UTType("public.avif") ?? .heic
        }
    }

    /// PNG est sans perte : pas de curseur de qualite.
    public var supportsQuality: Bool { self != .png }

    /// Une phrase pour choisir.
    public var hint: String {
        switch self {
        case .jpeg: "Lu partout, le plus sûr pour partager."
        case .png: "Sans perte, pour les captures et les logos."
        case .heic: "Deux fois plus léger que JPEG, lu par Apple et Windows 11."
        case .avif: "Le plus compact, lu par les navigateurs récents."
        }
    }

    /// Formats que ce Mac sait ecrire.
    public static var writable: [OutputFormat] {
        let ids = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        return allCases.filter { ids.contains($0.utType.identifier) }
    }
}
