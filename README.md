# WallPaps 🖼️

**🌐 [wallpaps.vercel.app](https://wallpaps.vercel.app)** · **📥 [İndir (DMG)](https://github.com/sdemirbas/WallPaps/releases/latest/download/WallPaps.dmg)** · macOS 14+ · ücretsiz · CC0

Dünyaca ünlü ressamların **kamu malı (public domain)** tablolarını, sade bir
**paspartu/çerçeve** içinde **4K** masaüstü duvar kâğıdına dönüştüren ve belirli
aralıklarla **düşük enerjiyle** yenileyen, ücretsiz bir macOS menü-çubuğu uygulaması.

Görseller üç açık-erişim müze API'sinden gelir (anahtar gerektirmez, hepsi CC0):

- **Art Institute of Chicago** — IIIF Image API ile yüksek çözünürlük
- **The Metropolitan Museum of Art** — Open Access `primaryImage`
- **Cleveland Museum of Art** — Open Access, full-res (>10000px)

Arayüz **Türkçe ve İngilizce** (sistem diline göre otomatik; menüden değiştirilebilir).

## Özellikler

- 🎨 Van Gogh, Monet, Vermeer, Rembrandt, Hokusai, Klimt, Renoir, Cézanne, Degas,
  Seurat, Toulouse-Lautrec, Delacroix (menüden açılıp kapatılabilir)
- 🖼️ Tablo ortada; ince mat + çerçeve + altında "Sanatçı · Yıl"
- 📐 Her eser için **3840×2160 4K master** arşivlenir; duvar kâğıdı ekranın
  native çözünürlüğünde ayrıca render edilir (ultra-wide dahil, kırpılmadan)
- 🖥️ **Her ekrana farklı tablo** seçeneği (çoklu monitör)
- ⭐ **Favoriler**: beğendiğin tabloyu yıldızla, menüden tek tıkla geri uygula;
  **"Sadece favorileri göster"** ile yalnızca favoriler arasında döndür
- 📁 **Kendi görsel klasörün**: yerel bir klasördeki görselleri de aynı çerçeve
  içinde döndür (yalnızca müzeler / yalnızca yerel / ikisi birden)
- 🎨 **Çerçeve temaları**: Klasik · Altın yaldız · Modern · Vintage
- 🔔 **Bildirim**: yeni tablo geçtiğinde "günün eseri" bildirimi (4K küçük resimli)
- ↔️ **Yön filtresi**: Tümü / Yatay / Dikey (geniş ekranlar için "Yatay" ideal)
- 🖼️ **Müze tarzı galeri penceresi**: serif tipografi, galeri-duvarı zemin, pirinç
  vurgular; her eserin altında **sanatçı adı + başlık** (müze etiketi gibi). Tabloları
  önizle, tıkla-uygula, favorile; tüm ayarları "Atölye" sekmesinden yönet
- 📚 **Kütüphane boyutu ayarlanabilir**: 40 / 100 / 200 / 400 tablo (varsayılan 100).
  Kaynaklarda toplam **400.000+** CC0 eser var; havuz sayfalama ile dolar
- ✨ **Animasyonlu karşılama**: ilk açılışta çerçeve kendini çizer, tablo belirir,
  yaldız parıltısı geçer (Reduce Motion'a saygılı)
- 🌍 **Çoklu dil**: Türkçe / İngilizce (sistem diline göre otomatik)
- 📤 **Paylaşılabilir export**: çerçeveli 4K görseli "✦ WallPaps ile yapıldı"
  kredisiyle paylaş / kaydet / kopyala
- 🗂️ **Küratörlü koleksiyonlar**: İzlenimcilik, Post-Empresyonizm, Japon Baskıları,
  Hollanda Ustaları, Barok, Portreler, Manzaralar + "Bu haftanın koleksiyonu" vitrini
- 🌐 **Uzaktan güncellenebilir katalog**: yeni sanatçı/koleksiyonlar uygulama
  güncellemesi olmadan eklenebilir (GitHub'daki `catalog/catalog.json`)
- 📜 **Eser bilgisi**: teknik, ölçü, müze açıklaması (yalnızca müzeden gelen gerçek metin)
- 🏛️ **Galeri atmosferi**: duvar kâğıdı, aydınlatılmış galeri duvarı gibi —
  spot ışığı + vinyet + ince doku + günün saatine göre ısınan ortam + kabartmalı
  pirinç müze etiketi (sanatçı · eser · teknik)
- 🖼️ **Sergi modu**: galeri penceresinde eseri büyük, yavaş Ken Burns kaymasıyla,
  yanında "Küratör notu" paneliyle izle
- 🖌️ **Döneme uygun çerçeve**: Barok→yaldız, empresyonist→klasik, modern→minimal otomatik
- 🎯 **Özel uygulama ikonu** (çerçeveli tablo motifi)
- 🔋 `NSBackgroundActivityScheduler` ile düşük enerji: ağır iş (indir + render)
  seyrek/arka planda; her yenilemede yalnızca önceden render edilmiş görsele geçiş
- ⏱️ Yenileme aralığı: 15 dk / 30 dk / 1 saat / 3 saat / Günlük
- 🚀 Girişte otomatik başlatma (`SMAppService`)

## Derleme & Çalıştırma

Gereksinim: Xcode 26 / Swift 6 (macOS 14+).

```bash
# Derle, .app paketle, ad-hoc imzala
./Scripts/build-app.sh

# Çalıştır (menü çubuğunda 🖼️ simgesi belirir)
open WallPaps.app

# (İsteğe bağlı) Uygulamalar'a kur
cp -R WallPaps.app /Applications/
```

Geliştirme sırasında hızlı deneme:

```bash
swift run            # menü-çubuğu uygulaması olarak başlar
```

> Not: "Girişte başlat" yalnızca paketlenmiş `.app` ile çalışır (`swift run` ile değil).

## Katalog güncelleme — sanatçı eklemek (uygulama güncellemesi olmadan)

Sanatçı ve koleksiyon listesi **uzaktan** `catalog/catalog.json` dosyasından gelir. Yeni
sanatçı eklemek için bu dosyaya bir satır ekleyip GitHub'a push'lamak yeterli — kullanıcılar
bir sonraki açılışta (en geç bir gün içinde) görür, **yeni sürüm gerekmez**:

```jsonc
{ "name": "Hilma af Klint", "displayName": "af Klint" }
```

Uygulama manifest'i `https://raw.githubusercontent.com/sdemirbas/WallPaps/main/catalog/catalog.json`
adresinden çeker (`CatalogService.swift` içindeki `manifestURL`). Ağ/erişim olmazsa uygulama
**gömülü varsayılan kataloğa** (53 sanatçı) düşer — asla kırılmaz.

## Dağıtım (ücretsiz, GitHub)

```bash
./Scripts/make-dmg.sh        # imzasız DMG üretir
```

DMG'yi **GitHub Releases**'e yükle. Apple Developer ücreti olmadan dağıtım: kullanıcı
indirince ilk açılışta **sağ tık → Aç** (Gatekeeper) demelidir — README'de belirt.

> İleride uyarısız kurulum istersen: Apple Developer Program ($99/yıl) ile `./Scripts/notarize.sh`
> (Developer ID + notarize + staple) veya `./Scripts/build-appstore.sh` (App Store) hazır.

## Dosyalar nerede?

`~/Library/Application Support/WallPaps/`
- `sources/` — indirilen orijinal görseller (varyantlar bunlardan üretilir)
- `masters/` — 3840×2160 4K arşiv (menüden "4K master klasörünü aç")
- `wallpapers/` — ekran boyutu + çerçeve stiline göre üretilen duvar kâğıtları
- `library.json` — havuz ve sıralama durumu
- `favorites.json` — favori tablolar

## Bilinen sınırlamalar

- **Spaces**: macOS `setDesktopImageURL` yalnızca *aktif* masaüstünü (Space)
  değiştirir; diğer Space'ler kendi görselini korur.
- Bazı eserler 4K'dan küçük olabilir; bu durumda tablo büyütülmez (keskin kalır),
  4K tuval üzerinde ortalanır.
- İlk açılışta havuz boşken birkaç eser indirilene kadar kısa bir bekleme olur.

## Telif

Tüm görseller **CC0 / kamu malı** eserlerdir; müzeler tarafından sınırsız kullanıma
açılmıştır. Banksy gibi **çağdaş/telifli** sanatçılar bu sürümde **bilinçli olarak
yer almaz** — bu, uygulamanın yasal ve serbestçe paylaşılabilir kalmasını sağlar.
