# WE-IRED

> **Koordinasi kesiapsiagaan bencana tingkat RT yang tetap berjalan saat sinyal hilang.**
> Proyek tim untuk **STACK 2026 by GDGoC ITB** — *Case 2: Stronger Communities and Everyday Services*.

WE-IRED membantu pengurus RT dan relawan mendata warga rentan, menetapkan titik kumpul, membagi tugas relawan, lalu saat bencana mengumpulkan status setiap rumah ("aman", "di titik kumpul", "butuh bantuan"). Laporan tetap bisa sampai walaupun internet putus, melalui relay Bluetooth, mesh antar-HP, WE-IRED Beacon di titik kumpul, dan Posko Lokal. Saat online, warga juga bisa melapor lewat tombol WhatsApp.

> ⚠️ **README ini untuk internal tim (bahasa Indonesia).** README yang dikumpulkan ke juri pada Final Day **wajib berbahasa Inggris** dan memuat: instruksi setup, dependensi, lingkungan yang didukung, akses demo, sumber pihak ketiga, pengungkapan bantuan AI, batasan yang diketahui, versi awal & akhir, perubahan Final Day, dan kontribusi anggota.

---

## 📚 Dokumen

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
│   ├── internal/             ← modul domain (auth, household, incident, report, ...)
│   ├── db/migrations/        ← migrasi SQL berversi
│   ├── db/queries/           ← query sqlc
│   ├── tools/seed/           ← generator data sintetis
│   └── .env.example          ← daftar variabel lingkungan (tanpa nilai rahasia)
├── firmware/beacon/          ← firmware ESP32-S3 (PlatformIO)
├── hardware/                 ← BOM, wiring, casing, laporan uji
├── deploy/                   ← docker-compose cloud & posko, Caddyfile
└── docs/                     ← PRD, SRS, SDD, HRD, test-vectors
```

Folder yang masih kosong berisi `.gitkeep` agar tetap ter-commit ke Git. Hapus `.gitkeep` setelah folder berisi kode.

---

## 🛠️ Prasyarat

| Alat | Kegunaan | Dipakai oleh |
|---|---|---|
| Git | Version control | Semua |
| Flutter SDK (stable) + Android Studio / SDK Android | Aplikasi & dashboard | Semua |
| Melos (`dart pub global activate melos`) | Monorepo Flutter | Semua |
| Go 1.23+ | Backend | Nopal, Joshua |
| Docker Desktop | PostgreSQL, Posko Lokal | Nopal, Joshua |
| sqlc, golang-migrate | Query & migrasi | Nopal |
| PlatformIO (VS Code extension) | Firmware beacon | Joshua |
| HP Android 8.0+ (minimal 3 unit untuk uji BLE) | Uji lapangan | Semua |
| Akun Meta Developer (WhatsApp Cloud API, mode uji) | Kanal WhatsApp | Nopal |
| Proyek Firebase (FCM saja) | Push notification | Nopal |

---

## 🚀 Memulai (rencana perintah)

> Perintah di bawah adalah **rencana** dan akan berlaku setelah proyek masing-masing diinisialisasi. Perbarui bagian ini saat setup sebenarnya sudah jadi.

```bash
git clone https://github.com/Thbetyfu/WE-IRED-STACK-GDG.git
```

```bash
cd WE-IRED-STACK-GDG && melos bootstrap
```

**Backend (lokal):**

```bash
cp backend/.env.example backend/.env
```

```bash
docker compose -f deploy/docker-compose.posko.yml up -d postgres
```

```bash
cd backend && go run ./cmd/weired --mode=cloud --role=all
```

**Aplikasi:**

```bash
cd apps/warga && flutter run
```

```bash
cd apps/dashboard && flutter run -d chrome
```

**Firmware:**

```bash
cd firmware/beacon && pio run -t upload
```

---

## 🤝 Aturan Kerja Tim

### Branch & Commit
- `main` selalu dalam kondisi bisa di-build dan didemokan.
- Kerjakan di branch fitur: `feat/<id-fitur>-<nama-singkat>`, contoh `feat/F-08-laporan-status`, `fix/F-18-relay-duplikat`, `hw/beacon-wiring`.
- Pesan commit: `F-08: tambah layar lapor 3 tombol`. Selalu sertakan ID fitur.
- Gabungkan ke `main` melalui Pull Request **minimal 1 reviewer**. Nopal menjadi reviewer default untuk backend/kontrak API, Joshua untuk BLE/firmware, Thoriq untuk UI/UX.

### Kontrak Bersama (jangan diubah sepihak)
| Kontrak | Lokasi | Pemilik |
|---|---|---|
| API REST & WebSocket | `docs/SDD.md` Bagian 9 | Nopal |
| Format paket relay, UUID BLE, LUV | `docs/SDD.md` Bagian 7 + `docs/test-vectors/` | Joshua |
| Model data | `docs/SDD.md` Bagian 5 | Nopal |
| Design system | `packages/ui` | Thoriq |

Perubahan kontrak harus melalui PR yang memperbarui dokumen terkait **dan** disetujui pemilik kontrak.

### Wajib Dipatuhi (aturan STACK 2026)
- 🔐 **Jangan pernah commit rahasia**: `.env`, token WhatsApp, kunci FCM/Gemini, `key.properties`, keystore. Gunakan `backend/.env.example` sebagai acuan.
- 🧪 **Gunakan data sintetis** untuk demo dan uji (`backend/tools/seed`). Jangan memakai data warga asli tanpa izin.
- 🤖 **Catat penggunaan AI** (alat dan perannya) di bagian *AI Usage* README final dan di proposal.
- 🏷️ **Jangan klaim fitur yang belum jadi.** Tandai fitur simulasi, mockup, atau yang belum selesai di tabel status di bawah.
- 🧠 **Setiap anggota harus bisa menjelaskan kontribusinya**, karena juri boleh bertanya ke siapa saja.
- 🆕 Seluruh kode dibuat baru untuk STACK 2026. Kode Resku **tidak** disalin; hanya konsepnya yang dipakai.

---

## 📊 Status Fitur

Perbarui kolom status setiap kali PR digabung: `Belum mulai` → `Dikerjakan` → `Selesai` / `Sebagian` / `Simulasi`.

| ID | Fitur | PIC | Status |
|---|---|---|---|
| F-01 | Pendataan Rumah & Anggota Keluarga | Nopal | Belum mulai |
| F-02 | Manajemen Titik Kumpul | Nopal | Belum mulai |
| F-03 | Manajemen Relawan & Blok | Nopal | Belum mulai |
| F-04 | Edukasi Kesiapsiagaan Keluarga | Thoriq | Belum mulai |
| F-05 | Mode Latihan | Nopal | Belum mulai |
| F-06 | Manajemen WE-IRED Beacon | Joshua | Belum mulai |
| F-07 | Aktivasi Mode Siaga | Nopal | Belum mulai |
| F-08 | Laporan Status Rumah | Thoriq | Belum mulai |
| F-09 | Laporan Atas Nama Warga | Thoriq | Belum mulai |
| F-10 | Dashboard Real-time & Belum Melapor | Nopal | Belum mulai |
| F-11 | Peta Interaktif | Thoriq | Belum mulai |
| F-12 | Tabel Triase | Nopal | Belum mulai |
| F-13 | Skor Prioritas & Rencana Penugasan | Nopal | Belum mulai |
| F-14 | Penugasan Relawan | Nopal | Belum mulai |
| F-15 | Siaran Pengumuman | Nopal | Belum mulai |
| F-16 | Panduan P3K Offline | Thoriq | Belum mulai |
| F-17 | Antrean Offline & Sinkronisasi | Nopal | Belum mulai |
| F-18 | Relay Bluetooth Warga → Relawan | Joshua | Belum mulai |
| F-19 | Mesh Multi-hop | Joshua | Belum mulai |
| F-20 | Pengumuman via Mesh | Joshua | Belum mulai |
| F-21 | Mode Posko Lokal | Nopal | Belum mulai |
| F-22 | WE-IRED Beacon | Joshua | Belum mulai |
| F-23 | Daftar Node & Topologi Relay | Joshua | Belum mulai |
| F-24 | Mode Hemat Baterai | Joshua | Belum mulai |
| F-25 | Penghapusan Otomatis Cache 72 Jam | Joshua | Belum mulai |
| F-26 | Rekap Kebutuhan | Nopal | Belum mulai |
| F-27 | Asisten AI | Nopal | Belum mulai |
| F-28 | Integrasi BMKG / InaRISK | Joshua | Belum mulai |
| F-29 | Skala Multi-RT | Nopal | Belum mulai |
| F-30 | Kanal WhatsApp | Nopal | Belum mulai |

Rincian tugas per orang ada di [Pembagian fitur.md](Pembagian%20fitur.md).

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
