import Foundation

/// A curated public-domain artist, used as a search seed against the museum APIs.
struct Artist: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    /// Canonical name used for searching the APIs.
    let name: String
    /// Name shown in the UI.
    let displayName: String

    init(_ name: String, displayName: String? = nil) {
        self.name = name
        self.displayName = displayName ?? name
    }

    /// Well-represented public-domain masters available as CC0 in AIC / The Met.
    static let defaults: [Artist] = [
        Artist("Vincent van Gogh"),
        Artist("Claude Monet"),
        Artist("Pierre-Auguste Renoir", displayName: "Renoir"),
        Artist("Paul Cézanne", displayName: "Cézanne"),
        Artist("Edgar Degas"),
        Artist("Johannes Vermeer", displayName: "Vermeer"),
        Artist("Rembrandt van Rijn", displayName: "Rembrandt"),
        Artist("Katsushika Hokusai", displayName: "Hokusai"),
        Artist("Gustav Klimt"),
        Artist("Georges Seurat"),
        Artist("Henri de Toulouse-Lautrec", displayName: "Toulouse-Lautrec"),
        Artist("Eugène Delacroix", displayName: "Delacroix"),
        Artist("Camille Pissarro", displayName: "Pissarro"),
        Artist("Paul Gauguin", displayName: "Gauguin"),
        Artist("Édouard Manet", displayName: "Manet"),
        Artist("John Singer Sargent", displayName: "Sargent"),
        Artist("J. M. W. Turner", displayName: "Turner"),
        Artist("Utagawa Hiroshige", displayName: "Hiroshige"),
        Artist("Mary Cassatt"),
        Artist("Francisco Goya", displayName: "Goya"),
        Artist("Caravaggio"),
        Artist("Diego Velázquez", displayName: "Velázquez"),
        Artist("Peter Paul Rubens", displayName: "Rubens"),
        Artist("Titian"),
        Artist("Albrecht Dürer", displayName: "Dürer"),
        Artist("Sandro Botticelli", displayName: "Botticelli"),
        Artist("Winslow Homer"),
        Artist("James McNeill Whistler", displayName: "Whistler"),
        Artist("Camille Corot", displayName: "Corot"),
        Artist("Jean-François Millet", displayName: "Millet"),
        Artist("Gustave Courbet", displayName: "Courbet"),
        Artist("Berthe Morisot"),
        Artist("Caspar David Friedrich", displayName: "Friedrich"),
        Artist("Raphael"),
        Artist("Tintoretto"),
        Artist("El Greco"),
        Artist("Hieronymus Bosch", displayName: "Bosch"),
        Artist("Pieter Bruegel the Elder", displayName: "Bruegel"),
        Artist("Jan van Eyck", displayName: "van Eyck"),
        Artist("Hans Holbein the Younger", displayName: "Holbein"),
        Artist("Anthony van Dyck", displayName: "van Dyck"),
        Artist("Bartolomé Esteban Murillo", displayName: "Murillo"),
        Artist("Frans Hals"),
        Artist("Nicolas Poussin", displayName: "Poussin"),
        Artist("Jacques-Louis David", displayName: "J.-L. David"),
        Artist("Théodore Géricault", displayName: "Géricault"),
        Artist("John Constable", displayName: "Constable"),
        Artist("Thomas Gainsborough", displayName: "Gainsborough"),
        Artist("Alfred Sisley", displayName: "Sisley"),
        Artist("Henri Rousseau", displayName: "Rousseau"),
        Artist("Kitagawa Utamaro", displayName: "Utamaro"),
        Artist("Pierre Bonnard", displayName: "Bonnard"),
        Artist("Édouard Vuillard", displayName: "Vuillard"),
    ]
}
