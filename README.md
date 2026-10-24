# WE-IRED

> **Koordinasi kesiapsiagaan bencana tingkat RT yang tetap berjalan saat sinyal hilang.**
> Proyek tim untuk **STACK 2026 by GDGoC ITB** — *Case 2: Stronger Communities and Everyday Services*.

WE-IRED membantu pengurus RT dan relawan mendata warga rentan, menetapkan titik kumpul, membagi tugas relawan, lalu saat bencana mengumpulkan status setiap rumah ("aman", "di titik kumpul", "butuh bantuan"). Laporan tetap bisa sampai walaupun internet putus, melalui relay Bluetooth, mesh antar-HP, WE-IRED Beacon di titik kumpul, dan Posko Lokal. Saat online, warga juga bisa melapor lewat tombol WhatsApp.

> ⚠️ **README ini untuk internal tim (bahasa Indonesia).** README yang dikumpulkan ke juri pada Final Day **wajib berbahasa Inggris** dan memuat: instruksi setup, dependensi, lingkungan yang didukung, akses demo, sumber pihak ketiga, pengungkapan bantuan AI, batasan yang diketahui, versi awal & akhir, perubahan Final Day, dan kontribusi anggota.

---

## 📚 Dokumentasi Proyek

### 🛠️ Panduan Pengembang & Operasional (Developer Guides)
| Dokumen | Deskripsi & Isi Utama |
|---|---|
| **[docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md)** | Struktur repositori, arsitektur DDD, hubungan antarmodul, standar kode Go/Dart, dan panduan menambah/mengubah fitur tanpa merusak kontrak tim. |
| **[docs/CONFIGURATION_REFERENCE.md](docs/CONFIGURATION_REFERENCE.md)** | Katalog lengkap variabel environment, berkas konfigurasi, port jaringan, dependensi sistem, katalog endpoint API `/api/v1`, dan tata kelola secret. |
| **[docs/RUNNING_THE_PROJECT.md](docs/RUNNING_THE_PROJECT.md)** | Panduan langkah-demi-langkah menjalankan backend Go, PostgreSQL, migrasi, Flutter dashboard, Docker Cloud/Posko, serta pengujian sistem. |
| **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** | Matriks diagnosis gejala, penyebab, cara cek log, langkah perbaikan, dan verifikasi untuk database, port, JWT, Posko TLS, dan WhatsApp webhook. |
| **[docs/INTEGRATION_STATUS.md](docs/INTEGRATION_STATUS.md)** | Status progres 30 fitur (F-01..30), pembagian PIC, kontrak beku (*frozen contracts*), pembedaan mock/simulator vs fisik, dan bukti uji riil. |

### 📋 Spesifikasi Sistem (System Specifications)
| Dokumen | Isi |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Kebutuhan produk: masalah, pengguna, 30 fitur, metrik |
| [docs/SRS.md](docs/SRS.md) | Kebutuhan perangkat lunak bernomor (FR/NFR) + kriteria penerimaan |
| [docs/SDD.md](docs/SDD.md) | Desain teknis: arsitektur, data, protokol BLE, API |
| [docs/HRD.md](docs/HRD.md) | Perangkat keras WE-IRED Beacon: komponen, wiring, firmware |
| [Pembagian fitur.md](Pembagian%20fitur.md) | **Siapa mengerjakan apa** |

---

## 🧩 Komponen Sistem

| Komponen | Folder | Teknologi | PIC utama |
|---|---|---|---|
| Aplikasi Warga | [`apps/warga`](apps/warga) | Flutter (Android) | Thoriq |
| Aplikasi Relawan | [`apps/relawan`](apps/relawan) | Flutter (Android) | Thoriq & Joshua |
| Dashboard Pengurus | [`apps/dashboard`](apps/dashboard) | Flutter Web/Windows | Nopal |
| Paket inti bersama | [`packages/core`](packages/core) | Dart | Nopal |
| Relay Bluetooth & mesh | [`packages/ble_relay`](packages/ble_relay) | Dart | Joshua |
| Design system & peta | [`packages/ui`](packages/ui) | Flutter | Thoriq |
| Konten P3K & edukasi | [`packages/content`](packages/content) | JSON + aset | Thoriq |
| Backend (cloud & Posko) | [`backend`](backend) | Go + PostgreSQL | Nopal |
| Firmware beacon | [`firmware/beacon`](firmware/beacon) | ESP32-S3, PlatformIO | Joshua |
| Perangkat keras beacon | [`hardware`](hardware) | — | Joshua |
| Deployment | [`deploy`](deploy) | Docker Compose, Caddy | Nopal |

---

## 🗂️ Struktur Folder

```
WE-IRED-STACK-GDG/
├── README.md                 ← dokumen ini
├── Pembagian fitur.md        ← pembagian tugas tim
├── .gitignore
├── .github/workflows/        ← CI: lint, test, gitleaks, build APK
├── apps/
│   ├── warga/                ← Aplikasi Warga
│   │   └── lib/
│   │       ├── app/          ← router, tema, bootstrap
│   │       ├── features/     ← onboarding, home, report, household, education,
│   │       │                   first_aid, announcements, beacon_checkin, settings
│   │       └── services/     ← outbox worker, push handler, foreground service
│   ├── relawan/              ← Aplikasi Relawan
│   │   └── lib/features/     ← tasks, block_map, proxy_report, collector, topology,
│   │                           posko, beacon_tools, first_aid
│   └── dashboard/            ← Dashboard Pengurus
│       └── lib/features/     ← incident_overview, map, triage, assignments, announcements,
│                               rt_data, education_admin, history_drills, recap, topology,
│                               beacons, region, audit, posko
├── packages/
│   ├── core/                 ← models, api client, Drift DB, outbox, auth
│   ├── ble_relay/            ← codec paket, GATT, mesh LUV, siklus peran, kolektor
│   ├── ui/                   ← tema, widget aksesibel, widget peta
│   └── content/              ← panduan P3K & modul edukasi
├── backend/
│   ├── cmd/weired/           ← main (--mode=cloud|posko, --role=api|worker|all)
│   ├── cmd/loadtest/         ← cli runner pengujian beban 15.000 laporan serentak
│   ├── internal/             ← modul domain (auth, household, incident, report, ...)
│   ├── db/migrations/        ← migrasi SQL berversi (000001 - 000009)
│   ├── db/queries/           ← query sqlc
│   └── .env.example          ← daftar variabel lingkungan (tanpa nilai rahasia)
├── firmware/beacon/          ← firmware ESP32-S3 (PlatformIO)
├── hardware/                 ← BOM, wiring, casing, laporan uji
├── deploy/                   ← docker-compose cloud & posko, Caddyfile, backup/restore
└── docs/                     ← PRD, SRS, SDD, HRD, test-vectors
```

---

## 🛠️ Prasyarat

| Alat | Kegunaan | Dipakai oleh |
|---|---|---|
| Git | Version control | Semua |
| Flutter SDK (stable) + Android Studio / SDK Android | Aplikasi & dashboard | Semua |
| Melos (`dart pub global activate melos`) | Monorepo Flutter | Semua |
| Go 1.23+ | Backend | Nopal, Joshua |
| Docker & Docker Compose | Deployment Cloud & Posko Lokal | Nopal, Joshua |
| Caddy v2 | Reverse proxy & auto-HTTPS | Nopal |
| Akun Meta Developer (WhatsApp Cloud API) | Kanal WhatsApp | Nopal |
| Proyek Firebase (FCM saja) | Push notification | Nopal |

---

## 🚀 Panduan Deployment & Menjalankan Sistem (N-32 & N-33)

### 1. Menjalankan Backend Cloud (Docker Compose)
```bash
# Jalankan PostgreSQL, API, Worker, dan Caddy Reverse Proxy
docker compose -f deploy/docker-compose.cloud.yml up -d
```
Endpoint:
- Dashboard & API: `http://localhost:8080` (atau via HTTPS pada domain Caddy)
- WebSocket Hub: `ws://localhost:8080/ws/{incident_id}`

### 2. Menjalankan Backend Posko Lokal (Offline Standalone)
```bash
# Jalankan Posko Lokal tanpa ketergantungan internet Cloud
docker compose -f deploy/docker-compose.posko.yml up -d

# Profil AI (opsional jika laptop posko memiliki RAM cukup untuk Ollama)
docker compose -f deploy/docker-compose.posko.yml --profile ai up -d
```
Endpoint Posko:
- Local mDNS: `http://weired-posko.local:8080` atau `http://192.168.4.1:8080`
- Self-Signed HTTPS: `https://192.168.4.1:8443` (disematkan via QR konfigurasi relawan)

### 3. Prosedur Backup & Restore Basis Data (NFR-REL-04)
```bash
# Menjalankan backup harian PostgreSQL
./deploy/scripts/backup.sh

# Melakukan restore dan validasi data otomatis
./deploy/scripts/restore.sh /backups/weired_backup_YYYYMMDD_HHMMSS.sql.gz
```

### 4. Eksekusi Pengujian Beban (k6 & Go Native Benchmark)
Target: **300 laporan/menit per RT pada 50 RT** (15.000 laporan/menit = 250 RPS sustained, target latensi p95 ≤ 500 ms).
```bash
# 1. HTTP Loopback Client-Server Benchmark (TCP, Chi router, JWT auth, JSON marshal/unmarshal)
cd backend
# Mode sustained: 250 RPS konstan selama durasi tertentu (15.000/menit)
go run ./cmd/loadtest -target=http -mode=sustained -rps=250 -duration=5
# Mode burst: 15.000 laporan serentak melintasi 50 RT
go run ./cmd/loadtest -target=http -mode=burst -rts=50 -reports=300

# 2. In-Memory Domain Benchmark (Kapasitas komputasi domain murni tanpa overhead network)
cd backend && go run ./cmd/loadtest -target=internal -mode=burst -rts=50 -reports=300

# 3. Eksekusi via k6 (pada host dengan k6 & Docker PostgreSQL terpasang)
k6 run deploy/k6/load_test_reports.js
```
*Hasil Uji Terukur Aktual (HTTP Client-Server Loopback)*:
- **Sustained (250 RPS = 15.000 req/menit)**: Latensi p95 = **0,69 ms**, Sukses = 100% (0 error), Throughput = **247,79 RPS** [PASS].
- **Burst (15.000 laporan serentak)**: Latensi p95 = **6,15 ms**, Sukses = 100% (0 error), Throughput = **21.552,77 RPS** [PASS].
- **Internal Domain Logic**: Latensi p95 = **1,57 ms**, Throughput = **128.800 RPS** [PASS].

---

## 📊 Status Fitur

| ID | Fitur | PIC | Status | Catatan / Batasan Demo |
|---|---|---|---|---|
| F-01 | Pendataan Rumah & Anggota Keluarga | Nopal | **Selesai** | Validasi NIK, enkripsi AES-256-GCM data kesehatan, impor CSV baris-per-baris |
| F-02 | Manajemen Titik Kumpul | Nopal | **Selesai** | Koordinat GPS & kapasitas terhubung ke shared map widget T-03 |
| F-03 | Manajemen Relawan & Blok | Nopal | **Selesai** | Penugasan blok, kapasitas tugas aktif, status ketersediaan |
| F-04 | Edukasi Kesiapsiagaan Keluarga | Thoriq | **Selesai** | Rencana siaga mandiri, tas siaga, kuis kesiapsiagaan |
| F-05 | Mode Latihan | Nopal | **Selesai** | Tanda [LATIHAN] pada semua layar, metrik tersimpan terpisah dari data riil |
| F-06 | Manajemen WE-IRED Beacon | Joshua | **Selesai** | Pendaftaran beacon ESP32-S3, status sinkronisasi, pemantauan baterai |
| F-07 | Aktivasi Mode Siaga | Nopal | **Selesai** | Aktivasi 2-tahap (token konfirmasi) mode nyata & langsung untuk latihan |
| F-08 | Laporan Status Rumah | Thoriq | **Selesai** | 3 tombol status utama (Aman, Titik Kumpul, Butuh Bantuan) + urgensi |
| F-09 | Laporan Atas Nama Warga | Thoriq | **Selesai** | Laporan proksi via relawan tercatat dengan ID relawan pelapor |
| F-10 | Dashboard Real-time & Belum Melapor | Nopal | **Selesai** | Hub WebSocket per insiden, event bus, pemulihan event via last_event_id |
| F-11 | Peta Interaktif | Thoriq | **Selesai** | Widget peta bersama `SharedLocationPickerMap` (T-03) berbasis flutter_map |
| F-12 | Tabel Triase | Nopal | **Selesai** | Filter multi-kriteria (status, blok, rentan, kanal) & sorting skor prioritas |
| F-13 | Skor Prioritas & Rencana Penugasan | Nopal | **Selesai** | Algoritma greedy U+V+W+N+D per SDD 6.1-6.3, recalculate berkala |
| F-14 | Penugasan Relawan | Nopal | **Selesai** | State machine tugas (disarankan -> ditugaskan -> diterima -> selesai), timeout 5m |
| F-15 | Siaran Pengumuman | Nopal | **Selesai** | Tanda tangan Ed25519, batas 160 karakter, kanal push/WhatsApp/relay |
| F-16 | Panduan P3K Offline | Thoriq | **Selesai** | Konten mandiri berbasis JSON luring tanpa internet |
| F-17 | Antrean Offline & Sinkronisasi | Nopal | **Selesai** | Outbox worker Drift SQLite, batch sync idempotensi, deduplikasi |
| F-18 | Relay Bluetooth Warga → Relawan | Joshua | **Selesai** | Format biner 46-byte per kontrak Joshua, HMAC per rumah |
| F-19 | Mesh Multi-hop | Joshua | **Selesai** | Relay multi-hop, pelacakan hop_count dan TTL |
| F-20 | Pengumuman via Mesh | Joshua | **Selesai** | Tanda tangan digital Ed25519 diverifikasi perangkat penerima |
| F-21 | Mode Posko Lokal | Nopal | **Selesai** | Mode `--mode=posko`, database lokal, ekspor/impor snapshot AES-256-GCM |
| F-22 | WE-IRED Beacon | Joshua | **Selesai** | Check-in otomatis via BLE, pencatatan ID beacon di titik kumpul |
| F-23 | Daftar Node & Topologi Relay | Joshua | **Selesai** | Visualisasi graf topologi node relawan dan beacon |
| F-24 | Mode Hemat Baterai | Joshua | **Selesai** | Penyesuaian duty cycle BLE scan/advertise saat baterai rendah |
| F-25 | Penghapusan Otomatis Cache 72 Jam | Joshua | **Selesai** | Retensi data darurat lokal otomatis dibersihkan setelah 72 jam |
| F-26 | Rekap Kebutuhan | Nopal | **Selesai** | Agregasi otomatis, persetujuan pengurus, ekspor PDF (Maroto) & CSV |
| F-27 | Asisten AI | Nopal | **Selesai (Simulasi/Lokal)** | Anonimisasi PII (`[WARGA_n]`), adapter Ollama & Gemini, saklar per RT |
| F-28 | Integrasi BMKG / InaRISK | Joshua | **Selesai (Simulasi)** | Banner peringatan dini gempa/tsunami BMKG berdasarkan kontrak JSON |
| F-29 | Skala Multi-RT | Nopal | **Selesai** | Halaman Admin Wilayah lintas-RT, agregasi numerik tanpa bocoran data medis |
| F-30 | Kanal WhatsApp | Nopal | **Selesai (Simulasi/Test API)** | 5 template resmi WhatsApp Cloud API, webhook verifikasi signature, alur butuh bantuan |

### Catatan Keterbatasan Demo & Integrasi Pihak Ketiga:
1. **WhatsApp Cloud API**: Integrasi menggunakan adapter resmi Meta Graph API v21.0. Pada pengujian demo tanpa nomor bisnis Meta berbayar, sistem beralih otomatis ke *Simulated WhatsApp Client* yang memvalidasi payload template dan webhook signature HMAC-SHA256 secara penuh.
2. **Asisten AI**: Dilengkapi dengan fallback engine internal cerdas saat daemon Ollama lokal atau API Key Google Gemini tidak dihubungkan. Data keluar dijamin telah melewati proses sanitasi anonimisasi PII (`[WARGA_n]`).
3. **Hardware WE-IRED Beacon & BLE Mesh**: Protokol paket biner 46-byte telah diuji kesesuaiannya dengan test-vectors resmi. Untuk pengujian tanpa perangkat fisik ESP32, backend dan dashboard menerima paket melalui emulator relay `POST /sync/relay-packets`.

---

## 👥 Tim

| Nama | Peran utama |
|---|---|
| **Nopal** | Tech lead · Backend Go · Dashboard Pengurus · integrasi WhatsApp & AI · deployment |
| **Joshua** | Hardware & firmware WE-IRED Beacon · protokol Bluetooth/mesh · integrasi BMKG |
| **Thoriq** | Aplikasi Warga & Relawan (UI) · design system · peta · konten edukasi & P3K |

---

## 🙏 Inspirasi & Atribusi

- **NALARIA (Navigasi Belajar Siaga Bencana)**, karya Tim PKM-PM Universitas Ahmad Dahlan (PIMNAS ke-37, 2024). Konsep edukasinya diadaptasi untuk fitur edukasi keluarga. Konten dibuat sendiri oleh tim.
- **Resku**, prototipe internal tim sebelumnya. Konsep relay Bluetooth dan skor prioritasnya diadaptasi. Kodenya ditulis ulang dari nol.
- Data peta © OpenStreetMap contributors (ODbL).
