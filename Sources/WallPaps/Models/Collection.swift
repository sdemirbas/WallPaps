import Foundation

/// A curated, themed set of artists (optionally pinned to an orientation).
/// When active, it overrides the manual artist selection in `ArtLibrary.replenish`.
/// Carries explicit TR/EN names so remote (manifest-driven) collections work the
/// same way as bundled ones.
struct ArtCollection: Identifiable, Hashable, Sendable {
    let id: String
    let nameTR: String
    let nameEN: String
    let artists: [String]
    let orientation: Orientation?

    var localizedName: String { Localization.resolved() == .tr ? nameTR : nameEN }

    /// Bundled fallback used offline / on first run (before the remote catalog loads).
    static let all: [ArtCollection] = [
        ArtCollection(id: "impressionism", nameTR: "İzlenimcilik", nameEN: "Impressionism",
                      artists: ["Claude Monet", "Pierre-Auguste Renoir", "Camille Pissarro",
                                "Alfred Sisley", "Edgar Degas"], orientation: nil),
        ArtCollection(id: "postimpressionism", nameTR: "Post-Empresyonizm", nameEN: "Post-Impressionism",
                      artists: ["Vincent van Gogh", "Paul Cézanne", "Georges Seurat",
                                "Paul Gauguin", "Henri de Toulouse-Lautrec"], orientation: nil),
        ArtCollection(id: "japanese", nameTR: "Japon Baskıları", nameEN: "Japanese Prints",
                      artists: ["Katsushika Hokusai", "Utagawa Hiroshige", "Kitagawa Utamaro"],
                      orientation: nil),
        ArtCollection(id: "dutch", nameTR: "Hollanda Ustaları", nameEN: "Dutch Masters",
                      artists: ["Rembrandt van Rijn", "Johannes Vermeer", "Frans Hals", "Jan Steen"],
                      orientation: nil),
        ArtCollection(id: "baroque", nameTR: "Barok", nameEN: "Baroque",
                      artists: ["Caravaggio", "Rembrandt van Rijn", "Diego Velázquez",
                                "Peter Paul Rubens"], orientation: nil),
        ArtCollection(id: "portraits", nameTR: "Portreler", nameEN: "Portraits",
                      artists: ["Vincent van Gogh", "Rembrandt van Rijn", "John Singer Sargent",
                                "Édouard Manet"], orientation: .portrait),
        ArtCollection(id: "landscapes", nameTR: "Manzaralar", nameEN: "Landscapes",
                      artists: ["Claude Monet", "Vincent van Gogh", "Camille Pissarro",
                                "J. M. W. Turner"], orientation: .landscape),
    ]
}
