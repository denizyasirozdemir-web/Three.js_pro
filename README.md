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
Proje, betikler + sahneler + gölgelendiriciler toplamı **200 KB'ın altında** kalacak şekilde hazırlandı (~189 KB).
Bu yüzden fabrikanın duvarları ve eşyaları sahne dosyasında değil, `scripts/world/Level.gd` kodunda tanımlı.

`scenes/Level.tscn`'i Godot'ta veya Xogot'ta açınca fabrikanın tamamı editörde görünür (kod editörde de çalışır),
ama dosya sadece ~10 KB'tır. Sahnede düzenleyebileceklerin:
- **Markers/PlayerSpawn**: oyuncunun başlangıç noktası ve yönü
- **Markers/PatrolPoints**: canavarın devriye rotası. Marker3D ekle/sil/taşı.
- **Markers/Items**: eşyalar. İsmin başı neyin çıkacağını belirler: `Flashlight`, `Fuse...`, `Keycard`, `Battery...`. Yeni `Battery_X` ekle = yeni pil.
- **Markers/Notes**: belgeler. İsim = not kimliği (notice, security, maintenance, manifest, diary, scrawl, voss, incident, last).
- **Markers/Triggers**: hikâye tetikleyicileri. CollisionShape3D ile boyutlandır.
- **Custom**: buraya eklediğin her şey (StaticBody3D + CollisionShape3D + MeshInstance3D, CSGBox3D vb.) oyuna girer. Çarpışmalı nesnelerin etrafından canavar da dolaşır.

Duvarları, makineleri ve ışıkları değiştirmek için `Level.gd`'deki ilgili oda fonksiyonunu düzenle
(`_build_lobby`, `_build_hall`, `_build_warehouse`, `_build_boiler`, `_build_furnace`, `_build_lockers`, `_build_foreman`).
Örnek: `crate(Vector3(10, 0, 20))` bir kasa, `box(merkez, boyut, M.rust)` bir duvar/blok, `locker_at(konum, yön)` bir dolap,
`lamp(konum, renk, parlaklık, menzil)` bir lamba ekler. Kaydedince editördeki görüntü de güncellenir (sahneyi kapatıp aç).

## Canavar (The Foreman) nasıl çalışır
- Devriye gezer, seni bulunduğun bölgeye doğru "sürüklenir"
- **Duyar**: koşmak, metal zeminde yürümek, kapılar, jeneratör
- **Görür**: görüş konisi + duvar kontrolü; fener açıksa ve ışığı ona tutarsan daha uzaktan fark eder
- Dolaba saklanırsan seni kaybeder — **ama girdiğini görürse kapıyı söküp açar**
- Kapıları kendisi parçalayarak açar, görüş kaybolunca son gördüğü yerde arar

## Ses efektlerini yeniden üretmek
`python3 tools/gen_audio.py` (numpy gerekli) — tüm `.wav` dosyalarını `audio/` içine yeniden yazar.

## Proje yapısı
```
scripts/autoload/Game.gd     global durum, görevler, altyazı kuyruğu, tuş atamaları
scripts/autoload/Sfx.gd      ses yöneticisi, reverb bus'ları, telsiz sesi, müzik geçişleri
scenes/Level.tscn            düzenlenebilir işaretçiler (başlangıç, devriye, eşyalar, notlar, tetikleyiciler, Custom)
scripts/world/Level.gd       fabrikanın tamamını kodla üretir (editörde de)
scripts/ui/TouchControls.gd  mobil dokunmatik kontroller
scripts/ui/UI.gd             ortak arayüz parçaları (yazı, buton, stil)
scripts/world/World.gd       hikâye yönetmeni: diyaloglar, olaylar, korkutmalar, son
scripts/player/Player.gd     FPS kontrol, stamina, fener, saklanma, korku/kalp atışı
scripts/monster/Monster.gd   The Foreman: model, animasyon, yapay zekâ
scripts/interact/*.gd        kapı, dolap, eşya, not, tetikleyici
scripts/ui/HUD.gd, Menu.gd   arayüz, ana menü, giriş hikâyesi
tools/gen_audio.py           prosedürel ses üretici
```
