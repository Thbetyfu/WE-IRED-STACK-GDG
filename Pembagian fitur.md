# Pembagian Fitur — Tim WE-IRED

Dokumen ini membagi seluruh pekerjaan WE-IRED (30 fitur di [PRD](docs/PRD.md), 5 komponen) kepada tiga anggota tim. Setiap tugas diberi ID, rincian pekerjaan, lokasi folder, rujukan kebutuhan di [SRS](docs/SRS.md), dan kriteria selesai.

---

## 1. Ringkasan Pembagian

| Anggota | Peran | Fokus utama | Beban (poin) | Porsi |
|---|---|---|---|---|
| **Nopal** | Tech lead & integrator | Backend Go, Dashboard Pengurus, paket `core`, WhatsApp, Posko Lokal, AI, deployment | **84** | **± 48%** |
| **Joshua** | Hardware & protokol | WE-IRED Beacon (perangkat keras + firmware), relay Bluetooth & mesh, backend beacon/relay, BMKG | **56** | **± 32%** |
| **Thoriq** | UI/UX & konten | Aplikasi Warga, layar operasional Aplikasi Relawan, design system, peta, edukasi & P3K | **34** | **± 20%** |
| | | **Total** | **174** | 100% |

**Cara membaca poin:** poin adalah **ukuran relatif besar-kecilnya pekerjaan**, bukan jam. 1 poin ≈ satu pekerjaan kecil yang jelas, dan 5 poin ≈ pekerjaan besar yang melibatkan banyak bagian. Poin dipakai untuk menjaga porsi tetap seimbang sesuai kesepakatan (Nopal paling banyak, Joshua di bawah Nopal, Thoriq paling sedikit).

**Istilah:**
- **PIC fitur** = orang yang bertanggung jawab memastikan fitur itu jalan dari ujung ke ujung (koordinasi + demo), walaupun bagiannya dikerjakan beberapa orang.
- **Pemilik tugas** = orang yang menulis kode/merakit bagian tersebut.

---

## 2. Matriks Fitur

| ID | Fitur | PIC fitur | Nopal | Joshua | Thoriq |
|---|---|---|---|---|---|
| F-01 | Pendataan Rumah & Anggota | Nopal | Backend, halaman Data RT | — | Layar "Rumah Saya" |
| F-02 | Titik Kumpul | Nopal | Backend, halaman Data RT | — | Tampil di peta |
| F-03 | Relawan & Blok | Nopal | Backend, halaman Data RT | — | — |
| F-04 | Edukasi Kesiapsiagaan | Thoriq | — | — | Backend, layar warga, admin, konten |
| F-05 | Mode Latihan | Nopal | Backend + metrik + halaman riwayat | — | Banner "LATIHAN" di UI |
| F-06 | Manajemen Beacon | Joshua | — | Backend, halaman Beacon, provisioning | — |
| F-07 | Aktivasi Mode Siaga | Nopal | Backend + alur aktivasi dashboard | — | Beranda mode siaga |
| F-08 | Laporan Status Rumah | Thoriq | Penerimaan & resolusi laporan | — | Layar lapor |
| F-09 | Laporan Atas Nama Warga | Thoriq | Endpoint laporan relawan | — | Layar lapor atas nama |
| F-10 | Dashboard Real-time | Nopal | WebSocket + halaman ringkasan | — | — |
| F-11 | Peta Interaktif | Thoriq | — | Lapisan beacon | Widget peta + halaman peta |
| F-12 | Tabel Triase | Nopal | Halaman triase | — | — |
| F-13 | Skor Prioritas & Rencana | Nopal | Algoritma + halaman penugasan | — | — |
| F-14 | Penugasan Relawan | Nopal | Backend + papan tugas | — | Layar tugas relawan |
| F-15 | Pengumuman | Nopal | Backend, tanda tangan, editor | — | Carousel warga |
| F-16 | Panduan P3K | Thoriq | — | — | Konten + layar |
| F-17 | Outbox & Sinkronisasi | Nopal | `core` outbox + endpoint sync | — | Indikator status kirim |
| F-18 | Relay Warga → Relawan | Joshua | Endpoint terima paket | `ble_relay`, kolektor | — |
| F-19 | Mesh Multi-hop | Joshua | — | LUV, TTL, kuota | — |
| F-20 | Pengumuman via Mesh | Joshua | Format & kunci Ed25519 | Penyebaran & verifikasi | — |
| F-21 | Posko Lokal | Nopal | Mode posko, snapshot, push/pull | Sinkron beacon → posko | Layar QR posko relawan |
| F-22 | WE-IRED Beacon | Joshua | — | Hardware, firmware, check-in | — |
| F-23 | Topologi Relay | Joshua | — | Layar relawan + dashboard | — |
| F-24 | Hemat Baterai | Joshua | — | Siklus BLE | Layar pengaturan |
| F-25 | Hapus Cache 72 Jam | Joshua | — | HP & beacon | — |
| F-26 | Rekap Kebutuhan | Nopal | Agregasi, PDF/CSV, halaman rekap | — | — |
| F-27 | Asisten AI | Nopal | Modul AI + anonimisasi | — | — |
| F-28 | BMKG / InaRISK | Joshua | Banner di dashboard | Polling & pencocokan | — |
| F-29 | Multi-RT | Nopal | Backend + halaman wilayah | — | — |
| F-30 | Kanal WhatsApp | Nopal | Seluruh integrasi | — | Layar OTP onboarding |

---

## 3. Rincian Tugas — Nopal (84 poin)

**Peran:** tech lead. Pemilik kontrak **API** dan **model data**, reviewer default untuk backend, integrator akhir, dan pengelola deployment.

### 3.1 Fondasi & Kontrak

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| N-01 | Inisialisasi repo & CI | Melos workspace, `go mod init`, workflow GitHub Actions: `flutter analyze`, `flutter test`, `go test`, `golangci-lint`, gitleaks, build APK per ABI | root, `.github/workflows/` | NFR-MNT-01, NFR-SEC-05 | 2 |
| N-02 | Platform backend | Loader konfigurasi `.env`, pool pgx, golang-migrate, logging `slog`, format galat standar, rate limiter, antrean `jobs` (`SKIP LOCKED`), `/healthz`, `/metrics` | `backend/internal/platform`, `backend/cmd/weired` | SDD 3.2, 9.7, 14 | 3 |
| N-03 | Paket `core` | Model Dart sesuai SDD 5, API client (dio + refresh token), WebSocket client dengan `last_event_id`, skema Drift (SDD 5.3), sesi di `flutter_secure_storage` | `packages/core` | SDD 5.3, 9.6 | 3 |
| N-04 | Outbox & deteksi endpoint | Outbox transaksional, `OutboxWorker` dengan backoff 2 s–5 menit, deteksi cloud → Posko via `/healthz` 3 s, snapshot lokal | `packages/core/lib/src/outbox` | FR-SYNC-01–04, NFR-REL-01 | 2 |

### 3.2 Autentikasi & Data Master

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| N-05 | Autentikasi | OTP via WhatsApp (5 menit, maks. 5 percobaan/15 menit), login email+sandi Argon2id, JWT 15 menit + refresh 30 hari (rotasi & cabut), middleware RBAC + cek lingkup RT/blok/rumah, aktivasi kode undangan + pembuatan kunci rumah 32 byte | `backend/internal/auth` | FR-AUTH-01–08 | 4 |
| N-06 | Wilayah & peran | Hierarki kelurahan → RW → RT, keanggotaan peran, isolasi data antar-RT | `backend/internal/region` | FR-MRT-01–02 | 1,5 |
| N-07 | Rumah & anggota | CRUD rumah/anggota, auto-flag lansia/balita, pencatatan & pencabutan persetujuan (hapus data rentan ≤ 24 jam), impor CSV dengan laporan galat per baris, kode undangan + kirim WA, ekspor data rumah, enkripsi AES-256-GCM `health_notes_enc` & `key_enc`, `short_id` acak 8 byte | `backend/internal/household` | FR-HH-01–08, NFR-SEC-03, NFR-PRV-02 | 4 |
| N-08 | Titik kumpul, blok, relawan | CRUD titik kumpul (fasilitas, kapasitas), relasi blok–titik kumpul utama/cadangan, CRUD blok & relawan, ketersediaan relawan, pembatasan akses relawan per blok | `backend/internal/assembly`, `backend/internal/volunteer` | FR-AP-01–02, FR-VOL-01–04 | 2 |

### 3.3 Operasi Insiden

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| N-09 | Siklus insiden | Aktivasi (jenis, mode nyata/latihan, cakupan blok), konfirmasi 2 langkah, aturan satu insiden nyata aktif, akhiri insiden, `short_id`, perhitungan metrik `t90`, `t100`, `vuln_reached_30`, `by_channel`, `offline_delivery`, `t_recap` | `backend/internal/incident` | FR-INC-01–08, SDD 6.5 | 4 |
| N-10 | Laporan & resolusi status | Endpoint laporan tunggal, laporan relawan atas nama warga (`seq` server), idempotensi (`id` & `(incident, household, seq)`), algoritma resolusi SDD 6.2 termasuk aturan "kritis tidak tertimpa check-in", tabel `household_states`, riwayat laporan | `backend/internal/report` | FR-RPT-04–08, FR-PRX-01–03 | 4 |
| N-11 | Endpoint sinkronisasi | `/sync/reports` (batch ≤ 50, hasil per item), `/sync/relay-packets` (memakai decoder dari J-20), `/sync/snapshot`, `/sync/acks`, tabel `events` | `backend/internal/sync` | FR-SYNC, SDD 8.1, 9.4 | 2 |
| N-12 | Skor prioritas & rencana | Rumus SDD 6.1 (U+V+W+N+D), `score_breakdown`, hitung ulang saat laporan baru + tiap 60 s, greedy rencana penugasan SDD 6.3, **uji unit ≥ 80%** termasuk dua contoh hitungan di SDD | `backend/internal/priority` | FR-PRI-01–04, FR-TSK-01 | 3 |
| N-13 | Penugasan | Status tugas (disarankan → … → selesai/ditolak), hasil penjangkauan, tanda tugas tidak diterima 5 menit, notifikasi relawan | `backend/internal/task` | FR-TSK-02–05 | 2 |
| N-14 | Pengumuman | CRUD pengumuman (level, kedaluwarsa, kanal), tanda tangan Ed25519, **pemberitahuan insiden tipe `0x11`**, kunci turunan untuk Posko. Format biner disepakati dengan Joshua (J-13) | `backend/internal/announcement` | FR-ANN-01–04, SDD 7.6 | 2 |
| N-15 | Real-time | Hub WebSocket per insiden, event SDD 9.6, pemulihan dengan `last_event_id`, target ≤ 3 s | `backend/internal/realtime` | FR-DSH-02, NFR-PERF-03 | 2 |

### 3.4 Posko Lokal

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| N-16 | Mode posko | Flag `--mode=posko`, ekspor/impor snapshot terenkripsi kata sandi, push/pull `events` dengan kursor, penerapan idempoten, tabel `sync_conflicts`, antrean pekerjaan internet (WA/FCM) untuk cloud, HTTPS self-signed + sidik jari di QR | `backend/internal/posko` | FR-PSK-01–06, SDD 8.2–8.3 | 5 |

### 3.5 Integrasi

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| N-17 | WhatsApp Cloud API | Pengajuan 5 template ke Meta (`otp_login`, `siaga_aktivasi`, `siaga_pengingat`, `pengumuman_rt`, `rekap_insiden`), pengiriman, webhook + verifikasi tanda tangan, laporan dari tombol `RPT|…`, alur sesi "Butuh bantuan" (list → urgensi → pesan), pengingat T+10/T+25, balasan untuk nomor tak terdaftar, pencatatan status pesan | `backend/internal/notify/whatsapp` | FR-WA-01–08, SDD 10.1 | 5 |
| N-18 | FCM | Topik per RT, token perangkat, payload prioritas tinggi untuk aktivasi & penugasan | `backend/internal/notify/fcm` | FR-INC-03, SDD 10.2 | 1 |
| N-19 | Rekap | Agregasi FR-RCP-01, catatan & persetujuan pengurus, PDF (maroto) ≤ 10 s, CSV, kirim dokumen via WA, versi agregat tanpa detail kesehatan untuk Admin Wilayah | `backend/internal/recap` | FR-RCP-01–05, NFR-PERF-06 | 3 |
| N-20 | Asisten AI | Antarmuka `LLMProvider`, penyedia Ollama & Gemini, anonimisasi (`[WARGA_n]`, hapus telepon/alamat/kesehatan), endpoint ringkasan/klasifikasi/draf rekap, label "Dibuat dengan bantuan AI", saklar per RT | `backend/internal/ai` | FR-AI-01–07, SDD 10.4 | 3 |
| N-21 | Audit & data sintetis | Audit log akses data rentan/ekspor/insiden, generator data sintetis (RT, ± 100 rumah, anggota rentan, relawan, laporan) bertanda `is_synthetic` | `backend/internal/audit`, `backend/tools/seed` | FR-ADM-01–03 | 2 |

### 3.6 Dashboard Pengurus

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| N-22 | Kerangka dashboard | Login (sandi & OTP), navigasi samping, guard per peran, pemilih RT, indikator koneksi cloud/Posko, build Web & Windows | `apps/dashboard/lib/app` | SDD 4.5 | 2 |
| N-23 | Halaman Data RT | Tabel & form rumah/anggota, pencatatan persetujuan, pilih lokasi di peta (memakai widget T-03), impor CSV + laporan galat, blok, relawan, titik kumpul, kirim kode undangan | `features/rt_data` | F-01–F-03 | 4 |
| N-24 | Ringkasan insiden | Kartu status per kategori, waktu sejak aktivasi, alur aktivasi 2 langkah (nyata/latihan), akhiri insiden, banner BMKG dari J-22 | `features/incident_overview` | FR-DSH-01, FR-INC-01–02, FR-EXT-02 | 2 |
| N-25 | Triase | Tabel sortir/filter (status, blok, kerentanan, kanal), daftar Belum Melapor urut prioritas, tombol *Locate*, panel detail rumah + riwayat laporan + rincian skor | `features/triage` | FR-DSH-03, 07–10, FR-PRI-04 | 3 |
| N-26 | Penugasan | Daftar rencana yang disarankan, setujui/ubah, papan status tugas, tanda tugas terlambat | `features/assignments` | FR-TSK-01–05 | 2 |
| N-27 | Editor pengumuman | Input 160 karakter + penghitung, level, kedaluwarsa, pilihan kanal (push/WA/relay) | `features/announcements` | FR-ANN-01–02 | 1 |
| N-28 | Riwayat & latihan | Daftar insiden lalu, grafik perbandingan metrik antar-latihan | `features/history_drills` | FR-INC-07–08 | 1,5 |
| N-29 | Halaman rekap | Pratinjau, catatan, tombol draf AI (berlabel), setujui, unduh PDF/CSV, kirim WA | `features/recap` | FR-RCP, FR-AI-03 | 2 |
| N-30 | Halaman wilayah | Agregat multi-RT untuk Admin Wilayah, pengumuman ke banyak RT | `features/region` | FR-MRT-03–04 | 1,5 |
| N-31 | Audit & Posko | Halaman audit log, halaman Posko: impor snapshot, status sinkron cloud, QR konfigurasi relawan | `features/audit`, `features/posko` | FR-ADM-02, FR-PSK-04 | 1,5 |

### 3.7 Deployment & Uji Sistem

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| N-32 | Deployment | `docker-compose.cloud.yml`, `docker-compose.posko.yml`, `Caddyfile`, deploy VPS + domain HTTPS (dibutuhkan webhook WA), cadangan `pg_dump` harian | `deploy/` | SDD 12, NFR-REL-03–04 | 2 |
| N-33 | Uji beban & end-to-end | Skrip k6 (300 laporan/menit/RT, 50 RT), koordinasi skenario AC-01–AC-11 bersama tim, uji integrasi testcontainers | `backend/`, `docs/` | NFR-PERF-01–02, SRS 6 | 2 |

---

## 4. Rincian Tugas — Joshua (56 poin)

**Peran:** pemilik **WE-IRED Beacon** (perangkat keras + firmware) dan pemilik kontrak **protokol Bluetooth** (format paket, UUID, LUV, vektor uji). Reviewer default untuk semua kode BLE dan firmware. Sekitar setengah beban Joshua ada di hardware/firmware, dan sisanya software yang berhubungan langsung dengan Bluetooth dan beacon.

### 4.1 Perangkat Keras Beacon

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| J-01 | Pengadaan komponen | Beli komponen sesuai BOM (minimal 2 unit beacon + cadangan sel 18650), catat toko, harga aktual, dan foto | `hardware/bom` | HRD 4 | 1,5 |
| J-02 | Prototipe breadboard | ESP32-S3 + OLED + DS3231 (I2C GPIO8/9) + 3 LED + buzzer via NPN + tombol, sesuai tabel pin HRD 5.1 | `hardware/wiring` | HRD 5.1, 5.4, 5.5 | 2 |
| J-03 | Rangkaian daya | Panel 6V 5W → CN3791 → BMS 1S → 3× 18650 paralel → saklar → buck-boost 3,3 V, pembagi tegangan ke GPIO4, status CHRG/DONE ke GPIO15/16, kapasitor 470 µF | `hardware/wiring` | HRD 5.2–5.3 | 2,5 |
| J-04 | Perakitan final & casing | Pindah ke PCB prototipe, casing IP65 (jendela OLED, cable gland di bawah, tombol & saklar tahan air, silica gel), bracket tiang | `hardware/enclosure` | HRD 5.6, 8 | 2,5 |
| J-05 | Dokumentasi hardware | Skema wiring final, foto tiap tahap, catatan revisi, perbarui HRD jika ada perubahan pin/komponen | `hardware/`, `docs/HRD.md` | HRD | 1 |

### 4.2 Firmware Beacon

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| J-06 | Kerangka firmware | Proyek PlatformIO `esp32-s3-devkitc-1`, `include/pins.h`, konstanta UUID, tugas FreeRTOS, mesin status BOOT/PROVISIONING/NORMAL/SIAGA/HEMAT/KRITIS/DEEP_SLEEP | `firmware/beacon` | HRD 7.1–7.2 | 2 |
| J-07 | Server BLE | NimBLE: layanan beacon + karakteristik `NODE_INFO`, `LUV`, `INBOX`, `OUTBOX`, `ANNOUNCE`, `BEACON_PROVISION`, `BEACON_STATUS`, framing, data iklan 12 byte + scan response, interval iklan per mode | `firmware/beacon/src/ble` | FR-BCN-02–03, SDD 7.1–7.4, HRD 7.7 | 3 |
| J-08 | Penyimpanan paket | LittleFS segmen 64 paket, indeks di PSRAM, deduplikasi kunci, kapasitas 5.000 paket, ACK, prune 72 jam, aturan buang saat penuh, tahan cabut daya | `firmware/beacon/src/store` | FR-BCN-03, FR-BCN-10, HRD 7.3 | 2,5 |
| J-09 | Pengumuman & insiden | Verifikasi Ed25519, simpan pengumuman terbaru, pemberitahuan insiden `0x11` → masuk/keluar SIAGA, tolak tanda tangan salah | `firmware/beacon/src/store` | FR-BCN-04, HRD 7.2 | 1,5 |
| J-10 | Sinkron Wi-Fi | Koneksi ke hotspot Posko, `POST /api/v1/beacon/sync` dengan header HMAC, kirim paket + flag `langsung`, telemetri, terima ACK + waktu + pengumuman, jadwal 30 s / ≥ 20 paket | `firmware/beacon/src/sync`, `src/timekeeper` | FR-BCN-07–09, SDD 8.4 | 2 |
| J-11 | Manajemen daya | ADC baterai + kalibrasi, status charger, ambang 3,60/3,40/3,30 V, mode HEMAT/KRITIS, deep sleep + bangun berkala | `firmware/beacon/src/power` | HRD 6, NFR-PWR-02 | 1,5 |
| J-12 | OLED, LED, buzzer, tombol | Tampilan OLED HRD 7.6, pola LED & buzzer HRD 7.5, tombol singkat/5 s/15 s, mode provisioning + reset pabrik | `firmware/beacon/src/ui` | FR-BCN-11–12, HRD 7.4–7.6 | 1,5 |

### 4.3 Protokol & Software Bluetooth

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| J-13 | Vektor uji protokol | **Dikerjakan paling awal** karena dipakai semua pihak: `relay_packet.json`, `luv.json`, `announcement.json` (format dari N-14), `beacon_sync.json` | `docs/test-vectors` | SDD 7, 8.4 | 1,5 |
| J-14 | Codec Dart | Encoder/decoder paket 46 byte + path, HMAC-SHA256 8 byte, framing `[msg_id][idx][total]`, lulus vektor uji | `packages/ble_relay/lib/src/codec` | FR-BLE-03–04, SDD 7.2–7.3 | 2 |
| J-15 | GATT server & klien | Peripheral (`ble_peripheral`) + central (`flutter_blue_plus`), negosiasi MTU 247, alur sesi SDD 7.4, batas sesi 5 s | `packages/ble_relay/lib/src/gatt` | FR-BLE-01–02, NFR-PERF-04 | 3 |
| J-16 | Siklus peran & daya | Siklus advertising/scanning/cooldown (normal 8/4/30 s, hemat 4/2/90 s), deteksi baterai < 20%, mode manual, foreground service selama siaga, cache peer 60 s | `packages/ble_relay/lib/src/cycle` | FR-BLE-10–11, 13, F-24 | 2,5 |
| J-17 | Mesh LUV | Diff LUV, TTL 6, kuota 500 paket, prioritas paket kritis, propagasi ACK, prune 72 jam / setelah ACK, isi paket orang lain tidak ditampilkan | `packages/ble_relay/lib/src/mesh` | FR-BLE-05–08, 12, F-19, F-25 | 3,5 |
| J-18 | Mode kolektor | Pemindaian agresif relawan, tarik semua paket, dorong pengumuman & ACK, kirim batch ke `/sync/relay-packets` beserta `path` | `packages/ble_relay/lib/src/collector` | FR-BLE-02, F-18 | 1,5 |
| J-19 | Pengumuman via mesh | Verifikasi Ed25519 di HP, sebarkan pengumuman lewat `ANNOUNCE`, `announce_version` di data iklan | `packages/ble_relay` | FR-ANN-04, F-20 | 1 |

### 4.4 Backend Terkait Beacon & Relay

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| J-20 | Decoder relay (Go) | Decoder paket biner, verifikasi HMAC dengan kunci rumah, anti-replay `seq`, UUIDv5 laporan, metadata jalur untuk topologi, lulus vektor uji | `backend/internal/relay` | FR-BLE-04, NFR-SEC-07, SDD 7.2 | 1,5 |
| J-21 | Modul beacon (Go) | Registrasi beacon, token provisioning sekali pakai, paket konfigurasi, endpoint `/beacon/sync` (verifikasi HMAC + timestamp ±300 s), telemetri, ambang RSSI per beacon di snapshot | `backend/internal/beacon` | FR-BCN-01, 07–08, SDD 8.4 | 2,5 |
| J-22 | BMKG & InaRISK | Polling BMKG tiap 5 menit (gempa & peringatan cuaca), pencocokan wilayah (M ≥ 5 & ≤ 150 km, atau nama wilayah), simpan `ext_alerts`, event `ext_alert.matched`, info/tautan InaRISK | `backend/internal/external/*` | FR-EXT-01–04, SDD 10.3 | 2 |

### 4.5 Layar Terkait Bluetooth & Beacon

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| J-23 | Check-in beacon (Warga) | Deteksi iklan beacon, moving average RSSI 5 sampel, ambang per beacon ≥ 10 s, notifikasi tawaran check-in, opsi check-in otomatis, laporan `beacon_checkin` ke beacon + outbox | `apps/warga/lib/features/beacon_checkin` | FR-BCN-05–06, SDD 7.7 | 2 |
| J-24 | Layar BLE relawan | Kolektor (status pindai, jumlah paket, sinkron), node & topologi, alat beacon (provisioning, diagnostik, **mode kalibrasi RSSI**) | `apps/relawan/lib/features/collector`, `topology`, `beacon_tools` | FR-BLE-09, FR-BCN-01, HRD 9 | 3 |
| J-25 | Halaman dashboard | Graf topologi relay, halaman beacon (registrasi, token provisioning, telemetri, peringatan beacon tidak sinkron > 5 menit), lapisan beacon di peta | `apps/dashboard/lib/features/topology`, `beacons` | F-06, F-23 | 2 |

### 4.6 Pengujian Hardware & Lapangan

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| J-26 | Uji hardware | HT-01 s.d. HT-12 (ADC, ketahanan 72 jam, surya, jangkauan, penyimpanan, sinkron, pemulihan daya, tahan air, suhu, keamanan paket, anti-pemalsuan, RSSI) + laporan berisi angka asli | `hardware/test-reports` | HRD 9–10 | 3 |
| J-27 | Uji lapangan BLE | Skenario AC-04 (relay), AC-05 (mesh), AC-06 (check-in), AC-10 (privasi paket) dengan ≥ 3 HP, ukur konsumsi baterai HP | `hardware/test-reports` | SRS 6, NFR-PWR-01 | 1,5 |

---

## 5. Rincian Tugas — Thoriq (34 poin)

**Peran:** pemilik **design system** dan pengalaman pengguna (terutama untuk lansia dan saat panik), PIC fitur yang paling banyak dilihat warga, serta penulis konten edukasi & P3K. Reviewer default untuk semua UI.

### 5.1 Desain & Komponen Bersama

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| T-01 | Wireframe & alur layar | Wireframe seluruh layar Aplikasi Warga & layar operasional Relawan, alur 3 ketukan dari notifikasi ke laporan terkirim | `docs/` (tautan Figma) | SDD 4.3–4.4, FR-RPT-03 | 1,5 |
| T-02 | Design system | Tema terang/gelap, warna status + ikon + teks (aman buta warna), tipografi besar, tombol lapor ≥ 64 dp/teks ≥ 20 sp, kartu status, banner "LATIHAN", dukungan ukuran huruf sistem & TalkBack | `packages/ui/lib/src/theme`, `widgets` | NFR-USA-01–04 | 3 |
| T-03 | Widget peta bersama | `flutter_map` + OSM, pin rumah per status (hijau/biru/oranye/merah/abu-abu + ikon rentan), titik kumpul, radius 100/250/500 m, posisi relawan, cache tile offline wilayah RT (perhatikan lisensi paket) | `packages/ui/lib/src/map` | FR-DSH-04–06 | 3 |
| T-04 | Halaman peta dashboard | Memakai widget T-03 di dashboard, sinkron dengan *Locate* dari triase (N-25). Lapisan beacon dari J-25 | `apps/dashboard/lib/features/map` | F-11 | 1 |

### 5.2 Aplikasi Warga

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| T-05 | Onboarding | Masukkan kode undangan → nomor WA → OTP, izin Bluetooth/lokasi/notifikasi dengan penjelasan sederhana | `apps/warga/lib/features/onboarding` | FR-AUTH-01, 03 | 1,5 |
| T-06 | Beranda & pengumuman | Beranda normal (skor kesiapsiagaan, pintasan), beranda siaga (banner merah/kuning "LATIHAN"), carousel pengumuman 6 s dengan darurat di depan, buka dari push | `features/home`, `features/announcements` | FR-ANN-03, FR-INC-04, NFR-PERF-05 | 2 |
| T-07 | Layar lapor | 3 tombol besar, form "Butuh bantuan" (urgensi, kebutuhan multi-pilih, anggota, pesan ≤ 140), status pengiriman (terkirim / menunggu sinyal / diteruskan relay), ubah laporan | `features/report` | FR-RPT-01–03, 08–09 | 2,5 |
| T-08 | Rumah Saya | Daftar & form anggota keluarga, kategori kerentanan, persetujuan & pencabutan, unduh data, minta hapus akun | `features/household` | FR-HH-02, 04–05, NFR-PRV-02 | 1,5 |
| T-09 | Pengaturan | Mode baterai (otomatis/hemat), opsi check-in otomatis, status izin, informasi aplikasi | `features/settings` | FR-BLE-11, FR-BCN-05 | 1 |

### 5.3 Edukasi Kesiapsiagaan (F-04, PIC: Thoriq)

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| T-10 | Layar edukasi warga | Daftar modul per bencana, pembaca modul offline, kuis pilihan ganda dengan penjelasan, checklist tas siaga, form rencana evakuasi keluarga (bisa dibuka offline), tampilan skor | `apps/warga/lib/features/education` | FR-EDU-01–05, 08 | 3 |
| T-11 | Backend edukasi | Tabel & endpoint modul/kuis/progres/checklist/rencana evakuasi, rumus skor SDD 6.4, agregat per blok untuk dashboard | `backend/internal/education` | FR-EDU-05–07, SDD 6.4 | 2 |
| T-12 | Admin edukasi dashboard | Kelola & terbitkan modul/kuis, skor per rumah, rata-rata per blok, tren | `apps/dashboard/lib/features/education_admin` | FR-EDU-06–07 | 1,5 |
| T-13 | Konten edukasi | Tulis modul banjir, longsor, gempa, kebakaran (masing-masing ≥ 10 soal kuis + penjelasan), checklist tas siaga, dengan sumber rujukan resmi (misalnya BNPB). Konsep diadaptasi dari NALARIA, **teks ditulis sendiri** | `packages/content/assets/education` | FR-EDU-01–03 | 3 |

### 5.4 Panduan P3K (F-16, PIC: Thoriq)

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| T-14 | Konten & layar P3K | 7 panduan (RJP/CPR, perdarahan, patah tulang, luka bakar, hipotermia, dehidrasi & sengatan panas, tenggelam), langkah bernomor, tanda bahaya, tombol cepat "Butuh bantuan medis", sumber rujukan + penafian. Dipakai di Aplikasi Warga & Relawan | `packages/content/assets/first_aid`, `apps/*/lib/features/first_aid` | FR-FA-01–03 | 2 |

### 5.5 Aplikasi Relawan (layar operasional)

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| T-15 | Layar operasional relawan | **Tugas**: daftar berurutan prioritas, ubah status, isi hasil penjangkauan. **Peta blok**: memakai T-03 + rute ke rumah. **Lapor atas nama**: pilih rumah → status → anggota (offline via outbox). **Posko**: pindai QR, status koneksi | `apps/relawan/lib/features/tasks`, `block_map`, `proxy_report`, `posko` | FR-TSK-03–04, FR-PRX-01–03, FR-PSK-04 | 4 |

### 5.6 Uji Pengguna

| ID | Tugas | Rincian | Lokasi | Rujukan | Poin |
|---|---|---|---|---|---|
| T-16 | Uji usabilitas | Uji ≥ 5 pengguna (termasuk lansia) melapor tanpa pelatihan, catat tingkat keberhasilan & kendala, lakukan perbaikan UI | `docs/` (laporan uji) | NFR-USA-05 | 1,5 |

---

## 6. Ketergantungan Antar-Anggota

Urutan di bawah adalah **urutan ketergantungan**, bukan jadwal. Tugas di tahap awal perlu ada lebih dulu supaya tugas lain bisa dikerjakan.

| Tahap | Yang harus ada dulu | Pemilik | Ditunggu oleh |
|---|---|---|---|
| **0. Kontrak** | Repo & CI (N-01) | Nopal | Semua |
| | Model data & API client `core` (N-03) | Nopal | Thoriq (semua layar), Joshua (J-23–J-25) |
| | Format pengumuman Ed25519 (N-14) | Nopal | Joshua (J-09, J-13, J-19) |
| | Vektor uji protokol (J-13) | Joshua | Nopal (N-11), Joshua (J-14, J-20, firmware) |
| | Design system (T-02) | Thoriq | Semua UI |
| **1. Fondasi** | Platform & auth backend (N-02, N-05) | Nopal | Semua endpoint |
| | Widget peta (T-03) | Thoriq | Nopal (N-23), Joshua (J-25) |
| | Kerangka dashboard (N-22) | Nopal | Thoriq (T-04, T-12), Joshua (J-25) |
| | Prototipe breadboard (J-02) | Joshua | Firmware (J-06–J-12) |
| **2. Alur inti online** | Insiden, laporan, real-time (N-09, N-10, N-15) | Nopal | Thoriq (T-06, T-07), triase |
| | Outbox (N-04) | Nopal | Thoriq (T-07, T-15) |
| **3. Alur offline** | Codec & GATT (J-14, J-15) | Joshua | J-16–J-19, J-23 |
| | Endpoint relay (N-11 + J-20) | Nopal + Joshua | J-18 |
| | Modul beacon backend (J-21) | Joshua | Firmware sinkron (J-10) |
| | Mode posko (N-16) | Nopal | Uji AC-07, sinkron beacon |
| **4. Integrasi & penyempurnaan** | WhatsApp, rekap, AI, BMKG, multi-RT | Nopal & Joshua | Demo lengkap |
| | Uji usabilitas, uji hardware, uji beban | Semua | Bukti validasi |

**Titik koordinasi wajib:**
- **Nopal ↔ Joshua:** format paket, kunci rumah, kunci publik pengumuman, isi snapshot untuk beacon & Posko.
- **Nopal ↔ Thoriq:** bentuk respons API untuk layar lapor, edukasi, dan tugas relawan; event WebSocket.
- **Joshua ↔ Thoriq:** status pengiriman via relay di layar lapor (T-07 membaca status dari `ble_relay`), tampilan check-in beacon, ikon beacon di peta.

---

## 7. Tanggung Jawab Bersama

| Kegiatan | Siapa | Keterangan |
|---|---|---|
| Review PR | Sesuai bidang (lihat README) | Minimal 1 reviewer per PR |
| Skenario demo AC-01 s.d. AC-11 | Semua, dikoordinasi Nopal | Setiap orang menyiapkan bagian demonya |
| README final berbahasa Inggris | Masing-masing menulis bagian komponennya, Nopal menyatukan | Wajib untuk Final Day |
| Pengungkapan penggunaan AI | Masing-masing mencatat alat & perannya | Disatukan di proposal & README |
| Mencatat fitur yang belum selesai/simulasi | Masing-masing PIC | Diperbarui di tabel status README |
| Siap menjelaskan kontribusi | Semua | Juri dapat bertanya teknis ke anggota mana pun |

---

## 8. Definisi "Selesai" (berlaku untuk semua tugas)

Sebuah tugas dianggap **selesai** jika:

1. ✅ Kode/rakitan sudah digabung ke `main` melalui PR yang di-review.
2. ✅ Memenuhi kebutuhan SRS yang dirujuk di kolom **Rujukan**.
3. ✅ Lulus lint dan uji. Logika inti (skor, resolusi status, codec, LUV) punya uji unit, dan codec lulus vektor uji.
4. ✅ Tidak ada rahasia di commit (lulus gitleaks).
5. ✅ Dokumen terkait diperbarui (SDD/HRD/README komponen) jika ada perubahan desain.
6. ✅ Status fitur di tabel README diperbarui. Bagian yang masih simulasi atau belum lengkap **ditandai jujur**.
7. ✅ Pemilik tugas dapat mendemokan dan menjelaskan cara kerjanya.
