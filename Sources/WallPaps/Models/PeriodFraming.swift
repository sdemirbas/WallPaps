import Foundation

/// Maps an artist to a period-appropriate frame, so each piece feels "properly
/// hung": Renaissance/Baroque → gilded gold, Romantic/Realist → vintage wood,
/// Modern/Japanese → minimal, Impressionist → classic. Unknown → nil (keep the
/// user's theme).
enum PeriodFraming {
    static func theme(for artist: String) -> FrameTheme? {
        let a = artist.lowercased()
        for (theme, names) in map where names.contains(where: { a.contains($0) }) {
            return theme
        }
        return nil
    }

    private static let map: [(FrameTheme, [String])] = [
        (.gold, ["caravaggio", "rembrandt", "rubens", "velázquez", "velazquez", "vermeer",
                 "hals", "van dyck", "murillo", "poussin", "el greco", "tintoretto", "titian",
                 "raphael", "botticelli", "dürer", "durer", "bosch", "bruegel", "van eyck",
                 "holbein", "gentileschi"]),
        (.vintage, ["goya", "delacroix", "turner", "constable", "géricault", "gericault",
                    "courbet", "corot", "millet", "friedrich", "david", "gainsborough",
                    "sargent", "homer", "eakins", "reynolds", "ingres"]),
        (.modern, ["klimt", "toulouse", "lautrec", "bonnard", "vuillard", "whistler",
                   "hokusai", "hiroshige", "utamaro", "schiele", "munch"]),
        (.classic, ["monet", "renoir", "pissarro", "sisley", "degas", "cézanne", "cezanne",
                    "van gogh", "gogh", "seurat", "gauguin", "manet", "morisot", "cassatt",
                    "rousseau", "boudin"]),
    ]
}
