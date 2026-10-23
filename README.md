# KESSLER WORKS — Plant 9

Godot 4.3+ ile yapılmış birinci şahıs endüstriyel korku oyunu. Tüm harita, modeller,
ışıklar ve **63 ses efekti** kodla üretilir — harici asset gerekmez.

## Nasıl çalıştırılır
1. Godot 4.3 (veya daha yeni 4.x, **Forward+**) indir: https://godotengine.org
2. Godot'u aç → **Import** → bu klasördeki `project.godot` dosyasını seç.
3. **F5** (Play). İlk açılışta ses dosyaları otomatik içe aktarılır.

## Hikâye (altyazılar İngilizce)
Ekim 1986'da Kessler Ironworks'ün 9 numaralı fabrikasında gece vardiyasındaki 14 işçi
kayboldu. Şirket "gaz kaçağı" dedi ve fabrikayı mühürledi. 40 yıl sonra, yıkımdan önce
elektriği geri getirmek için gönderilen elektrikçisin. Telsizdeki "Harlan" sana yol
gösteriyor... ama Harlan kim?

## Görevler
1. Güvenlik kulübesinden el fenerini al
2. Ana üretim holüne gir
3. Saklanmış 3 sigortayı bul (depo, soyunma odası, dökümhane) — ilk sigortada **The Foreman** uyanır
4. Sigortaları ana şalter paneline tak
5. Kazan dairesindeki jeneratörü çalıştır (gürültülü — canavarı çeker)
6. Ustabaşı Voss'un ofisinden anahtar kartını al
7. Dökümhanedeki Line 9 konsolunu kullan → alarm, kepenk açılır, canavar öfkelenir
8. Yükleme rampasından KAÇ!

9 okunabilir belge hikâyenin gizemini çözer. Kontrol noktaları otomatik kaydedilir.

## Kontroller
| Tuş | Eylem |
|---|---|
| WASD | Hareket |
| Shift | Koş (gürültülü) |
| Ctrl / C | Çömel (sessiz) |
| Space | Zıpla |
| E / Sol tık | Etkileşim (al, oku, kapı, dolaba saklan) |
| F / Sağ tık | El feneri |
| R | Pil değiştir |
| Tab | Görevi göster |
| Esc | Duraklat (hassasiyet, ses, altyazı ayarları) |

## Mobil (iPhone / iPad — Xogot)
Dokunmatik ekranda kontroller otomatik açılır:
- **Sol taraf:** parmağını koy ve sürükle → yürü (joystick parmağını takip eder)
- **Sağ taraf:** sürükle → etrafına bak
- **USE** (el ikonu): al / oku / kapı / dolaba saklan. Etkileşilebilir bir şeye bakınca parlar ve ne yapacağını yazar (TAKE, OPEN, HIDE...)
- **LIGHT:** el feneri, çevresindeki halka pil seviyesi
- **RUN:** basılı tut, çevresindeki halka dayanıklılık
- **CROUCH:** çömel / kalk · **JUMP:** zıpla · **BATTERY:** pil değiştir (rozet = yedek pil)
- Üstte **görev** ve **duraklat** butonları. Duraklat menüsünde bakış hassasiyeti ayarı var.
- Butonlara basınca telefon hafifçe titrer.

## Haritayı düzenlemek
Harita `scenes/Level.tscn` sahnesinde. Godot'ta (veya Xogot'ta) bu dosyayı aç:
- **Geometry**: duvarlar, zemin, makineler, raflar, dolaplar (çarpışmalı her şey). Taşı, kopyala (Ctrl+D), sil.
- **Props**: kapılar, tabelalar, süslemeler, buhar, ses kaynakları. Kapıların kilit türü Inspector'da (`requirement`: power / keycard / finale / never).
- **Lights**: lambalar. Inspector'dan parlaklık (`base_energy`), elektrik gerekip gerekmediği (`needs_power`) ve titreme (`flicker`).
- **Markers**: sürükle-bırak ile ayarlanabilir noktalar
  - `PlayerSpawn`: başlangıç noktası ve yönü
  - `PatrolPoints`: canavarın devriye rotası (yeni Marker3D ekleyebilirsin)
  - `Items`: eşyalar. İsmin başı neyin çıkacağını belirler: `Flashlight`, `Fuse...`, `Keycard`, `Battery...` (yeni `Battery_X` ekle = yeni pil)
  - `Notes`: belgeler. İsim = not kimliği (notice, security, voss...)
  - `Triggers`: hikâye tetikleyicileri; CollisionShape3D ile boyutlandır
- Kaydet (Ctrl+S) ve F5 ile oyna. Canavarın yürüme ağı (navmesh) oyun başlarken yeniden hesaplanır, yani duvar taşısan da canavar yeni yolu bulur.
- Sihirli isimler: `FuseBox`, `Generator`, `Line9Console`, `ForemanDoor`, `LoadingBayShutter`, `HeCountsUs`, `AlarmLight...` — bunların ismini değiştirme, hikâye onları ismen bulur.
- Haritayı koddan sıfırdan üretmek için `tools/BakeLevel.tscn`'i açıp F6'ya bas. **Dikkat: Level.tscn'deki tüm değişikliklerin silinir.**

## Canavar (The Foreman) nasıl çalışır
- Devriye gezer, seni bulunduğun bölgeye doğru "sürüklenir"
- **Duyar**: koşmak, metal zeminde yürümek, kapılar, jeneratör
- **Görür**: görüş konisi + duvar kontrolü; fener açıksa ve ışığı ona tutarsan daha uzaktan fark eder
- Dolaba saklanırsan seni kaybeder — **ama girdiğini görürse kapıyı söküp açar**
- Kapıları kendisi parçalayarak açar, görüş kaybolunca son gördüğü yerde arar

## Ses efektlerini yeniden üretmek
`python3 tools/gen_audio.py` (numpy gerekli) — tüm `.wav` dosyalarını `audio/` içine yeniden yazar.

## Testler
- `godot --headless res://tests/Test.tscn` — tüm hikâyeyi otomatik oynar (navigasyon, kovalama, ölüm, final)
- `godot res://tests/Shots.tscn -- <klasör>` — ekran görüntüleri alır

## Proje yapısı
```
scripts/autoload/Game.gd     global durum, görevler, altyazı kuyruğu, tuş atamaları
scripts/autoload/Sfx.gd      ses yöneticisi, reverb bus'ları, telsiz sesi, müzik geçişleri
scenes/Level.tscn            düzenlenebilir harita sahnesi
scripts/world/Level.gd       haritayı kodla üretir / sahneden referansları bulur
scripts/ui/TouchControls.gd  mobil dokunmatik kontroller
tools/BakeLevel.tscn         haritayı koddan Level.tscn'e yeniden üretir
scripts/world/World.gd       hikâye yönetmeni: diyaloglar, olaylar, korkutmalar, son
scripts/player/Player.gd     FPS kontrol, stamina, fener, saklanma, korku/kalp atışı
scripts/monster/Monster.gd   The Foreman: model, animasyon, yapay zekâ
scripts/interact/*.gd        kapı, dolap, eşya, not, tetikleyici
scripts/ui/HUD.gd, Menu.gd   arayüz, ana menü, giriş hikâyesi
tools/gen_audio.py           prosedürel ses üretici
```
