# Güncelleme Günlüğü (Updates Log)

Projede yapılan önemli değişikliklerin tarihli özeti. Adım adım ne yapıldığını incelemek için kullanılır.

---

## 2025-02-12

### Hisse detay grafiği: Alım/satım okları, tooltip, MA, teknik ekran

- **Hisse detay (Fiyat Grafiği):**
  - Alım tarihlerinde grafik üzerinde **yeşil aşağı ok**, satım tarihlerinde **kırmızı yukarı ok** gösteriliyor.
  - Bu oklara tıklanınca grafiğin **altında** bir tooltip açılıyor: Alım/Satım, Adet, Fiyat, Tarih, satımda Kar %.
  - Grafikte **15 günlük (MA15)** ve **50 günlük (MA50)** kapanış fiyat ortalaması çizgileri ve legend eklendi.
  - Portföy işlemleri `SupabasePortfolioService.hisseIslemleriYukle(symbol)` ile yüklenip grafik verisine bağlandı.

- **Teknik grafik (landscape) ekranı:**
  - **Geri butonu** sol üst yerine **sol alt köşeye** taşındı.
  - Ekran `rootNavigator: true` ile açıldığı için **alt menü çubuğu** (Ana Sayfa, Geçmiş, Portföyler vb.) bu ekranda görünmüyor.
  - **Sistem çubuğu** (saat, pil, bildirim) gizlendi: `SystemUiMode.immersiveSticky` / dispose’da `edgeToEdge` ile eski haline dönüş.

- **Not:** TradingView sayfasındaki üst bar (indicator, alert, replay) ve hisse adına tıklama kaldırılmadı (sayfa dışı, kırılgan müdahale).

---

## 2025-02-12

### Finansal özet son fiyat + AI analiz prompt zenginleştirme

- **Finansal özet – Son fiyat düzeltmesi**
  - Finansal özet kartındaki "Son Fiyat" artık hisse kodunun yanındaki anlık fiyatla **aynı kaynaktan** (Yahoo `meta.price`). Öncelik: `meta?.price ?? data?.sonFiyat` (İş Yatırım sadece yedek).
  - Dosya: `lib/stock_detail_screen.dart` – `_buildOzetKartVerileri()` içinde `son_fiyat` case.

- **AI analiz prompt’u**
  - **Sistem talimatı:** Analizin **eğlenceli ve şakacı** bir dille yazılması eklendi.
  - Prompt’a eklenen alanlar (hisse detaydan açıldığında): **52 haftalık fiyat değişimi %**, **F/K**, **PD/DD**, **Son dönem net karı** (milyon/milyar TL), **Sektör / endüstri**, **Son 15 ve 52 günlük kapanış fiyat ortalamaları** (trend için). 15/52 ortalamaları yoksa servis chart verisinden hesaplıyor (`enrichWithChartAverages`).
  - Hisse detayda `HisseDetayliBilgi` (Yahoo quoteSummary) arka planda yükleniyor; sektör/endüstri AI’a iletilir.
  - Dosyalar: `lib/services/ai_analysis_service.dart` (`StockAnalysisContext`, `getAnalysis`, `enrichWithChartAverages`), `lib/widgets/ai_analysis_bottom_sheet.dart` (opsiyonel `stockContext`), `lib/stock_detail_screen.dart` (`_detayliBilgi`, `_AIAnalizButton` parametreleri).

---

## 2025-02-12

### Arama kutuları: Temizleme ikonu, büyüteç, 2 karakter sonrası öneri

- **Temizleme ikonu (X):**
  - **Ana sayfa:** Hisse ara ve Kripto ara alanlarında metin yazıldığında sağda temizleme ikonu; tıklanınca kutu temizleniyor.
  - **Portföyler – Hisse:** Hisse ara alanında aynı temizleme ikonu.
  - **Portföyler – Kripto:** Kripto varlık ara alanında aynı temizleme ikonu.
  - Hepsi `ValueListenableBuilder<TextEditingValue>` ile controller’a bağlı; metin boşken ikon gizleniyor. Tooltip: "Temizle".

- **Portföy hisse araması:**
  - Ana sayfadaki gibi **büyüteç ikonu** (`prefixIcon: Icon(Icons.search)`) eklendi.

- **Öneri davranışı:**
  - Hisse: Zaten 2. karakterden sonra öneri (Yahoo hem sembol hem ad ile arama yapıyor).
  - Ana sayfa kripto: Öneriler 2. karakterden sonra gösterilecek şekilde güncellendi (`metin.length < 2` ise boş liste).

- Dosyalar: `lib/ana_sayfa_page.dart`, `lib/hisse_page.dart`, `lib/crypto_portfolio_page.dart`.

---

## 2025-02-12

### Güncelleme günlüğü (bu dosya)

- `docs/UPDATES_LOG.md` oluşturuldu.
- Bundan sonra yapılan önemli güncellemeler bu dosyaya **tarih + kısa başlık + madde madde özet** olarak eklenecek; proje bütününde adım adım ne yapıldığı buradan takip edilebilir.

---

## 2025-02-12

### Ana sayfa kullanıcı adı, favori yıldız, günlük değişim % | Portföy K/Z tutar, sağa süpürme Alış | Hisse arama sembol

- **Ana sayfa (hisse):**
  - "Bugün" başlık satırının **en sağına** aktif kullanıcının **e-posta adresi** (Supabase `auth.currentUser?.email`) eklendi.
  - BIST 30 listesinde **favori** hisselerin logosunun **üst köşesinde** sarı **yıldız** ikonu gösteriliyor (`_favoriSet` state ile).
  - Listelenen hisselerin **güncel fiyatının altına** **günlük değişim yüzdesi** (yeşil/kırmızı) eklendi.

- **Kripto ana sayfa:**
  - "Kripto Piyasası" başlık satırının en sağına **kullanıcı e-postası** eklendi.

- **Portföyler sayfası:**
  - **Tepede:** Güncel yaklaşık değer altında gösterilen portföy kar/zarar **yüzdesinin yanına** **kar/zarar tutarı** (parantez içinde, aynı renkte) eklendi. `_portfoyKarZararTutar` getter eklendi.
  - **Hisse listesi:** Sağdaki kar/zarar **yüzdesi** biraz **küçültüldü** (font 11); **altına** **kar/zarar tutarı** (font 10) yazılıyor. `_HisseKarti` bileşenine `karZararTutar` parametresi eklendi.
  - **Sağa süpürme:** Listelenen hisseyi **sağa süpürünce** **Alış** butonu (yeşil, `Icons.add_chart`) açılıyor; tıklanınca o hisse için **alım ekranı** açılıyor (`_alisDiyaloguAc`: hisse bilgisi yüklenip `_arananHisse` ile portföye ekleme formu dolduruluyor). Slidable’a `startActionPane` eklendi.

- **Hisse arama (ana sayfa + portföyler):**
  - Arama **öncelikli olarak hisse kodu** ile yapılıyor: Sorgu 2–5 büyük harf ise (örn. CONSE, CANTE) doğrudan `chartMetaAlSymbol(sembol.IS)` çağrılıyor ve sonuç liste başına ekleniyor.
  - Yahoo search API sonuçları da **hisse açık adı** (şirket adı) ile eşleşmeye devam ediyor. Böylece hem **CONSE** hem **Consus Enerji** hem **CANTE** hem **Can Termik** yazınca ilgili hisse önerilerde çıkıyor.
  - Dosya: `lib/yahoo_finance_service.dart` – `hisseAraListele` güncellendi.

- Dosyalar: `lib/ana_sayfa_page.dart`, `lib/hisse_page.dart`, `lib/yahoo_finance_service.dart`.

---

*Son güncelleme: 2025-02-12*
