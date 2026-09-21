# Cipet — Nyopet di Angkot — Prototype Gameplay

Prototipe main loop lengkap: **pilih target → tahan buat nyopet → progress lawan awareness →
berhasil / ketahuan → ulangi sampai ronde habis.** Pakai art asli dari `environment/` + `character/`.

## Jalanin

```bash
open Cipet.xcodeproj
```
Pilih simulator iPhone → Run. **Landscape**, iOS 17+.
Kalau `project.yml` diubah: `xcodegen generate`.

## Cara main

| Aksi | Kontrol |
|---|---|
| Pindah kursi | Tap kursi kosong (yang ada garis putus-putus putih) |
| Nyopet | **Tahan** penumpang di sebelah kiri/kanan kamu |
| Nyopet dua sekaligus | Dari kursi tengah, **tahan dua-duanya pakai dua jari** |
| Batal | Lepas jari — progress hangus, awareness turun sendiri |
| Jeda | Tombol pause di kanan atas (waktu, jalan, dan semua penumpang ikut berhenti) |

Bar **hijau** = progress nyopet. Bar **merah** = awareness korban. Hijau duluan penuh = dapat barang.
Merah duluan penuh = ketahuan, ronde selesai. Tanda **!** artinya awareness korban lagi naik.
Ronde 90 detik; bertahan sampai habis = menang.

Penumpang naik-turun sendiri sepanjang ronde: tiap orang punya jatah waktu ikut angkot
(`Tune.rideTime`), habis itu turun — **mau udah kecopetan atau belum, sama aja**. Kursi yang
ditinggal nganggur sebentar (`Tune.boardWait`), terus ada penumpang baru naik. Jadi dalam satu
ronde korbannya terus berganti.

## Kursi

Yang bisa diduduki cuma **jok hijau**, sesuai art. Totalnya **9 kursi**:

- **Bangku seberang — 5 kursi** (4 jok + 1 kursi lipat dekat pintu), satu jok satu orang.
  Penumpang di sini kelihatan dari depan, jadi pakai art `*_left_*` yang state-nya paling lengkap.
- **Bangku dekat — 4 kursi.** Dua jok hijau lebar, **masing-masing muat 2 orang**.
  Kelihatan dari belakang, jadi pakai art `*_right_*`.

**Copet bebas pindah ke kursi kosong mana pun**, termasuk bangku dekat. Jumlah penumpang dibatasi
`Tune.maxPassengers` (5 dari 9), jadi selalu ada 3 kursi nganggur buat pindah.

Nyopet cuma bisa ke orang yang **duduk persis di sebelah** dan **satu bangku** — beda bangku nggak
saling jangkau (`Layout.adjacent`). Kalau copet duduk pas di tengah dua penumpang, dua-duanya bisa
ditahan barengan pakai dua jari.

Kursi sopir & kursi depan warnanya krem, jadi nggak pernah bisa ditap.

## Tech stack

| Bagian | Pakai apa |
|---|---|
| Bahasa & UI | **Swift 5 + SwiftUI**, target iOS 17, landscape |
| Game loop | `Timer.publish(every: 1/60)` + `.onReceive` — bukan `TimelineView`, bukan `SKScene` |
| Gambar | `Image` + `Canvas` (buat jalan yang di-tile), semua di Asset Catalog |
| Audio | **AVFoundation** (`AVAudioPlayer`), file WAV di `Resources/Audio` |
| Project file | **XcodeGen** (`project.yml`) — `.xcodeproj` bisa di-generate ulang kapan aja |
| Dependency luar | **Nol.** Nggak ada SPM/CocoaPods/engine |

### SpriteKit atau SwiftUI?

**SwiftUI murni. Nggak ada SpriteKit sama sekali.**

Yang kita butuhin cuma: satu background yang geser horizontal, ±15 sprite diam yang gambarnya
ganti-ganti sesuai state, beberapa bar, dan UI. Nggak ada physics, collision, particle, kamera,
atau ratusan node. Buat beban segitu SwiftUI santai di 60fps, dan kita dapat HUD, tombol, layar
menang/kalah, plus SwiftUI Preview gratis — nggak perlu bikin ulang semua itu di dalam `SKScene`.

Kapan baru pindah ke SpriteKit:
- sprite udah ratusan sekaligus, atau ada particle emitter beneran (debu, konfeti, asap knalpot)
- butuh physics/collision engine
- animasi frame-by-frame sprite sheet yang rapat (bukan cuma ganti gambar per state)
- profiling nunjukin SwiftUI nggak sanggup 60fps

Pindahnya nggak bakal nyakitin: `Game` itu struct murni yang nggak impor SwiftUI sama sekali.
Kalau suatu saat ganti ke SpriteKit, yang ditulis ulang cuma lapisan gambarnya — aturan mainnya
tetap kepake apa adanya. Itu alasan utama logika dan tampilan dipisah dari awal.

### Alur kerja

```
NyopetPrototypeApp
      |
   GameView  @State var game: Game          <- satu-satunya sumber kebenaran
      |
      |  Timer 60fps -> game.tick(1/60)
      |        tick: jalan geser, timer ronde, state penumpang,
      |              penumpang naik-turun, progress copet vs awareness,
      |              menang / ketahuan
      |
      |  @State berubah -> SwiftUI render ulang
      +--> RoadLayer    (Canvas, tile jalan digeser)
      +--> CabinLayer   (body angkot -> sprite orang -> UI kursi + area tap)
      +--> HUD          (skor, timer, pause, layar akhir)

  input: SeatInput -> game.move(to:) / beginSteal / endSteal
  audio: GameView .onChange(taken / copet / phase) -> Audio.shared.play(...)
```

Arahnya satu jalur: **input → model → render**. Model nggak pernah manggil view, dan nggak pernah
manggil audio — view yang ngelihat state berubah lalu bunyiin SFX. Makanya `Game` gampang di-test
tanpa bikin UI sama sekali (lihat `runGameChecks()`).

## Isi file

| File | Isinya |
|---|---|
| `Sources/GameConfig.swift` | `Layout` (koordinat kursi), `Tune` (semua angka balancing), `Kind` (config tiap archetype) |
| `Sources/Game.swift` | Model murni: penumpang, state machine, awareness, steal, menang/kalah + self-check |
| `Sources/GameView.swift` | Gambar scene: jalan bergerak, body angkot, sprite, area tap |
| `Sources/HUD.swift` | Timer, skor, tombol pause, layar jeda & layar akhir |
| `Sources/Audio.swift` | Pemutar SFX, 3 voice per bunyi biar bisa numpuk |

## Yang perlu diketahui programmer

**Scene pakai koordinat art, bukan pixel layar.**
`environment/angkot.svg` dan `road.svg` viewBox-nya sama persis (1966.5 × 904.5) — emang
dirancang buat ditumpuk. Jadi semua digambar di ruang itu lalu di-scale sekali biar nutup layar.
Ganti HP, ganti orientasi, layout tetap bener. Posisi kursi disimpan 0...1 relatif kotak angkot
(hasil scan pixel hijau di art), bukan angka pixel.

**Tambah archetype = tambah 1 case, bukan tambah sistem.**
`Kind.config` isinya art per state + kecepatan awareness + durasi lengah + lama nyopet.
Sistem awareness dan steal-nya sama buat semua penumpang. Mau nambah "Anxious" atau "Child"?
Tambah `case`, isi `Config`, selesai — `Game.tick` nggak perlu disentuh.

**Semua angka balancing ngumpul di `enum Tune` dan `Kind.config`.**
Durasi ronde, kecepatan jalan, decay awareness, penalti pindah kursi, lama nyopet per archetype.
Nggak ada magic number nyelip di view.

**Semua kursi didefinisikan di satu tempat.** `Layout.seats` itu array `SeatSpec`: bangku mana,
titik tengah, lebar, batas jok, dan garis duduk sprite-nya. Mau nambah/geser kursi? Ubah array itu,
sisanya (gambar, area tap, penanda kosong, aturan bersebelahan) ikut sendiri.

**Nyopet bisa lebih dari satu target.** `Game.steals` itu `[kursi: progress]`, bukan satu target.
Tiap target punya progress sendiri dan awareness sendiri. Di view, tiap kursi pasang
`simultaneousGesture` (bukan `gesture`) supaya dua kursi bisa ditahan barengan. Kalau pemain cuma
pakai satu jari, jalannya persis kayak satu target — nggak ada yang berubah.

**Penumpang keluar-masuk sendiri.** Tiap penumpang bawa `rideLeft`. Habis waktunya, dia turun —
nggak peduli udah kecopetan atau belum. Kursinya nganggur selama `Tune.boardWait` (acak), terus
diisi penumpang baru dengan archetype acak yang beda dari tetangganya. Kalau kursinya lagi diduduki
copet, penumpang baru nunggu sampai copetnya pindah.

**State machine penumpang:** `busy → waking → alert → busy`.
`waking` itu jendela peringatan singkat (art `sleepy_left_wakeup`) — pemain masih sempat lepas.
Awareness naik pelan pas `busy`, cepat pas `alert`. Kalau nggak lagi dicopet, awareness turun sendiri.
Duo sengaja dikasih durasi fix (bukan random) biar A dan B berhenti ngobrol barengan.

**Logika kepisah dari tampilan.** `Game` itu struct murni tanpa SwiftUI. `runGameChecks()` di bawah
`Game.swift` nguji aturan kursi, adjacency, sukses, ketahuan, dan ronde habis — jalan tiap app
dibuka di DEBUG, app langsung crash kalau ada aturan yang rusak.

**Game loop-nya satu `Timer` 60fps**, bukan `TimelineView`. Semua yang gerak (jalan, getaran mesin,
timer, awareness) maju dari `Game.tick(dt)` yang sama, jadi gampang di-pause dan di-test.

## Catatan audio

SFX-nya **placeholder yang di-generate**, bukan rekaman — `sfx_success` (dapat barang),
`sfx_caught` (ketahuan), `sfx_move` (pindah kursi), `sfx_win` (lolos sampai turun).
Tinggal timpa file `.wav`-nya di `Resources/Audio` pakai nama yang sama, nggak usah ubah kode.

Session-nya `.ambient` + `.mixWithOthers`: ikut tombol silent dan nggak motong musik yang lagi
diputar pemain. Kalau nanti mau bunyi tetap keluar walau silent, ganti ke `.playback` di
`Audio.init`.

## Catatan art

- File `.svg` di `environment/` dan `character/` sebenarnya PNG yang dibungkus SVG, dan tiap file
  karakter itu **sprite sheet 12 pose** yang di-crop ke satu sel. Sudah diekstrak jadi PNG
  transparan satu-satu ke `Resources/Assets.xcassets`. Kalau art-nya di-update, ekstrak ulang —
  jangan drag `.svg`-nya langsung ke Xcode, Xcode nggak bisa baca raster di dalam SVG.
- `copet_left_act_left` dan `copet_left_act_right` isinya pose yang sama persis, jadi yang kiri
  dicermin di kode. Begitu juga `sleepy_right_idle` dan `sleepy_right_sleeping`.
- "Zzz" di `sleepy_*_sleeping` bentuknya teks vektor dan nggak keikut waktu diekstrak, jadi
  digambar ulang di SwiftUI (sekalian bisa dianimasiin).
- Art `copet_left_act_*` itu **ngejangkau ke kiri**. Buat target di kanan, sprite-nya dicermin
  (`scaleEffect(x: -1)`) — jangan dibalik lagi, nanti arahnya kebalik.
- Duo belum punya art `aware`/`shock`, sementara pakai `idle`. Bar merah + tanda **!** yang
  nanggung info bahayanya.

## Belum ada (sengaja)

Musik latar, menu utama, high score, archetype Anxious/Child/Driver, nyawa lebih dari satu.
Ketahuan = ronde langsung selesai, biar satu jalur kode dan tensinya kerasa.

Waktu nyopet dua orang barengan, pose copet cuma bisa ngadep satu arah — art `act` cuma ada satu
tangan. Kalau mau, bisa ditambah pose "dua tangan" nanti.

Copet yang duduk di **bangku dekat** cuma punya `copet_right_idle` — belum ada art nyopet/geser
tampak belakang, jadi pose-nya diam walau lagi nyopet. Bar hijau/merah yang nanggung feedback-nya.
