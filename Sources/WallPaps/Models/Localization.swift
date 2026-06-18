import Foundation

/// User-selectable UI language.
enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system, tr, en
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return t("lang.system")
        case .tr:     return "Türkçe"
        case .en:     return "English"
        }
    }
}

enum ResolvedLang { case tr, en }

/// Tiny code-based localizer (no .lproj — works with our SwiftPM/manual bundle).
/// `Localization.current` is updated from `Settings` on the main actor and read
/// from anywhere; `t("key")` returns the string for the resolved language.
enum Localization {
    nonisolated(unsafe) static var current: AppLanguage = .system

    static func resolved() -> ResolvedLang {
        switch current {
        case .tr: return .tr
        case .en: return .en
        case .system:
            let pref = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return pref.hasPrefix("tr") ? .tr : .en
        }
    }

    static func string(_ key: String) -> String {
        guard let pair = table[key] else { return key }
        return resolved() == .tr ? pair.0 : pair.1
    }

    /// key → (Turkish, English)
    static let table: [String: (String, String)] = [
        // Language
        "lang.system": ("Sistem", "System"),
        "lang.title": ("Dil", "Language"),

        // Collections
        "col.section": ("Koleksiyonlar", "Collections"),
        "col.none": ("Koleksiyon yok", "No collection"),
        "col.impressionism": ("İzlenimcilik", "Impressionism"),
        "col.postimpressionism": ("Post-Empresyonizm", "Post-Impressionism"),
        "col.japanese": ("Japon Baskıları", "Japanese Prints"),
        "col.dutch": ("Hollanda Ustaları", "Dutch Masters"),
        "col.portraits": ("Portreler", "Portraits"),
        "col.landscapes": ("Manzaralar", "Landscapes"),

        // Share
        "share.button": ("Paylaş", "Share"),
        "share.save": ("Görseli kaydet…", "Save image…"),
        "share.copy": ("Panoya kopyala", "Copy to clipboard"),
        "share.credit": ("WallPaps ile yapıldı", "made with WallPaps"),
        "share.preparing": ("Paylaşım hazırlanıyor…", "Preparing share…"),

        // Details
        "details.show": ("Detayları göster", "Show details"),

        // Featured / favorites
        "featured.nowShowing": ("SERGİLENİYOR", "NOW SHOWING"),
        "featured.next": ("Sonraki eser", "Next artwork"),
        "fav.in": ("Favoride", "Favorited"),
        "fav.add": ("Favori", "Favorite"),
        "unit.artworks": ("tablo", "artworks"),

        // Gallery window
        "gallery.subtitle": ("SANAT KOLEKSİYONU", "ART COLLECTION"),
        "room.collection": ("Koleksiyon", "Collection"),
        "room.studio": ("Atölye", "Studio"),
        "gallery.header": ("Koleksiyon", "Collection"),
        "gallery.fetching": ("eserler getiriliyor…", "fetching artworks…"),
        "gallery.refresh": ("Yenile", "Refresh"),

        // Status
        "status.loadingTitle": ("Koleksiyon hazırlanıyor", "Preparing the collection"),
        "status.loadingBody": ("İlk eserler indirilirken bir an bekleyin…", "Downloading the first artworks…"),
        "status.offlineTitle": ("İnternet bağlantısı yok", "No internet connection"),
        "status.offlineBody": ("Bağlantı gelince eserler otomatik yüklenecek.", "Artworks will load automatically when you're back online."),
        "status.emptyTitle": ("Eser bulunamadı", "No artworks found"),
        "status.emptyBody": ("Seçili sanatçı/yön/kaynak için sonuç yok. Ayarları gevşetip tekrar deneyin.", "Nothing matched your artist/orientation/source. Loosen the filters and try again."),
        "status.retry": ("Tekrar dene", "Try again"),

        // Welcome
        "welcome.title": ("WallPaps'e hoş geldin", "Welcome to WallPaps"),
        "welcome.subtitle": ("Dünyaca ünlü ressamların tabloları, çerçeveli birer 4K duvar kâğıdı olarak masaüstünde.", "Masterpieces by famous painters, framed as 4K wallpapers on your desktop."),
        "welcome.f1": ("Van Gogh, Monet, Vermeer ve daha fazlası", "Van Gogh, Monet, Vermeer and more"),
        "welcome.f2": ("Tüm görseller kamu malı (CC0) — yasal ve ücretsiz", "All images are public domain (CC0) — legal and free"),
        "welcome.f3": ("Düşük enerjiyle belirli aralıklarla yenilenir", "Refreshes on a schedule with low energy use"),
        "welcome.notify": ("Yeni tablo geçince bildir", "Notify me on each new artwork"),
        "welcome.cta": ("Koleksiyonu Aç", "Open the Collection"),
        "welcome.credit": ("Görseller: Art Institute of Chicago · The Met · Cleveland (CC0)", "Images: Art Institute of Chicago · The Met · Cleveland (CC0)"),

        // About
        "about.cc0": ("Tüm eserler kamu malı (CC0) olup müzeler tarafından sınırsız kullanıma açılmıştır.", "All works are public domain (CC0), released by the museums for unrestricted use."),

        // Menu
        "menu.retry": ("Tekrar dene", "Try again"),
        "menu.gallerysettings": ("Galeri & Ayarlar…", "Gallery & Settings…"),
        "menu.next": ("Sonraki tablo", "Next artwork"),
        "menu.favAdd": ("☆ Favorilere ekle", "☆ Add to favorites"),
        "menu.favRemove": ("★ Favorilerden çıkar", "★ Remove from favorites"),
        "menu.skip": ("Bu tabloyu atla", "Skip this one"),
        "menu.share": ("Bu eseri paylaş", "Share this artwork"),
        "menu.favorites": ("Favoriler", "Favorites"),
        "menu.favoritesOnly": ("Sadece favorileri göster", "Favorites only"),
        "menu.artists": ("Sanatçılar", "Artists"),
        "menu.interval": ("Yenileme aralığı", "Refresh interval"),
        "menu.librarySize": ("Kütüphane boyutu", "Library size"),
        "menu.frame": ("Çerçeve", "Frame"),
        "menu.theme": ("Tema", "Theme"),
        "menu.showCaption": ("Başlığı göster", "Show caption"),
        "menu.source": ("Görsel kaynağı", "Image source"),
        "menu.chooseFolder": ("Yerel klasör seç…", "Choose local folder…"),
        "menu.orientation": ("Yön", "Orientation"),
        "menu.perScreen": ("Her ekrana farklı tablo", "Different artwork per display"),
        "menu.notify": ("Yeni tabloyu bildir", "Notify on new artwork"),
        "menu.launchLogin": ("Girişte başlat", "Launch at login"),
        "menu.refresh": ("Kütüphaneyi yenile", "Refresh library"),
        "menu.openMasters": ("4K master klasörünü aç", "Open 4K masters folder"),
        "menu.working": ("Çalışıyor…", "Working…"),
        "menu.quit": ("WallPaps'ten çık", "Quit WallPaps"),

        // Settings form
        "set.source": ("Görsel kaynağı", "Image source"),
        "set.sourceLabel": ("Kaynak", "Source"),
        "set.localFolder": ("Yerel klasör", "Local folder"),
        "set.orientation": ("Yön", "Orientation"),
        "set.collection": ("Koleksiyon", "Collection"),
        "set.frame": ("Çerçeve", "Frame"),
        "set.matWidth": ("Kenarlık genişliği", "Border width"),
        "set.displayRefresh": ("Görüntü & yenileme", "Display & refresh"),
        "set.interval": ("Yenileme aralığı", "Refresh interval"),
        "set.libSizeDisk": ("Diskte eser başına ≈ 10–12 MB.", "≈ 10–12 MB per artwork on disk."),
        "set.notifFav": ("Bildirim & favoriler", "Notifications & favorites"),
        "set.general": ("Genel", "General"),
        "set.rebuild": ("Kütüphaneyi yeniden oluştur", "Rebuild library"),
        "set.about": ("Hakkında", "About"),
        "set.ambiance": ("Galeri atmosferi", "Gallery atmosphere"),
        "set.autoFrame": ("Döneme uygun çerçeve", "Period-matched frame"),

        // Exhibit / ritual
        "room.exhibit": ("Sergi", "Exhibit"),
        "exhibit.today": ("Günün sergisi", "Today's exhibition"),
        "exhibit.curatorNote": ("Küratör notu", "Curator's note"),
        "exhibit.noNote": ("Bu eser için müze notu bulunmuyor.", "No museum note for this piece."),
        "exhibit.collection": ("Senin koleksiyonun", "Your collection"),

        // Enum labels
        "interval.15m": ("15 dakika", "15 minutes"),
        "interval.30m": ("30 dakika", "30 minutes"),
        "interval.1h": ("1 saat", "1 hour"),
        "interval.3h": ("3 saat", "3 hours"),
        "interval.daily": ("Günlük", "Daily"),
        "mat.thin": ("İnce kenarlık", "Thin border"),
        "mat.medium": ("Orta kenarlık", "Medium border"),
        "mat.wide": ("Geniş kenarlık", "Wide border"),
        "source.museums": ("Yalnızca müzeler", "Museums only"),
        "source.local": ("Yalnızca yerel klasör", "Local folder only"),
        "source.both": ("Müzeler + yerel klasör", "Museums + local folder"),
        "orient.any": ("Tümü", "All"),
        "orient.landscape": ("Yatay", "Landscape"),
        "orient.portrait": ("Dikey", "Portrait"),
        "theme.classic": ("Klasik", "Classic"),
        "theme.gold": ("Altın yaldız", "Gilded gold"),
        "theme.modern": ("Modern", "Modern"),
        "theme.vintage": ("Vintage", "Vintage"),
    ]
}

/// Shorthand used throughout the UI.
func t(_ key: String) -> String { Localization.string(key) }
