# Ortam Değişkenleri (.env) Kurulumu

Bu proje hassas verileri (Supabase URL/anon key, Gemini API key) **flutter_dotenv** ile `env.example` dosyasından okur. Uygulamanın çalışması için aşağıdaki adımları uygulayın.

---

## Adım 1: flutter_dotenv ve env dosyası (tamamlandı)

- `pubspec.yaml` içine `flutter_dotenv: ^5.2.1` eklendi.
- `flutter: assets:` altına `env.example` eklendi.
- Proje kökünde `env.example` ve (isteğe bağlı) `.env` kullanılıyor.

---

## Adım 2: Kendi anahtarlarınızı env.example'a yazın

1. Proje kökündeki **`env.example`** dosyasını açın.
2. Aşağıdaki değerleri doldurun:

| Değişken | Nereden alınır |
|----------|-----------------|
| `SUPABASE_URL` | [Supabase Dashboard](https://supabase.com/dashboard) → Projeniz → **Settings** → **API** → Project URL |
| `SUPABASE_ANON_KEY` | Aynı sayfada **Project API keys** → `anon` `public` key |
| `GEMINI_API_KEY` | [Google AI Studio](https://aistudio.google.com/apikey) → API key oluştur |

Örnek (gerçek değerleri kendi projenizden alın):

```env
SUPABASE_URL=https://xxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9....
GEMINI_API_KEY=AIzaSy....
```

3. Dosyayı kaydedin.

---

## Adım 3: (İsteğe bağlı) .env kullanmak

- `env.example` dosyasını **`.env`** olarak kopyalayıp aynı değerleri orada da doldurabilirsiniz.
- **`.env`** `.gitignore`'da olduğu için commit edilmez; hassas veriler repoda görünmez.
- `.env` kullanacaksanız:
  1. `env.example` içeriğini `.env` dosyasına kopyalayın.
  2. `pubspec.yaml` → `flutter: assets:` altına `- .env` ekleyin.
  3. `lib/main.dart` içinde `dotenv.load(fileName: "env.example")` satırını şu şekilde değiştirin:
     ```dart
     try {
       await dotenv.load(fileName: ".env");
     } catch (_) {
       await dotenv.load(fileName: "env.example");
     }
     ```
  4. Böylece önce `.env`, yoksa `env.example` yüklenir.

---

## Adım 4: Paketi ve uygulamayı çalıştırma

```bash
flutter pub get
flutter run
```

- `SUPABASE_URL` veya `SUPABASE_ANON_KEY` boşsa uygulama açılışta hata verir.
- Gemini key boşsa sadece AI analiz özelliği çalışmaz; diğer sayfalar açılır.

---

## Güvenlik

- **Gerçek API anahtarlarını asla repoda commit etmeyin.**
- `.env` kullanıyorsanız zaten `.gitignore`'da; `env.example` içine gerçek key yazmayın, sadece kendi makinenizde doldurun.
- Repoyu paylaşırken `env.example` içinde sadece boş veya örnek değerler kalsın.
